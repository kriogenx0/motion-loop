import Foundation

struct OccurrenceSnapshot: Hashable {
    let id: UUID
    let windowEnd: Date?
    let status: OccurrenceStatus
}

struct OccurrenceStatusChange: Hashable {
    let id: UUID
    let newStatus: OccurrenceStatus
}

/// Determines which pending occurrences should flip to "missed" because their
/// window closed without a response. This is how "missed" gets decided -- no
/// background task fires exactly at the deadline; instead this pass runs
/// lazily (on app foreground, before any UI reads occurrence status) and the
/// result is identical regardless of how long the app was closed.
///
/// Only occurrences with a `windowEnd` (window-type schedules) are ever
/// eligible: reminder-type and freeform occurrences have no deadline and are
/// never auto-flipped, at any age -- see ExerciseOccurrence.effectiveStatus /
/// OccurrenceDisplay for how History still shows old unanswered reminders as
/// "not done" without mutating their real status.
enum OccurrenceReconciler {
    static func reconcile(occurrences: [OccurrenceSnapshot], now: Date) -> [OccurrenceStatusChange] {
        occurrences
            .filter { $0.status == .pending && ($0.windowEnd.map { $0 <= now } ?? false) }
            .map { OccurrenceStatusChange(id: $0.id, newStatus: .missed) }
    }
}
