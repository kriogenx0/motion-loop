import SwiftUI
import SwiftData

/// Lets the user pick one of their already-created Schedules to reuse instead
/// of authoring a new one -- this is the whole mechanism behind "sessions":
/// two activities pointing at the same Schedule fire together as one
/// notification and get checked off together in one SessionView.
struct ExistingScheduleListView: View {
    var excludingActivityID: UUID?
    var onSelect: (Schedule) -> Void

    @Query(sort: \Schedule.createdAt) private var schedules: [Schedule]
    @Environment(\.dismiss) private var dismiss

    private var eligibleSchedules: [Schedule] {
        schedules.filter { !$0.activities.isEmpty }
    }

    var body: some View {
        List {
            if eligibleSchedules.isEmpty {
                ContentUnavailableView(
                    "No Schedules Yet",
                    systemImage: "calendar.badge.clock",
                    description: Text("Create a schedule on another activity first, then reuse it here.")
                )
            }
            ForEach(eligibleSchedules) { schedule in
                Button {
                    onSelect(schedule)
                    dismiss()
                } label: {
                    ScheduleSummaryRow(schedule: schedule, excludingActivityID: excludingActivityID)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Existing Schedules")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScheduleSummaryRow: View {
    let schedule: Schedule
    let excludingActivityID: UUID?

    private var timesText: String {
        let groups = ScheduleDisplay.groups(from: schedule.times.filter(\.isEnabled).map { ($0.weekday, $0.hour, $0.minute) })
        return groups.map(\.displayText).joined(separator: ", ")
    }

    private var sharedWithNames: [String] {
        schedule.activities.filter { $0.id != excludingActivityID }.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timesText.isEmpty ? "No enabled times" : timesText)
                .font(.body.weight(.medium))
            HStack(spacing: 6) {
                Text(schedule.type == .window ? "Window" : "Reminder")
                if !sharedWithNames.isEmpty {
                    Text("\u{00b7} Shared with \(sharedWithNames.joined(separator: ", "))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
