import SwiftUI
import SwiftData

private struct RuleDraft: Identifiable {
    let id: UUID
    let persistedID: UUID?
    var weekday: Int
    var hour: Int
    var minute: Int
}

/// A name+icon+default-target suggestion, whether it comes from the bundled
/// preset list or from an activity the user has typed in before.
private struct ActivitySuggestion: Identifiable, Hashable {
    var id: String { name.lowercased() }
    let name: String
    let symbolName: String
    let defaultDurationMinutes: Int?
    let defaultSets: Int?
    let defaultReps: Int?
}

struct AddEditActivityView: View {
    let activity: Activity?

    /// All activities ever entered (including archived) -- source of "you've
    /// typed this before" suggestions, since we never hard-delete activities.
    @Query private var pastActivities: [Activity]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var rules: [RuleDraft]
    @State private var isPresentingRuleEditor = false

    @State private var targetType: ActivityTargetType
    @State private var targetDurationMinutes: Int
    @State private var targetSets: Int
    @State private var targetReps: Int

    init(activity: Activity?) {
        self.activity = activity
        _name = State(initialValue: activity?.name ?? "")
        _rules = State(initialValue: (activity?.scheduleRules ?? [])
            .sorted { ($0.weekday, $0.hour, $0.minute) < ($1.weekday, $1.hour, $1.minute) }
            .map { RuleDraft(id: $0.id, persistedID: $0.id, weekday: $0.weekday, hour: $0.hour, minute: $0.minute) })
        _targetType = State(initialValue: activity?.targetType ?? .none)
        _targetDurationMinutes = State(initialValue: activity?.targetDurationMinutes ?? 10)
        _targetSets = State(initialValue: activity?.targetSets ?? 3)
        _targetReps = State(initialValue: activity?.targetReps ?? 10)
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rules.isEmpty
    }

    private var scheduleGroups: [ScheduleTimeGroup] {
        ScheduleDisplay.groups(from: rules.map { ($0.weekday, $0.hour, $0.minute) })
    }

    /// The user can type any name they like -- this only resolves an icon when
    /// the name exactly matches a known preset. Falls back to the activity's
    /// existing icon (when editing) so renaming never silently changes it.
    private var resolvedSymbolName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = PresetActivities.all.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match.symbolName
        }
        return activity?.symbolName ?? PresetActivities.customSymbolName
    }

    /// Autocomplete suggestions: a curated featured set when the field is empty,
    /// narrowing to substring matches across the full static list -- plus any
    /// custom names the user has typed before -- as they type.
    private var suggestedActivities: [ActivitySuggestion] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let presetSuggestions = (trimmed.isEmpty ? PresetActivities.featured : PresetActivities.all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) })
            .map {
                ActivitySuggestion(
                    name: $0.name,
                    symbolName: $0.symbolName,
                    defaultDurationMinutes: $0.defaultDurationMinutes,
                    defaultSets: $0.defaultSets,
                    defaultReps: $0.defaultReps
                )
            }
        guard !trimmed.isEmpty else { return presetSuggestions }

        let presetNames = Set(PresetActivities.all.map { $0.name.lowercased() })
        var seenCustomNames = Set<String>()
        let customSuggestions = pastActivities
            .filter { $0.id != activity?.id }
            .sorted { $0.createdAt > $1.createdAt }
            .filter { !presetNames.contains($0.name.lowercased()) }
            .filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
            .compactMap { pastActivity -> ActivitySuggestion? in
                guard seenCustomNames.insert(pastActivity.name.lowercased()).inserted else { return nil }
                return ActivitySuggestion(
                    name: pastActivity.name,
                    symbolName: pastActivity.symbolName,
                    defaultDurationMinutes: pastActivity.targetType == .duration ? pastActivity.targetDurationMinutes : nil,
                    defaultSets: pastActivity.targetType == .setsReps ? pastActivity.targetSets : nil,
                    defaultReps: pastActivity.targetType == .setsReps ? pastActivity.targetReps : nil
                )
            }

        return presetSuggestions + customSuggestions
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                    presetPicker
                }

                Section("Target") {
                    Picker("Type", selection: $targetType) {
                        Text("None").tag(ActivityTargetType.none)
                        Text("Duration").tag(ActivityTargetType.duration)
                        Text("Sets & Reps").tag(ActivityTargetType.setsReps)
                    }
                    .pickerStyle(.segmented)

                    switch targetType {
                    case .none:
                        EmptyView()
                    case .duration:
                        Stepper("Duration: \(targetDurationMinutes) min", value: $targetDurationMinutes, in: 1...240)
                    case .setsReps:
                        Stepper("Sets: \(targetSets)", value: $targetSets, in: 1...20)
                        Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...100)
                    }
                }

                Section("Schedule") {
                    if rules.isEmpty {
                        Text("No schedule yet -- add at least one.").foregroundStyle(.secondary)
                    }
                    ForEach(scheduleGroups) { group in
                        Text(group.displayText)
                    }
                    .onDelete { indexSet in
                        let groupsToRemove = indexSet.map { scheduleGroups[$0] }
                        rules.removeAll { rule in
                            groupsToRemove.contains { $0.hour == rule.hour && $0.minute == rule.minute }
                        }
                    }
                    Button("Add Schedule") {
                        isPresentingRuleEditor = true
                    }
                }
            }
            .navigationTitle(activity == nil ? "New Activity" : "Edit Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(isSaveDisabled)
                }
            }
            .sheet(isPresented: $isPresentingRuleEditor) {
                ScheduleRuleEditorView { weekdays, times in
                    for weekday in weekdays.sorted() {
                        for time in times {
                            let alreadyExists = rules.contains {
                                $0.weekday == weekday && $0.hour == time.hour && $0.minute == time.minute
                            }
                            guard !alreadyExists else { continue }
                            rules.append(RuleDraft(id: UUID(), persistedID: nil, weekday: weekday, hour: time.hour, minute: time.minute))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var presetPicker: some View {
        if !suggestedActivities.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestedActivities) { suggestion in
                        Button {
                            applySuggestion(suggestion)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: suggestion.symbolName).font(.title3)
                                Text(suggestion.name).font(.caption2)
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            name.localizedCaseInsensitiveCompare(suggestion.name) == .orderedSame
                                ? Color.accentColor : Color.primary
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func applySuggestion(_ suggestion: ActivitySuggestion) {
        name = suggestion.name
        if let duration = suggestion.defaultDurationMinutes {
            targetType = .duration
            targetDurationMinutes = duration
        } else if let sets = suggestion.defaultSets, let reps = suggestion.defaultReps {
            targetType = .setsReps
            targetSets = sets
            targetReps = reps
        }
    }

    private func save() {
        let resolvedSymbol = resolvedSymbolName
        let targetActivity: Activity
        if let activity {
            targetActivity = activity
            targetActivity.name = name
            targetActivity.symbolName = resolvedSymbol
        } else {
            targetActivity = Activity(name: name, symbolName: resolvedSymbol)
            modelContext.insert(targetActivity)
        }

        targetActivity.targetType = targetType
        switch targetType {
        case .none:
            targetActivity.targetDurationMinutes = nil
            targetActivity.targetSets = nil
            targetActivity.targetReps = nil
        case .duration:
            targetActivity.targetDurationMinutes = targetDurationMinutes
            targetActivity.targetSets = nil
            targetActivity.targetReps = nil
        case .setsReps:
            targetActivity.targetDurationMinutes = nil
            targetActivity.targetSets = targetSets
            targetActivity.targetReps = targetReps
        }

        let keptPersistedIDs = Set(rules.compactMap(\.persistedID))
        for existingRule in targetActivity.scheduleRules where !keptPersistedIDs.contains(existingRule.id) {
            modelContext.delete(existingRule)
        }
        targetActivity.scheduleRules.removeAll { !keptPersistedIDs.contains($0.id) }

        for draft in rules {
            if let persistedID = draft.persistedID,
               let existing = targetActivity.scheduleRules.first(where: { $0.id == persistedID }) {
                existing.weekday = draft.weekday
                existing.hour = draft.hour
                existing.minute = draft.minute
            } else {
                let newRule = ScheduleRule(weekday: draft.weekday, hour: draft.hour, minute: draft.minute)
                newRule.activity = targetActivity
                targetActivity.scheduleRules.append(newRule)
            }
        }

        try? modelContext.save()
        try? ScheduleEngine.reconcileAndGenerate(context: modelContext)
        try? ScheduleEngine.syncNotifications(context: modelContext)

        Task {
            await NotificationManager.ensureAuthorization()
        }

        dismiss()
    }
}
