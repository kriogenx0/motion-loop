import Foundation
import SwiftData

/// An extra, unscheduled completion of an activity -- logged on top of its
/// normal schedule (e.g. an extra set of push-ups outside the usual times).
/// Deliberately its own entity rather than a flag on ExerciseOccurrence: it
/// must never be counted by streaks, WeeklyStats, or the reminder-type gap
/// check, and keeping it out of ExerciseOccurrence entirely makes that
/// structural rather than dependent on every stat call site remembering to
/// filter it out.
@Model
final class BonusCompletion {
    @Attribute(.unique) var id: UUID
    var completedAt: Date

    /// Snapshot of the activity's display fields at the moment this was logged,
    /// same survives-deletion rationale as ExerciseOccurrence's activityName/etc.
    var activityName: String
    var activitySymbolName: String

    var activity: Activity?

    init(
        id: UUID = UUID(),
        completedAt: Date = .now,
        activityName: String,
        activitySymbolName: String
    ) {
        self.id = id
        self.completedAt = completedAt
        self.activityName = activityName
        self.activitySymbolName = activitySymbolName
    }
}
