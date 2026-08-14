import SwiftUI
import SwiftData

/// A schedule being built or reused for this activity. `existingSchedule` is
/// non-nil whenever it points at a real, already-persisted Schedule (whether
/// authored earlier for this same activity or picked from
/// ExistingScheduleListView) -- `save()` mutates that same object in place
/// rather than creating a new one, which is exactly what makes editing a
/// shared schedule propagate to every activity using it. `nil` means freeform.
private struct ScheduleDraft {
    var existingSchedule: Schedule?
    var type: ScheduleType
    var weekdays: Set<Int>
    var times: [(hour: Int, minute: Int)]
    var windowDurationMinutes: Int?
    var minimumGapMinutes: Int?
    var leadTimeMinutes: Int?

    /// Reconstructs a draft from a persisted Schedule. All times on a Schedule
    /// share one weekday set by construction (see ScheduleAuthoringView), so
    /// reading back just one representative weekday's times is faithful.
    init(from schedule: Schedule) {
        let weekdays = Set(schedule.times.map(\.weekday))
        let representativeWeekday = weekdays.min() ?? 1
        let times = schedule.times
            .filter { $0.weekday == representativeWeekday }
            .map { (hour: $0.hour, minute: $0.minute) }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        self.init(
            existingSchedule: schedule, type: schedule.type, weekdays: weekdays, times: times,
            windowDurationMinutes: schedule.windowDurationMinutes, minimumGapMinutes: schedule.minimumGapMinutes,
            leadTimeMinutes: schedule.leadTimeMinutes
        )
    }

    init(
        existingSchedule: Schedule?, type: ScheduleType, weekdays: Set<Int>, times: [(hour: Int, minute: Int)],
        windowDurationMinutes: Int?, minimumGapMinutes: Int?, leadTimeMinutes: Int?
    ) {
        self.existingSchedule = existingSchedule
        self.type = type
        self.weekdays = weekdays
        self.times = times
        self.windowDurationMinutes = windowDurationMinutes
        self.minimumGapMinutes = minimumGapMinutes
        self.leadTimeMinutes = leadTimeMinutes
    }
}

struct AddEditActivityView: View {
    let activity: Activity?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbolName: String
    @State private var scheduleDraft: ScheduleDraft?
    @State private var isPresentingScheduleAuthor = false
    @State private var isPresentingDeleteConfirm = false

    @State private var targetType: ActivityTargetType
    @State private var targetDurationSeconds: Int
    @State private var targetSets: Int
    @State private var targetReps: Int

    init(activity: Activity?) {
        self.activity = activity
        _name = State(initialValue: activity?.name ?? "")
        _symbolName = State(initialValue: activity?.symbolName ?? PresetActivities.customSymbolName)
        _scheduleDraft = State(initialValue: activity?.schedule.map(ScheduleDraft.init(from:)))
        _targetType = State(initialValue: activity?.targetType ?? .none)
        _targetDurationSeconds = State(initialValue: activity?.targetDurationSeconds ?? 600)
        _targetSets = State(initialValue: activity?.targetSets ?? 3)
        _targetReps = State(initialValue: activity?.targetReps ?? 10)
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var durationLabel: String {
        ActivityTargetFormatter.formatDuration(targetDurationSeconds)
    }

    private var sharedWithCount: Int {
        guard let existing = scheduleDraft?.existingSchedule else { return 0 }
        return existing.activities.filter { $0.id != activity?.id }.count
    }

    private var scheduleSummaryLines: [String] {
        guard let draft = scheduleDraft else { return [] }
        let entries = draft.weekdays.sorted().flatMap { weekday in
            draft.times.map { (weekday: weekday, hour: $0.hour, minute: $0.minute) }
        }
        var lines = ScheduleDisplay.groups(from: entries).map(\.displayText)
        if draft.type == .window, let window = draft.windowDurationMinutes {
            lines.append("Window: \(ScheduleDisplay.windowDurationLabel(window))")
        } else if draft.type == .reminder, let gap = draft.minimumGapMinutes {
            lines.append("Minimum gap: \(ScheduleDisplay.windowDurationLabel(gap))")
        }
        if let lead = draft.leadTimeMinutes {
            lines.append("Reminds \(lead) min before")
        }
        return lines
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

                scheduleSection

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
            .sheet(isPresented: $isPresentingScheduleAuthor) {
                ScheduleAuthoringView(
                    initial: scheduleDraft.map {
                        ScheduleAuthoringView.InitialValue(
                            type: $0.type, weekdays: $0.weekdays, times: $0.times,
                            windowDurationMinutes: $0.windowDurationMinutes, minimumGapMinutes: $0.minimumGapMinutes,
                            leadTimeMinutes: $0.leadTimeMinutes
                        )
                    },
                    sharedWithCount: sharedWithCount
                ) { weekdays, times, type, windowDurationMinutes, minimumGapMinutes, leadTimeMinutes in
                    scheduleDraft = ScheduleDraft(
                        existingSchedule: scheduleDraft?.existingSchedule,
                        type: type, weekdays: weekdays, times: times,
                        windowDurationMinutes: windowDurationMinutes, minimumGapMinutes: minimumGapMinutes,
                        leadTimeMinutes: leadTimeMinutes
                    )
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

    @ViewBuilder
    private var scheduleSection: some View {
        Section("Schedule") {
            if let draft = scheduleDraft {
                ForEach(scheduleSummaryLines, id: \.self) { line in
                    Text(line)
                }
                if let existing = draft.existingSchedule, sharedWithCount > 0 {
                    let names = existing.activities.filter { $0.id != activity?.id }.map(\.name)
                    Text("Shared with \(names.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Edit Schedule") { isPresentingScheduleAuthor = true }
                NavigationLink("Use a Different Existing Schedule") {
                    ExistingScheduleListView(excludingActivityID: activity?.id) { schedule in
                        scheduleDraft = ScheduleDraft(from: schedule)
                    }
                }
                Button("Remove Schedule (Freeform)", role: .destructive) {
                    scheduleDraft = nil
                }
            } else {
                Button("Add Schedule") { isPresentingScheduleAuthor = true }
                NavigationLink("Use Existing Schedule") {
                    ExistingScheduleListView(excludingActivityID: activity?.id) { schedule in
                        scheduleDraft = ScheduleDraft(from: schedule)
                    }
                }
                Text("No schedule -- freeform, complete anytime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

        if let draft = scheduleDraft {
            let schedule: Schedule
            if let existing = draft.existingSchedule {
                schedule = existing
            } else {
                schedule = Schedule(type: draft.type)
                modelContext.insert(schedule)
            }
            schedule.type = draft.type
            schedule.windowDurationMinutes = draft.windowDurationMinutes
            schedule.minimumGapMinutes = draft.minimumGapMinutes
            schedule.leadTimeMinutes = draft.leadTimeMinutes

            // ScheduleTime rows are cheap and not referenced by any live
            // relationship from ExerciseOccurrence (sourceScheduleTimeID is a
            // plain UUID), so a full delete-and-recreate on every save is
            // simpler and just as safe as diffing them.
            for time in schedule.times {
                modelContext.delete(time)
            }
            schedule.times.removeAll()
            for weekday in draft.weekdays.sorted() {
                for time in draft.times {
                    let newTime = ScheduleTime(weekday: weekday, hour: time.hour, minute: time.minute)
                    newTime.schedule = schedule
                    schedule.times.append(newTime)
                }
            }

            targetActivity.schedule = schedule
        } else {
            targetActivity.schedule = nil
        }

        try? modelContext.save()
        try? ScheduleEngine.pruneOrphanedSchedules(context: modelContext)
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
        try? ScheduleEngine.pruneOrphanedSchedules(context: modelContext)
        try? ScheduleEngine.syncNotifications(context: modelContext)
        dismiss()
    }
}
