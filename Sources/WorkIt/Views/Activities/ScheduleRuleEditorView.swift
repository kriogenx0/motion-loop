import SwiftUI

private enum ScheduleFrequency: String, CaseIterable, Identifiable {
    case everyDay = "Every Day"
    case specificDays = "Specific Days"
    var id: String { rawValue }
}

/// Lets the user build a schedule the way they actually think about it: either
/// "every day" (just pick one or more reminder times) or "specific days" (pick
/// weekdays, then one or more times for those days). Confirming fans out into
/// one ScheduleRule per (weekday, time) pair -- the data model always stores a
/// single weekday+time per row; this view is purely UI sugar over that.
struct ScheduleRuleEditorView: View {
    var onAdd: (_ weekdays: Set<Int>, _ times: [(hour: Int, minute: Int)]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var frequency: ScheduleFrequency = .everyDay
    @State private var selectedWeekdays: Set<Int> = []
    @State private var times: [Date] = [ScheduleRuleEditorView.defaultTime]

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private let weekdaySymbols = DateFormatter().shortWeekdaySymbols ?? []

    private var isAddDisabled: Bool {
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
            }
            .navigationTitle("Add Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let weekdays = frequency == .everyDay ? Set(1...7) : selectedWeekdays
                        let timeComponents = times.map { time -> (hour: Int, minute: Int) in
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                            return (parts.hour ?? 9, parts.minute ?? 0)
                        }
                        onAdd(weekdays, timeComponents)
                        dismiss()
                    }
                    .disabled(isAddDisabled)
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
