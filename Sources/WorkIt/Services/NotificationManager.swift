import Foundation
import UserNotifications

enum NotificationManager {
    static let categoryIdentifier = "EXERCISE_CHECKIN"
    static let completeAction = "MARK_COMPLETE"
    static let missedAction = "MARK_MISSED"
    /// Minutes after the window opens that the more insistent follow-up fires,
    /// if the user hasn't answered yet.
    static let reminderOffsetMinutes = 30

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
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
        }
    }

    static func identifier(for ruleID: UUID) -> String { "rule-\(ruleID.uuidString)" }
    static func reminderIdentifier(for ruleID: UUID) -> String { "rule-\(ruleID.uuidString)-reminder" }

    /// Two repeating UNCalendarNotificationTriggers per ScheduleRule (not per
    /// generated occurrence) -- iOS caps an app at 64 pending local notifications,
    /// so per-instance scheduling over a rolling horizon would break as activities
    /// grow, while weekly triggers per rule stay flat and auto-adjust across DST.
    ///
    /// The second trigger is a more insistent follow-up `reminderOffsetMinutes`
    /// later, in case the user hasn't answered the first one. Local notifications
    /// have no server behind them, so this can't be perfectly suppressed once the
    /// activity is completed early: NotificationDelegate.willPresent cancels it
    /// when the app is running to receive that callback, but if the app was fully
    /// terminated the reminder may still show even though the user already
    /// responded -- an accepted limitation of local-only notifications.
    static func syncNotifications(for rules: [ScheduleRuleSnapshot], activityNames: [UUID: String]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for rule in rules {
            let activityName = activityNames[rule.activityID] ?? "Time to check in"

            var components = DateComponents()
            components.weekday = rule.weekday
            components.hour = rule.hour
            components.minute = rule.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let content = makeContent(
                activityName: activityName,
                body: "Did you complete it? You have 1 hour to confirm.",
                ruleID: rule.ruleID,
                activityID: rule.activityID,
                timeSensitive: false
            )
            center.add(UNNotificationRequest(identifier: identifier(for: rule.ruleID), content: content, trigger: trigger))

            let reminderTime = ScheduleMath.addingMinutes(
                reminderOffsetMinutes, toWeekday: rule.weekday, hour: rule.hour, minute: rule.minute
            )
            var reminderComponents = DateComponents()
            reminderComponents.weekday = reminderTime.weekday
            reminderComponents.hour = reminderTime.hour
            reminderComponents.minute = reminderTime.minute
            let reminderTrigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: true)
            let reminderContent = makeContent(
                activityName: activityName,
                body: "Still haven't checked in for \(activityName) -- less than 30 minutes left!",
                ruleID: rule.ruleID,
                activityID: rule.activityID,
                timeSensitive: true
            )
            center.add(UNNotificationRequest(
                identifier: reminderIdentifier(for: rule.ruleID), content: reminderContent, trigger: reminderTrigger
            ))
        }
    }

    private static func makeContent(
        activityName: String,
        body: String,
        ruleID: UUID,
        activityID: UUID,
        timeSensitive: Bool
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = timeSensitive ? "\u{23f0} \(activityName)" : activityName
        content.body = body
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "ruleID": ruleID.uuidString,
            "activityID": activityID.uuidString,
        ]
        content.sound = .default
        if timeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        return content
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
