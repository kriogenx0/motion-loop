import SwiftUI

struct DaySummaryRow: View {
    let summary: DaySummary

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: summary.day)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(summary.day)
    }

    var body: some View {
        HStack {
            Text(dayLabel)
                .font(.body.weight(isToday ? .semibold : .regular))
            Spacer()
            HStack(spacing: 14) {
                if summary.completed > 0 {
                    Label("\(summary.completed)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if summary.missed > 0 {
                    Label("\(summary.missed)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                if summary.pending > 0 {
                    Label("\(summary.pending)", systemImage: "clock.fill")
                        .foregroundStyle(.orange)
                }
                if summary.upcoming > 0 {
                    Label("\(summary.upcoming)", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                }
                if summary.completed == 0 && summary.missed == 0 && summary.pending == 0 && summary.upcoming == 0 {
                    Text("--").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)
        }
    }
}
