import SwiftUI

struct TodayOccurrenceRow: View {
    let occurrence: ExerciseOccurrence
    var onComplete: (() -> Void)?
    var onMissed: (() -> Void)?

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: occurrence.scheduledDate)) - \(formatter.string(from: occurrence.windowEnd))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: occurrence.activity?.symbolName ?? "figure.run")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(occurrence.activity?.name ?? "Activity")
                        .font(.body.weight(.medium))
                    Text(timeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusIcon
            }

            if let onComplete, let onMissed {
                HStack(spacing: 12) {
                    Button("Didn't Do It", role: .destructive, action: onMissed)
                        .buttonStyle(.bordered)
                    Button("Mark Complete", action: onComplete)
                        .buttonStyle(.borderedProminent)
                }
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
