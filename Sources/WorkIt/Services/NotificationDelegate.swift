import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let router: AppRouter
    let modelContainer: ModelContainer

    init(router: AppRouter, modelContainer: ModelContainer) {
        self.router = router
        self.modelContainer = modelContainer
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard
            let ruleIDString = userInfo["ruleID"] as? String,
            let ruleID = UUID(uuidString: ruleIDString),
            let activityIDString = userInfo["activityID"] as? String,
            let activityID = UUID(uuidString: activityIDString)
        else { return }

        let context = ModelContext(modelContainer)
        guard let occurrence = try? Self.findOrCreateTodayOccurrence(
            ruleID: ruleID, activityID: activityID, context: context, now: .now
        ) else { return }

        switch response.actionIdentifier {
        case NotificationManager.completeAction:
            occurrence.status = .completed
            occurrence.respondedAt = .now
            try? context.save()
        case NotificationManager.missedAction:
            occurrence.status = .missed
            occurrence.respondedAt = .now
            try? context.save()
        case UNNotificationDefaultActionIdentifier:
            router.pendingCheckInOccurrenceID = occurrence.id
            router.selectedTab = .today
        default:
            break
        }
    }

    /// Self-healing lookup: if today's occurrence for this rule doesn't already
    /// exist (the generator hasn't run recently enough), synthesize it from the
    /// rule data rather than silently dropping the notification response.
    private static func findOrCreateTodayOccurrence(
        ruleID: UUID,
        activityID: UUID,
        context: ModelContext,
        now: Date
    ) throws -> ExerciseOccurrence? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let existingDescriptor = FetchDescriptor<ExerciseOccurrence>(
            predicate: #Predicate { $0.sourceRuleID == ruleID && $0.scheduledDate >= dayStart }
        )
        if let existing = try context.fetch(existingDescriptor).first {
            return existing
        }

        let activityDescriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.id == activityID }
        )
        guard
            let activity = try context.fetch(activityDescriptor).first,
            let rule = activity.scheduleRules.first(where: { $0.id == ruleID })
        else { return nil }

        let scheduledDate = calendar.date(
            bySettingHour: rule.hour, minute: rule.minute, second: 0, of: now
        ) ?? now
        let windowEnd = ScheduleMath.windowEnd(
            for: scheduledDate, durationMinutes: rule.windowDurationMinutes, calendar: calendar
        )
        let occurrence = ExerciseOccurrence(
            scheduledDate: scheduledDate,
            windowEnd: windowEnd,
            sourceRuleID: rule.id,
            ruleWeekday: rule.weekday,
            ruleHour: rule.hour,
            ruleMinute: rule.minute
        )
        occurrence.activity = activity
        context.insert(occurrence)
        try context.save()
        return occurrence
    }
}
