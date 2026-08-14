import Foundation

/// Display-only reinterpretation of an occurrence's status -- never mutates
/// anything, unlike OccurrenceReconciler.
///
/// Reminder-type occurrences (`windowEnd == nil`) are never auto-flipped to
/// `.missed` by the reconciler: they have no deadline, so nothing ever
/// "closes" on them, and completion is never blocked. But History/streaks
/// still need an old, never-answered reminder to eventually read as "not
/// done" rather than sitting as "pending" forever. This reconciles the two:
/// a still-`.pending` reminder occurrence reads as `.missed` once its
/// scheduled day has fully elapsed, purely for display/stats -- the stored
/// `status` is untouched, so it's still completable and no notification ever
/// calls it missed.
enum OccurrenceDisplay {
    static func effectiveStatus(
        status: OccurrenceStatus,
        scheduledDate: Date,
        windowEnd: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> OccurrenceStatus {
        guard status == .pending, windowEnd == nil else { return status }
        let scheduledDay = calendar.startOfDay(for: scheduledDate)
        let today = calendar.startOfDay(for: now)
        return scheduledDay >= today ? status : .missed
    }
}
