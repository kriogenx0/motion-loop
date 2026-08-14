import SwiftUI

/// Renders one session's worth of rows in Today's list. A session with
/// exactly one activity renders as a bare TodayOccurrenceRow -- no visual
/// change from before sessions existed. A session with several shares a
/// caption header ("Push-ups & Crunches") so a multi-activity check-in reads
/// as one group while each activity keeps its own independently-completable
/// row and its own "Bonus" swipe action.
struct SessionCardView: View {
    let occurrences: [ExerciseOccurrence]
    var now: Date
    var showActions: Bool
    var onComplete: (ExerciseOccurrence) -> Void
    var onBonus: (ExerciseOccurrence) -> Void

    var body: some View {
        if occurrences.count > 1 {
            Text(ScheduleDisplay.sessionTitle(activityNames: occurrences.map(\.displayActivityName)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
        }
        ForEach(occurrences) { occurrence in
            TodayOccurrenceRow(
                occurrence: occurrence,
                now: now,
                onComplete: showActions ? { onComplete(occurrence) } : nil
            )
            .swipeActions(edge: .leading) {
                if occurrence.activity != nil {
                    Button {
                        onBonus(occurrence)
                    } label: {
                        Label("Bonus", systemImage: "plus.circle.fill")
                    }
                    .tint(.purple)
                }
            }
        }
    }
}
