import Foundation

enum SessionBucket: Equatable {
    case activeNow
    case upcoming
    case completed
    case missed
}

/// Minimal occurrence view needed to group/bucket sessions, decoupled from
/// SwiftData.
struct SessionOccurrenceSnapshot: Hashable {
    let id: UUID
    let sessionID: UUID?
    let scheduledDate: Date
    let windowEnd: Date?
    let status: OccurrenceStatus
}

/// A "session" isn't a stored entity -- it's the set of occurrences sharing a
/// sessionID (activities that share a Schedule and fired from the same
/// ScheduleTime on the same day). Occurrences with no sessionID (freeform) are
/// a session of one, grouped by their own id, so they flow through the same
/// rendering path with no special-casing.
enum SessionGrouping {
    static func groupIntoSessions(_ occurrences: [SessionOccurrenceSnapshot]) -> [[SessionOccurrenceSnapshot]] {
        var order: [UUID] = []
        var groups: [UUID: [SessionOccurrenceSnapshot]] = [:]
        for occurrence in occurrences {
            let key = occurrence.sessionID ?? occurrence.id
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(occurrence)
        }
        return order.compactMap { groups[$0] }
    }

    /// Rollup rule: if any occurrence in the session is still pending, bucket
    /// by the earliest-open one (activeNow if its window is open, or it's a
    /// reminder-type slot whose time has arrived; upcoming otherwise). Once
    /// none are pending, the session is fully resolved: completed only if ALL
    /// completed, else missed -- partial completion is a UI badge ("2/3
    /// done"), not a fifth bucket.
    static func bucket(for session: [SessionOccurrenceSnapshot], now: Date) -> SessionBucket {
        let pending = session.filter { $0.status == .pending }
        if !pending.isEmpty {
            let earliest = pending.min { $0.scheduledDate < $1.scheduledDate }!
            let isOpen: Bool
            if let windowEnd = earliest.windowEnd {
                isOpen = earliest.scheduledDate <= now && now < windowEnd
            } else {
                isOpen = earliest.scheduledDate <= now
            }
            return isOpen ? .activeNow : .upcoming
        }
        return session.allSatisfy { $0.status == .completed } ? .completed : .missed
    }
}
