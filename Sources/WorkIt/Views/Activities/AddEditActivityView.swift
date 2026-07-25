import SwiftUI
import SwiftData

private struct RuleDraft: Identifiable {
    let id: UUID
    let persistedID: UUID?
    var weekday: Int
    var hour: Int
    var minute: Int

    private static let weekdaySymbols = DateFormatter().shortWeekdaySymbols ?? []

    var displayText: String {
        let dayName = Self.weekdaySymbols.indices.contains(weekday - 1) ? Self.weekdaySymbols[weekday - 1] : "?"
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let time = Calendar.current.date(from: components) ?? .now
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(dayName) at \(formatter.string(from: time))"
    }
}

struct AddEditActivityView: View {
    let activity: Activity?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbolName: String
    @State private var rules: [RuleDraft]
    @State private var isPresentingRuleEditor = false

    init(activity: Activity?) {
        self.activity = activity
        _name = State(initialValue: activity?.name ?? "")
        _symbolName = State(initialValue: activity?.symbolName ?? PresetActivities.all[0].symbolName)
        _rules = State(initialValue: (activity?.scheduleRules ?? [])
            .sorted { ($0.weekday, $0.hour, $0.minute) < ($1.weekday, $1.hour, $1.minute) }
            .map { RuleDraft(id: $0.id, persistedID: $0.id, weekday: $0.weekday, hour: $0.hour, minute: $0.minute) })
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rules.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    if activity == nil {
                        presetPicker
                    }
                    TextField("Name", text: $name)
                }

                Section("Schedule") {
                    if rules.isEmpty {
                        Text("No schedule yet -- add at least one.").foregroundStyle(.secondary)
                    }
                    ForEach(rules) { rule in
                        Text(rule.displayText)
                    }
                    .onDelete { indexSet in
                        rules.remove(atOffsets: indexSet)
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
                ScheduleRuleEditorView { weekdays, hour, minute in
                    for weekday in weekdays.sorted() {
                        rules.append(RuleDraft(id: UUID(), persistedID: nil, weekday: weekday, hour: hour, minute: minute))
                    }
                }
            }
        }
    }

    private var presetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PresetActivities.all) { preset in
                    Button {
                        name = preset.name
                        symbolName = preset.symbolName
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: preset.symbolName).font(.title3)
                            Text(preset.name).font(.caption2)
                        }
                        .frame(width: 64)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(symbolName == preset.symbolName && name == preset.name ? Color.accentColor : Color.primary)
                }
            }
            .padding(.vertical, 4)
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
