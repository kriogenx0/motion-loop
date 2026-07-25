import SwiftUI

/// Weekday multi-select + a single time. Confirming fans out into one draft per
/// selected weekday -- the underlying data model still stores one ScheduleRule
/// per weekday, this view is purely UI sugar for adding several at once.
struct ScheduleRuleEditorView: View {
    var onAdd: (_ weekdays: Set<Int>, _ hour: Int, _ minute: Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWeekdays: Set<Int> = []
    @State private var time = Date.now

    private let weekdaySymbols = DateFormatter().shortWeekdaySymbols ?? []

    var body: some View {
        NavigationStack {
            Form {
                Section("Days") {
                    HStack {
                        ForEach(1...7, id: \.self) { weekday in
                            weekdayChip(weekday)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Time") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            .navigationTitle("Add Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                        onAdd(selectedWeekdays, components.hour ?? 9, components.minute ?? 0)
                        dismiss()
                    }
                    .disabled(selectedWeekdays.isEmpty)
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
