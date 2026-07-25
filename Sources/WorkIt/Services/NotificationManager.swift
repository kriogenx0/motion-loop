import Foundation
import UserNotifications

enum NotificationManager {
    static let categoryIdentifier = "EXERCISE_CHECKIN"
    static let completeAction = "MARK_COMPLETE"
    static let missedAction = "MARK_MISSED"

    static func registerCategories() {
        let complete = UNNotificationAction(
            identifier: completeAction, title: "Mark Complete", options: []
        )
        let missed = UNNotificationAction(
            identifier: missedAction, title: "Didn't Do It", options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [complete, missed],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func ensureAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    static func identifier(for ruleID: UUID) -> String { "rule-\(ruleID.uuidString)" }

    /// One repeating UNCalendarNotificationTrigger per ScheduleRule (not per
    /// generated occurrence) -- iOS caps an app at 64 pending local notifications,
    /// so per-instance scheduling over a rolling horizon would break as activities
    /// grow, while one weekly trigger per rule stays flat and auto-adjusts across DST.
    static func syncNotifications(for rules: [ScheduleRuleSnapshot], activityNames: [UUID: String]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for rule in rules {
            var components = DateComponents()
            components.weekday = rule.weekday
            components.hour = rule.hour
            components.minute = rule.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = activityNames[rule.activityID] ?? "Time to check in"
            content.body = "Did you complete it? You have 1 hour to confirm."
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = [
                "ruleID": rule.ruleID.uuidString,
                "activityID": rule.activityID.uuidString,
            ]
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifier(for: rule.ruleID), content: content, trigger: trigger
            )
            center.add(request)
        }
    }

    #if DEBUG
    /// Fires a one-off notification in `seconds` using the same category/actions,
    /// so the full notification -> action -> status-update path can be manually
    /// exercised in Simulator without waiting for a real weekly trigger to fire.
    static func scheduleDebugNotification(activityID: UUID, ruleID: UUID, activityName: String, seconds: TimeInterval = 10) {
        let content = UNMutableNotificationContent()
        content.title = activityName
        content.body = "(debug) Did you complete it?"
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["ruleID": ruleID.uuidString, "activityID": activityID.uuidString]
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "debug-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    #endif
}
