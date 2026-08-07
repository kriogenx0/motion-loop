import SwiftUI

struct TodayOccurrenceRow: View {
    let occurrence: ExerciseOccurrence
    var now: Date = .now
    var onComplete: (() -> Void)?

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: occurrence.scheduledDate)) - \(formatter.string(from: occurrence.windowEnd))"
    }

    /// Only meaningful while the window is actually open -- otherwise "minutes
    /// left" would either be negative or describe a window that hasn't started.
    private var minutesLeftText: String? {
        guard occurrence.status == .pending, now >= occurrence.scheduledDate, now < occurrence.windowEnd else {
            return nil
        }
        let minutes = max(1, Int(occurrence.windowEnd.timeIntervalSince(now) / 60))
        return minutes == 1 ? "1 min left" : "\(minutes) min left"
    }

    private var completedTimeText: String? {
        guard occurrence.status == .completed, let respondedAt = occurrence.respondedAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Completed at \(formatter.string(from: respondedAt))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: occurrence.activitySymbolName)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(occurrence.activityName)
                        .font(.body.weight(.medium))
                    HStack(spacing: 6) {
                        Text(timeRangeText)
                        if let targetDescription = occurrence.activityTargetDescription {
                            Text("\u{00b7}")
                            Text(targetDescription)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let minutesLeftText {
                        Text(minutesLeftText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    if let completedTimeText {
                        Text(completedTimeText)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                statusIcon
            }

            if let onComplete {
                Button("Mark Complete", action: onComplete)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch occurrence.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .missed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .pending:
            Image(systemName: "clock.fill").foregroundStyle(.orange)
        }
    }
}
