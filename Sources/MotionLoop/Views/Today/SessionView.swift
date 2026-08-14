import SwiftUI

/// Presented when the user taps into a session -- one activity (today's
/// original single-activity check-in layout, unchanged) or several sharing a
/// Schedule. Each row independently derives whether it can still be completed right now
/// via CompletionService.availability, so a stale sheet opened just as a
/// window closes (or before the next reminder's gap has elapsed) can't be
/// used to sneak in a completion that CompletionService.complete would reject
/// anyway -- this mirrors the real write-path instead of trusting the
/// occurrence's possibly-stale stored status.
struct SessionView: View {
    let occurrences: [ExerciseOccurrence]
    var onComplete: (ExerciseOccurrence) -> Void
    var now: Date = .now
    @Environment(\.dismiss) private var dismiss

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if occurrences.count == 1, let occurrence = occurrences.first {
                    singleActivityView(occurrence)
                } else {
                    List(occurrences) { occurrence in
                        sessionRow(occurrence)
                    }
                    .navigationTitle(ScheduleDisplay.sessionTitle(activityNames: occurrences.map(\.displayActivityName)))
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents(occurrences.count == 1 ? [.medium] : [.medium, .large])
    }

    @ViewBuilder
    private func singleActivityView(_ occurrence: ExerciseOccurrence) -> some View {
        VStack(spacing: 24) {
            Image(systemName: occurrence.displayActivitySymbolName)
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(occurrence.displayActivityName)
                .font(.title2.bold())

            if let targetDescription = occurrence.displayActivityTargetDescription {
                Text(targetDescription)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            completionControl(for: occurrence, fullWidth: true)
                .padding(.top, 8)
        }
        .padding()
    }

    private func sessionRow(_ occurrence: ExerciseOccurrence) -> some View {
        HStack(spacing: 12) {
            Image(systemName: occurrence.displayActivitySymbolName)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(occurrence.displayActivityName).font(.body.weight(.medium))
                if let targetDescription = occurrence.displayActivityTargetDescription {
                    Text(targetDescription).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            completionControl(for: occurrence, fullWidth: false)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func completionControl(for occurrence: ExerciseOccurrence, fullWidth: Bool) -> some View {
        switch CompletionService.availability(for: occurrence, now: now) {
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available:
            Button {
                onComplete(occurrence)
                if occurrences.count == 1 { dismiss() }
            } label: {
                Text("Mark Complete").frame(maxWidth: fullWidth ? .infinity : nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(fullWidth ? .large : .regular)
        case .windowClosed:
            Text("Window Closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        case .gapBlocked(let availableAt):
            Text("Available at \(Self.timeFormatter.string(from: availableAt))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }
}
