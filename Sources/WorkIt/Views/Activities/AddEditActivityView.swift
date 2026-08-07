import SwiftUI
import SwiftData

private struct RuleDraft: Identifiable {
    let id: UUID
    let persistedID: UUID?
    var weekday: Int
    var hour: Int
    var minute: Int
    var windowDurationMinutes: Int
}

struct AddEditActivityView: View {
    let activity: Activity?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbolName: String
    @State private var rules: [RuleDraft]
    @State private var isPresentingRuleEditor = false
    @State private var editingGroup: ScheduleTimeGroup?
    @State private var isPresentingDeleteConfirm = false

    @State private var targetType: ActivityTargetType
    @State private var targetDurationSeconds: Int
    @State private var targetSets: Int
    @State private var targetReps: Int

    init(activity: Activity?) {
        self.activity = activity
        _name = State(initialValue: activity?.name ?? "")
        _symbolName = State(initialValue: activity?.symbolName ?? PresetActivities.customSymbolName)
        _rules = State(initialValue: (activity?.scheduleRules ?? [])
            .sorted { ($0.weekday, $0.hour, $0.minute) < ($1.weekday, $1.hour, $1.minute) }
            .map {
                RuleDraft(
                    id: $0.id, persistedID: $0.id, weekday: $0.weekday, hour: $0.hour, minute: $0.minute,
                    windowDurationMinutes: $0.windowDurationMinutes
                )
            })
        _targetType = State(initialValue: activity?.targetType ?? .none)
        _targetDurationSeconds = State(initialValue: activity?.targetDurationSeconds ?? 600)
        _targetSets = State(initialValue: activity?.targetSets ?? 3)
        _targetReps = State(initialValue: activity?.targetReps ?? 10)
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rules.isEmpty
    }

    private var scheduleGroups: [ScheduleTimeGroup] {
        ScheduleDisplay.groups(from: rules.map { ($0.weekday, $0.hour, $0.minute) })
    }

    private var durationLabel: String {
        ActivityTargetFormatter.formatDuration(targetDurationSeconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    NavigationLink {
                        ExercisePickerView(excludingActivityID: activity?.id) { suggestion in
                            applySuggestion(suggestion)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: symbolName)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            Text(name.isEmpty ? "Choose Exercise" : name)
                                .foregroundStyle(name.isEmpty ? .secondary : .primary)
                        }
                    }
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
                        Stepper(value: $targetDurationSeconds, in: 15...14400, step: 15) {
                            Text("Duration: \(durationLabel)")
                        }
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
                        Button {
                            editingGroup = group
                            isPresentingRuleEditor = true
                        } label: {
                            HStack {
                                Text(group.displayText)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(ScheduleDisplay.windowDurationLabel(windowDuration(for: group)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        let groupsToRemove = indexSet.map { scheduleGroups[$0] }
                        rules.removeAll { rule in
                            groupsToRemove.contains { $0.hour == rule.hour && $0.minute == rule.minute }
                        }
                    }
                    Button("Add Schedule") {
                        editingGroup = nil
                        isPresentingRuleEditor = true
                    }
                }

                if activity != nil {
                    Section {
                        Button("Delete Activity", role: .destructive) {
                            isPresentingDeleteConfirm = true
                        }
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
                ScheduleRuleEditorView(
                    initial: editingGroup.map {
                        ScheduleRuleEditorView.InitialValue(
                            weekdays: $0.weekdays, hour: $0.hour, minute: $0.minute,
                            windowDurationMinutes: windowDuration(for: $0)
                        )
                    }
                ) { weekdays, times, windowDurationMinutes in
                    if let editingGroup {
                        rules.removeAll { $0.hour == editingGroup.hour && $0.minute == editingGroup.minute }
                    }
                    for weekday in weekdays.sorted() {
                        for time in times {
                            let alreadyExists = rules.contains {
                                $0.weekday == weekday && $0.hour == time.hour && $0.minute == time.minute
                            }
                            guard !alreadyExists else { continue }
                            rules.append(RuleDraft(
                                id: UUID(), persistedID: nil, weekday: weekday, hour: time.hour, minute: time.minute,
                                windowDurationMinutes: windowDurationMinutes
                            ))
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete this activity?",
                isPresented: $isPresentingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteActivity() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Completed and missed history is kept. Occurrences that haven't happened yet will be removed.")
            }
        }
    }

    private func windowDuration(for group: ScheduleTimeGroup) -> Int {
        rules.first { $0.hour == group.hour && $0.minute == group.minute }?.windowDurationMinutes ?? 60
    }

    private func applySuggestion(_ suggestion: ActivitySuggestion) {
        name = suggestion.name
        symbolName = suggestion.symbolName
        if let duration = suggestion.defaultDurationSeconds {
            targetType = .duration
            targetDurationSeconds = duration
        } else if let sets = suggestion.defaultSets, let reps = suggestion.defaultReps {
            targetType = .setsReps
            targetSets = sets
            targetReps = reps
        }
    }

    private func save() {
        let targetActivity: Activity
        if let activity {
            targetActivity = activity
            targetActivity.name = name
            targetActivity.symbolName = symbolName
        } else {
            targetActivity = Activity(name: name, symbolName: symbolName)
            modelContext.insert(targetActivity)
        }

        targetActivity.targetType = targetType
        switch targetType {
        case .none:
            targetActivity.targetDurationSeconds = nil
            targetActivity.targetSets = nil
            targetActivity.targetReps = nil
        case .duration:
            targetActivity.targetDurationSeconds = targetDurationSeconds
            targetActivity.targetSets = nil
            targetActivity.targetReps = nil
        case .setsReps:
            targetActivity.targetDurationSeconds = nil
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
                existing.windowDurationMinutes = draft.windowDurationMinutes
            } else {
                let newRule = ScheduleRule(
                    weekday: draft.weekday, hour: draft.hour, minute: draft.minute,
                    windowDurationMinutes: draft.windowDurationMinutes
                )
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

    /// Real delete, distinct from the swipe-to-archive on the activities list:
    /// resolved (completed/missed) occurrences are kept for History -- reading
    /// from their own snapshot fields since `activity` will be nil -- but
    /// occurrences that haven't happened yet are removed rather than left as
    /// orphaned pending items nobody can act on.
    private func deleteActivity() {
        guard let activity else { return }
        for occurrence in activity.occurrences where occurrence.status == .pending {
            modelContext.delete(occurrence)
        }
        modelContext.delete(activity)
        try? modelContext.save()
        try? ScheduleEngine.syncNotifications(context: modelContext)
        dismiss()
    }
}
