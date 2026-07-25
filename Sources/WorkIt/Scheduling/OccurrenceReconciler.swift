import Foundation

struct OccurrenceSnapshot: Hashable {
    let id: UUID
    let windowEnd: Date
    let status: OccurrenceStatus
}

struct OccurrenceStatusChange: Hashable {
    let id: UUID
    let newStatus: OccurrenceStatus
}

/// Determines which pending occurrences should flip to "missed" because their
/// hour-long window closed without a response. This is how "missed" gets decided --
/// no background task fires exactly at the 1-hour mark; instead this pass runs
/// lazily (on app foreground, before any UI reads occurrence status) and the result
/// is identical regardless of how long the app was closed.
enum OccurrenceReconciler {
    static func reconcile(occurrences: [OccurrenceSnapshot], now: Date) -> [OccurrenceStatusChange] {
        occurrences
            .filter { $0.status == .pending && $0.windowEnd <= now }
            .map { OccurrenceStatusChange(id: $0.id, newStatus: .missed) }
    }
}
