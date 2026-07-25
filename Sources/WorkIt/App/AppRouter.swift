import Foundation
import Observation

enum AppTab {
    case today, activities, history
}

/// Shared navigation state. Lets NotificationDelegate (which has no view hierarchy
/// of its own) request that the UI open a check-in sheet for a specific occurrence.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var pendingCheckInOccurrenceID: UUID?
}
