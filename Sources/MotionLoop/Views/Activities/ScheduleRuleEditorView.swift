import SwiftUI

private enum ScheduleFrequency: String, CaseIterable, Identifiable {
    case everyDay = "Every Day"
    case specificDays = "Specific Days"
    var id: String { rawValue }
}

/// Lets the user build a schedule the way they actually think about it: either
/// "every day" (just pick one or more reminder times) or "specific days" (pick
/// weekdays, then one or more times for those days), plus how long they have to
/// confirm before it counts as missed. Confirming fans out into one ScheduleRule
/// per (weekday, time) pair -- the data model always stores a single
/// weekday+time per row; this view is purely UI sugar over that.
///
/// Doubles as the editor for an existing schedule entry: pass `initial` to
/// prefill from it and switch the title/button to "Edit"/"Save". The caller
/// (AddEditActivityView) is responsible for replacing the old entry's drafts
/// with whatever `onSave` returns -- this view doesn't know about drafts.
struct ScheduleRuleEditorView: View {
    struct InitialValue {
        let weekdays: Set<Int>
        let hour: Int
        let minute: Int
        let windowDurationMinutes: Int
    }

    var initial: InitialValue?
    var onSave: (_ weekdays: Set<Int>, _ times: [(hour: Int, minute: Int)], _ windowDurationMinutes: Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var frequency: ScheduleFrequency
    @State private var selectedWeekdays: Set<Int>
    @State private var times: [Date]
    @State private var windowDurationMinutes: Int

    private static let windowDurationOptions = [15, 30, 45, 60, 90, 120]

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private let weekdaySymbols = DateFormatter().shortWeekdaySymbols ?? []

    init(
        initial: InitialValue? = nil,
        onSave: @escaping (_ weekdays: Set<Int>, _ times: [(hour: Int, minute: Int)], _ windowDurationMinutes: Int) -> Void
    ) {
        self.initial = initial
        self.onSave = onSave
        if let initial {
            _frequency = State(initialValue: initial.weekdays.count == 7 ? .everyDay : .specificDays)
            _selectedWeekdays = State(initialValue: initial.weekdays)
            _times = State(initialValue: [
                Calendar.current.date(bySettingHour: initial.hour, minute: initial.minute, second: 0, of: .now) ?? .now
            ])
            _windowDurationMinutes = State(initialValue: initial.windowDurationMinutes)
        } else {
            _frequency = State(initialValue: .everyDay)
            _selectedWeekdays = State(initialValue: [])
            _times = State(initialValue: [Self.defaultTime])
            _windowDurationMinutes = State(initialValue: 60)
        }
    }

    private var isSaveDisabled: Bool {
        times.isEmpty || (frequency == .specificDays && selectedWeekdays.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
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

                Section(times.count > 1 ? "Times" : "Time") {
                    ForEach(times.indices, id: \.self) { index in
                        HStack {
                            DatePicker("Time", selection: $times[index], displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Spacer()
                            if times.count > 1 {
                                Button(role: .destructive) {
                                    times.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                        }
                    }
                    Button {
                        times.append(Self.defaultTime)
                    } label: {
                        Label("Add Another Time", systemImage: "plus.circle.fill")
                    }
                }

                Section("Window") {
                    Picker("Time to Complete", selection: $windowDurationMinutes) {
                        ForEach(Self.windowDurationOptions, id: \.self) { minutes in
                            Text(ScheduleDisplay.windowDurationLabel(minutes)).tag(minutes)
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
                        let weekdays = frequency == .everyDay ? Set(1...7) : selectedWeekdays
                        let timeComponents = times.map { time -> (hour: Int, minute: Int) in
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                            return (parts.hour ?? 9, parts.minute ?? 0)
                        }
                        onSave(weekdays, timeComponents, windowDurationMinutes)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
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
