import Foundation
import Observation

enum AppTab {
    case today, activities, history
}

/// A notification tap resolves to one of these -- either a still-actionable
/// session (SessionView) or a session whose window has closed (MissedSessionView).
enum PendingRoute: Equatable {
    case session(occurrenceIDs: [UUID])
    case missedSession(occurrenceIDs: [UUID])
}

/// Shared navigation state. Lets NotificationDelegate (which has no view hierarchy
/// of its own) request that the UI open a session sheet for specific occurrences.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var pendingRoute: PendingRoute?
}
