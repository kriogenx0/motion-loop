import SwiftUI

/// Read-only. Presented when the user taps a "You missed it" notification --
/// unlike SessionView, there is never a Mark Complete action available here,
/// by design: once the window has closed it's closed, full stop.
struct MissedSessionView: View {
    let occurrences: [ExerciseOccurrence]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(occurrences) { occurrence in
                HStack(spacing: 12) {
                    Image(systemName: occurrence.displayActivitySymbolName)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(occurrence.displayActivityName).font(.body.weight(.medium))
                        if let targetDescription = occurrence.displayActivityTargetDescription {
                            Text(targetDescription).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
                .padding(.vertical, 4)
            }
            .safeAreaInset(edge: .top) {
                Text("This window has closed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .navigationTitle(ScheduleDisplay.sessionTitle(activityNames: occurrences.map(\.displayActivityName)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
