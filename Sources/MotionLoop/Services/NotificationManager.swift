import Foundation
import UserNotifications

enum NotificationManager {
    static let categorySingle = "EXERCISE_CHECKIN_SINGLE"
    static let categorySession = "EXERCISE_CHECKIN_SESSION"
    static let categoryMissed = "EXERCISE_MISSED"
    static let completeAction = "MARK_COMPLETE"

    /// Everything NotificationManager needs to schedule one Schedule's
    /// notifications, already resolved to the activities currently attached to
    /// it (i.e. the session).
    struct SessionSchedule {
        let scheduleID: UUID
        let type: ScheduleType
        /// nil unless type == .window.
        let windowDurationMinutes: Int?
        let leadTimeMinutes: Int?
        let activityIDs: [UUID]
        let activityNames: [String]
        let times: [ScheduleTimeSnapshot]
    }

    /// Three categories, since a "Mark Complete" quick action only makes sense
    /// when a notification refers to exactly one activity:
    /// - single: one activity on the schedule -- has the quick action.
    /// - session: 2+ activities -- tap-only, forces opening SessionView to
    ///   check them off individually.
    /// - missed: the window-closed notification -- tap-only, opens a read-only
    ///   missed view, never lets you complete from it.
    static func registerCategories() {
        let complete = UNNotificationAction(identifier: completeAction, title: "Mark Complete", options: [])
        let singleCategory = UNNotificationCategory(
            identifier: categorySingle, actions: [complete], intentIdentifiers: [], options: []
        )
        let sessionCategory = UNNotificationCategory(
            identifier: categorySession, actions: [], intentIdentifiers: [], options: []
        )
        let missedCategory = UNNotificationCategory(
            identifier: categoryMissed, actions: [], intentIdentifiers: [], options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([singleCategory, sessionCategory, missedCategory])
    }

    static func ensureAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
        }
    }

    static func atTimeIdentifier(for scheduleTimeID: UUID) -> String { "time-\(scheduleTimeID.uuidString)" }
    static func leadIdentifier(for scheduleTimeID: UUID) -> String { "time-\(scheduleTimeID.uuidString)-lead" }
    static func missedIdentifier(for scheduleTimeID: UUID) -> String { "time-\(scheduleTimeID.uuidString)-missed" }

    /// Up to 3 repeating UNCalendarNotificationTriggers per ScheduleTime (not
    /// per generated occurrence) -- iOS caps an app at 64 pending local
    /// notifications, so per-instance scheduling over a rolling horizon would
    /// break as activities grow, while weekly triggers per time stay flat and
    /// auto-adjust across DST. Iterating per-ScheduleTime -- shared by every
    /// activity attached to a Schedule -- rather than per-(activity, time) is
    /// what collapses a multi-activity session into one notification for free.
    ///
    /// Local notifications have no server behind them, so suppression of an
    /// already-answered notification can't be perfect once it's been
    /// scheduled -- NotificationDelegate.willPresent cancels it when the app
    /// is running to receive that callback, but if the app was fully
    /// terminated it may still show even though the user already responded --
    /// an accepted limitation of local-only notifications.
    static func syncNotifications(for sessions: [SessionSchedule]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for session in sessions {
            let title = ScheduleDisplay.sessionTitle(activityNames: session.activityNames)
            let category = session.activityIDs.count == 1 ? categorySingle : categorySession
            let atTimeBody = session.activityIDs.count == 1
                ? (session.type == .window ? "Did you complete it? Confirm before the window closes." : "Time to check in.")
                : "\(session.activityIDs.count) activities to check off."

            for time in session.times {
                addRequest(
                    identifier: atTimeIdentifier(for: time.scheduleTimeID),
                    weekday: time.weekday, hour: time.hour, minute: time.minute,
                    title: title, body: atTimeBody, category: category,
                    scheduleTimeID: time.scheduleTimeID, scheduleID: session.scheduleID,
                    activityIDs: session.activityIDs, kind: "atTime", timeSensitive: false, center: center
                )

                if let leadTimeMinutes = session.leadTimeMinutes {
                    let lead = ScheduleMath.addingMinutes(
                        -leadTimeMinutes, toWeekday: time.weekday, hour: time.hour, minute: time.minute
                    )
                    addRequest(
                        identifier: leadIdentifier(for: time.scheduleTimeID),
                        weekday: lead.weekday, hour: lead.hour, minute: lead.minute,
                        title: title, body: "Coming up in \(leadTimeMinutes) min", category: category,
                        scheduleTimeID: time.scheduleTimeID, scheduleID: session.scheduleID,
                        activityIDs: session.activityIDs, kind: "lead", timeSensitive: false, center: center
                    )
                }

                if session.type == .window, let windowDurationMinutes = session.windowDurationMinutes {
                    let missed = ScheduleMath.addingMinutes(
                        windowDurationMinutes, toWeekday: time.weekday, hour: time.hour, minute: time.minute
                    )
                    addRequest(
                        identifier: missedIdentifier(for: time.scheduleTimeID),
                        weekday: missed.weekday, hour: missed.hour, minute: missed.minute,
                        title: "\u{274c} \(title)", body: "You missed it.", category: categoryMissed,
                        scheduleTimeID: time.scheduleTimeID, scheduleID: session.scheduleID,
                        activityIDs: session.activityIDs, kind: "missed", timeSensitive: true, center: center
                    )
                }
            }
        }
    }

    private static func addRequest(
        identifier: String,
        weekday: Int, hour: Int, minute: Int,
        title: String, body: String, category: String,
        scheduleTimeID: UUID, scheduleID: UUID, activityIDs: [UUID], kind: String, timeSensitive: Bool,
        center: UNUserNotificationCenter
    ) {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.userInfo = [
            "scheduleTimeID": scheduleTimeID.uuidString,
            "scheduleID": scheduleID.uuidString,
            "activityIDs": activityIDs.map(\.uuidString),
            "kind": kind,
        ]
        content.sound = .default
        if timeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    #if DEBUG
    /// Fires a one-off notification in `seconds` using the same
    /// category/userInfo shape as the real triggers, so the full notification
    /// -> action -> status-update path can be manually exercised in Simulator
    /// without waiting for a real weekly trigger to fire.
    static func scheduleDebugNotification(
        activityNames: [String],
        activityIDs: [UUID],
        scheduleTimeID: UUID = UUID(),
        scheduleID: UUID = UUID(),
        kind: String = "atTime",
        seconds: TimeInterval = 10
    ) {
        let title = ScheduleDisplay.sessionTitle(activityNames: activityNames)
        let content = UNMutableNotificationContent()
        content.title = kind == "missed" ? "\u{274c} \(title)" : title
        content.body = "(debug) \(kind)"
        content.categoryIdentifier = kind == "missed" ? categoryMissed : (activityIDs.count == 1 ? categorySingle : categorySession)
        content.userInfo = [
            "scheduleTimeID": scheduleTimeID.uuidString,
            "scheduleID": scheduleID.uuidString,
            "activityIDs": activityIDs.map(\.uuidString),
            "kind": kind,
        ]
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "debug-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    #endif
}
