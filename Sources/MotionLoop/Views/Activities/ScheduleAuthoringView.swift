import SwiftUI

private enum ScheduleFrequency: String, CaseIterable, Identifiable {
    case everyDay = "Every Day"
    case specificDays = "Specific Days"
    var id: String { rawValue }
}

private enum ReminderTimeMode: String, CaseIterable, Identifiable {
    case explicit = "Explicit Times"
    case countAndGap = "Count + Gap"
    var id: String { rawValue }
}

/// Builds or edits an entire Schedule in one session: how often (every day /
/// specific weekdays), what times, and its type-specific completion rule --
/// a mandatory window (deadline) or a minimum gap between completions with no
/// deadline at all. All times in a Schedule share the same weekday set --
/// deliberately simpler than allowing independent weekday sets per time,
/// since a Schedule now has to read as one coherent, shareable unit (that's
/// what makes "sessions" -- several activities on one Schedule -- make sense).
///
/// The type picker only shows when authoring a brand-new schedule -- changing
/// an existing (possibly shared) schedule's type after activities already
/// depend on it is out of scope.
struct ScheduleAuthoringView: View {
    struct InitialValue {
        let type: ScheduleType
        let weekdays: Set<Int>
        let times: [(hour: Int, minute: Int)]
        let windowDurationMinutes: Int?
        let minimumGapMinutes: Int?
        let leadTimeMinutes: Int?
    }

    var initial: InitialValue?
    var sharedWithCount: Int = 0
    var onSave: (
        _ weekdays: Set<Int>,
        _ times: [(hour: Int, minute: Int)],
        _ type: ScheduleType,
        _ windowDurationMinutes: Int?,
        _ minimumGapMinutes: Int?,
        _ leadTimeMinutes: Int?
    ) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scheduleType: ScheduleType
    @State private var frequency: ScheduleFrequency
    @State private var selectedWeekdays: Set<Int>
    @State private var explicitTimes: [Date]
    @State private var reminderTimeMode: ReminderTimeMode = .explicit
    @State private var countPerDay: Int = 3
    @State private var rangeStart: Date = ScheduleAuthoringView.defaultRangeStart
    @State private var rangeEnd: Date = ScheduleAuthoringView.defaultRangeEnd
    @State private var windowDurationMinutes: Int
    @State private var minimumGapMinutes: Int
    @State private var isLeadTimeEnabled: Bool
    @State private var leadTimeMinutes: Int

    private static let windowDurationOptions = [15, 30, 45, 60, 90, 120]
    private static let minimumGapOptions = [15, 30, 45, 60, 90, 120, 180, 240]
    private static let leadTimeOptions = [5, 10, 15, 30, 60]

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }
    private static var defaultRangeStart: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }
    private static var defaultRangeEnd: Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    }

    private let weekdaySymbols = DateFormatter().shortWeekdaySymbols ?? []

    init(
        initial: InitialValue? = nil,
        sharedWithCount: Int = 0,
        onSave: @escaping (
            _ weekdays: Set<Int>, _ times: [(hour: Int, minute: Int)], _ type: ScheduleType,
            _ windowDurationMinutes: Int?, _ minimumGapMinutes: Int?, _ leadTimeMinutes: Int?
        ) -> Void
    ) {
        self.initial = initial
        self.sharedWithCount = sharedWithCount
        self.onSave = onSave
        let calendar = Calendar.current
        if let initial {
            _scheduleType = State(initialValue: initial.type)
            _frequency = State(initialValue: initial.weekdays.count == 7 ? .everyDay : .specificDays)
            _selectedWeekdays = State(initialValue: initial.weekdays)
            _explicitTimes = State(initialValue: initial.times.isEmpty
                ? [Self.defaultTime]
                : initial.times.map { calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: .now) ?? .now })
            _countPerDay = State(initialValue: max(1, initial.times.count))
            _windowDurationMinutes = State(initialValue: initial.windowDurationMinutes ?? 60)
            _minimumGapMinutes = State(initialValue: initial.minimumGapMinutes ?? 60)
            _isLeadTimeEnabled = State(initialValue: initial.leadTimeMinutes != nil)
            _leadTimeMinutes = State(initialValue: initial.leadTimeMinutes ?? 5)
        } else {
            _scheduleType = State(initialValue: .window)
            _frequency = State(initialValue: .everyDay)
            _selectedWeekdays = State(initialValue: [])
            _explicitTimes = State(initialValue: [Self.defaultTime])
            _windowDurationMinutes = State(initialValue: 60)
            _minimumGapMinutes = State(initialValue: 60)
            _isLeadTimeEnabled = State(initialValue: false)
            _leadTimeMinutes = State(initialValue: 5)
        }
    }

    private var resolvedWeekdays: Set<Int> {
        frequency == .everyDay ? Set(1...7) : selectedWeekdays
    }

    private var explicitTimeComponents: [(hour: Int, minute: Int)] {
        explicitTimes.map { time -> (hour: Int, minute: Int) in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            return (parts.hour ?? 9, parts.minute ?? 0)
        }
    }

    private var countAndGapTimes: [(hour: Int, minute: Int)]? {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: rangeStart)
        let end = calendar.dateComponents([.hour, .minute], from: rangeEnd)
        return TimeDistribution.evenlySpaced(
            count: countPerDay,
            rangeStart: (hour: start.hour ?? 8, minute: start.minute ?? 0),
            rangeEnd: (hour: end.hour ?? 20, minute: end.minute ?? 0),
            minimumGapMinutes: minimumGapMinutes
        )
    }

    /// The actual times that would be saved right now.
    private var resolvedTimes: [(hour: Int, minute: Int)]? {
        if scheduleType == .reminder && reminderTimeMode == .countAndGap {
            return countAndGapTimes
        }
        return explicitTimeComponents.isEmpty ? nil : explicitTimeComponents
    }

    private var explicitTimesViolateGap: Bool {
        guard scheduleType == .reminder, reminderTimeMode == .explicit else { return false }
        let entries = resolvedWeekdays.flatMap { weekday in
            explicitTimeComponents.map { GapEnforcer.TimeEntry(weekday: weekday, hour: $0.hour, minute: $0.minute) }
        }
        return GapEnforcer.violatesMinimumGap(entries, minimumGapMinutes: minimumGapMinutes)
    }

    private var isSaveDisabled: Bool {
        if frequency == .specificDays && selectedWeekdays.isEmpty { return true }
        guard let times = resolvedTimes, !times.isEmpty else { return true }
        return explicitTimesViolateGap
    }

    var body: some View {
        NavigationStack {
            Form {
                if initial == nil {
                    typeSection
                } else if sharedWithCount > 0 {
                    Section {
                        Text("Editing this schedule updates it for all \(sharedWithCount + 1) activities using it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(ScheduleFrequency.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if frequency == .specificDays {
                    Section("Days") {
                        HStack {
                            ForEach(1...7, id: \.self) { weekday in
                                weekdayChip(weekday)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                timesSection

                if scheduleType == .window {
                    Section("Window") {
                        Picker("Time to Complete", selection: $windowDurationMinutes) {
                            ForEach(Self.windowDurationOptions, id: \.self) { minutes in
                                Text(ScheduleDisplay.windowDurationLabel(minutes)).tag(minutes)
                            }
                        }
                    }
                } else {
                    Section("Minimum Gap") {
                        Picker("Between Completions", selection: $minimumGapMinutes) {
                            ForEach(Self.minimumGapOptions, id: \.self) { minutes in
                                Text(ScheduleDisplay.windowDurationLabel(minutes)).tag(minutes)
                            }
                        }
                    }
                }

                Section("Reminder") {
                    Toggle("Remind Me Before", isOn: $isLeadTimeEnabled)
                    if isLeadTimeEnabled {
                        Picker("Lead Time", selection: $leadTimeMinutes) {
                            ForEach(Self.leadTimeOptions, id: \.self) { minutes in
                                Text("\(minutes) min before").tag(minutes)
                            }
                        }
                    }
                }
            }
            .navigationTitle(initial == nil ? "Add Schedule" : "Edit Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(initial == nil ? "Add" : "Save") {
                        guard let times = resolvedTimes else { return }
                        onSave(
                            resolvedWeekdays, times, scheduleType,
                            scheduleType == .window ? windowDurationMinutes : nil,
                            scheduleType == .reminder ? minimumGapMinutes : nil,
                            isLeadTimeEnabled ? leadTimeMinutes : nil
                        )
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var typeSection: some View {
        Section {
            Picker("Type", selection: $scheduleType) {
                Text("Window").tag(ScheduleType.window)
                Text("Reminder").tag(ScheduleType.reminder)
            }
            .pickerStyle(.segmented)
            Text(scheduleType == .window
                 ? "Complete within a time limit, or it's marked missed."
                 : "A nudge with no deadline -- check in whenever, spaced apart."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var timesSection: some View {
        if scheduleType == .reminder {
            Section {
                Picker("Times", selection: $reminderTimeMode) {
                    ForEach(ReminderTimeMode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }

        if scheduleType == .reminder && reminderTimeMode == .countAndGap {
            Section("Times") {
                Stepper("Times per day: \(countPerDay)", value: $countPerDay, in: 1...12)
                DatePicker("From", selection: $rangeStart, displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: $rangeEnd, displayedComponents: .hourAndMinute)
                if let times = countAndGapTimes {
                    Text(times.map { formattedTime(hour: $0.hour, minute: $0.minute) }.joined(separator: " \u{00b7} "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Can't fit \(countPerDay) times that far apart in this range.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } else {
            Section(explicitTimes.count > 1 ? "Times" : "Time") {
                ForEach(explicitTimes.indices, id: \.self) { index in
                    HStack {
                        DatePicker("Time", selection: $explicitTimes[index], displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Spacer()
                        if explicitTimes.count > 1 {
                            Button(role: .destructive) {
                                explicitTimes.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }
                Button {
                    explicitTimes.append(Self.defaultTime)
                } label: {
                    Label("Add Another Time", systemImage: "plus.circle.fill")
                }

                if explicitTimesViolateGap {
                    Text("Two times are less than \(ScheduleDisplay.windowDurationLabel(minimumGapMinutes)) apart.")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Auto-Space Evenly", action: autoSpaceExplicitTimes)
                }
            }
        }
    }

    private func autoSpaceExplicitTimes() {
        guard explicitTimes.count >= 2 else { return }
        let calendar = Calendar.current
        let sorted = explicitTimeComponents.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        guard
            let first = sorted.first, let last = sorted.last,
            let spaced = TimeDistribution.evenlySpaced(
                count: explicitTimes.count, rangeStart: first, rangeEnd: last, minimumGapMinutes: minimumGapMinutes
            )
        else { return }
        explicitTimes = spaced.map { calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: .now) ?? .now }
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func weekdayChip(_ weekday: Int) -> some View {
        let isSelected = selectedWeekdays.contains(weekday)
        let label = weekdaySymbols.indices.contains(weekday - 1) ? weekdaySymbols[weekday - 1] : "?"
        return Button {
            if isSelected {
                selectedWeekdays.remove(weekday)
            } else {
                selectedWeekdays.insert(weekday)
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
