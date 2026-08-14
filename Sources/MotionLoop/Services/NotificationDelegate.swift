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

    /// Best-effort suppression: if every occurrence in this session was
    /// already answered (e.g. completed via the "atTime" notification's quick
    /// action, or a "missed" notification whose session got completed just
    /// before the window closed) and the app happens to be running to receive
    /// this callback, skip presenting it. Local notifications have no server
    /// behind them, so this can't help if the app was fully terminated
    /// between triggers -- an accepted limitation.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if let scheduleTimeID = Self.uuid(userInfo["scheduleTimeID"]),
           let activityIDs = Self.uuids(userInfo["activityIDs"]),
           let kind = userInfo["kind"] as? String,
           kind == "atTime" || kind == "missed" {
            let context = ModelContext(modelContainer)
            let dayStart = Calendar.current.startOfDay(for: .now)
            if let occurrences = try? Self.existingTodayOccurrences(
                scheduleTimeID: scheduleTimeID, activityIDs: activityIDs, context: context, dayStart: dayStart
            ), !occurrences.isEmpty, occurrences.allSatisfy({ $0.status == .completed }) {
                return []
            }
        }
        // `.list` keeps the notification in Notification Center after the banner
        // dismisses -- without it, foregrounded banners disappear without a trace.
        return [.banner, .sound, .badge, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard
            let scheduleTimeID = Self.uuid(userInfo["scheduleTimeID"]),
            let activityIDs = Self.uuids(userInfo["activityIDs"]),
            let kind = userInfo["kind"] as? String,
            !activityIDs.isEmpty
        else { return }

        let context = ModelContext(modelContainer)
        guard
            let occurrences = try? Self.findOrCreateTodayOccurrences(
                scheduleTimeID: scheduleTimeID, activityIDs: activityIDs, context: context, now: .now
            ),
            !occurrences.isEmpty
        else { return }

        switch response.actionIdentifier {
        case NotificationManager.completeAction:
            // Only ever attached to the single-activity category, so there's
            // exactly one occurrence to resolve.
            if let occurrence = occurrences.first {
                CompletionService.complete(occurrence: occurrence, context: context)
            }
        case UNNotificationDefaultActionIdentifier:
            let occurrenceIDs = occurrences.map(\.id)
            router.pendingRoute = kind == "missed" ? .missedSession(occurrenceIDs: occurrenceIDs) : .session(occurrenceIDs: occurrenceIDs)
            router.selectedTab = .today
        default:
            break
        }
    }

    private static func uuid(_ value: Any?) -> UUID? {
        (value as? String).flatMap(UUID.init)
    }

    private static func uuids(_ value: Any?) -> [UUID]? {
        (value as? [String])?.compactMap(UUID.init)
    }

    private static func existingTodayOccurrences(
        scheduleTimeID: UUID,
        activityIDs: [UUID],
        context: ModelContext,
        dayStart: Date
    ) throws -> [ExerciseOccurrence] {
        let descriptor = FetchDescriptor<ExerciseOccurrence>(
            predicate: #Predicate { $0.sourceScheduleTimeID == scheduleTimeID && $0.scheduledDate >= dayStart }
        )
        let all = try context.fetch(descriptor)
        let activityIDSet = Set(activityIDs)
        return all.filter { occurrence in
            guard let activityID = occurrence.activity?.id else { return false }
            return activityIDSet.contains(activityID)
        }
    }

    /// Self-healing lookup: if today's occurrences for this session don't
    /// already exist (the generator hasn't run recently enough), synthesize
    /// them from the ScheduleTime/Schedule data rather than silently dropping
    /// the notification response. Any newly-synthesized occurrences share one
    /// fresh sessionID (or the existing one, if some siblings already exist).
    private static func findOrCreateTodayOccurrences(
        scheduleTimeID: UUID,
        activityIDs: [UUID],
        context: ModelContext,
        now: Date
    ) throws -> [ExerciseOccurrence] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let existing = try existingTodayOccurrences(
            scheduleTimeID: scheduleTimeID, activityIDs: activityIDs, context: context, dayStart: dayStart
        )
        let existingByActivity = Dictionary(uniqueKeysWithValues: existing.compactMap { occurrence -> (UUID, ExerciseOccurrence)? in
            guard let activityID = occurrence.activity?.id else { return nil }
            return (activityID, occurrence)
        })

        let missingActivityIDs = activityIDs.filter { existingByActivity[$0] == nil }
        guard !missingActivityIDs.isEmpty else {
            return activityIDs.compactMap { existingByActivity[$0] }
        }

        let timeDescriptor = FetchDescriptor<ScheduleTime>(predicate: #Predicate { $0.id == scheduleTimeID })
        guard let scheduleTime = try context.fetch(timeDescriptor).first, let schedule = scheduleTime.schedule else {
            return activityIDs.compactMap { existingByActivity[$0] }
        }

        let activitiesDescriptor = FetchDescriptor<Activity>(predicate: #Predicate { missingActivityIDs.contains($0.id) })
        let activitiesToCreate = try context.fetch(activitiesDescriptor)

        let scheduledDate = calendar.date(
            bySettingHour: scheduleTime.hour, minute: scheduleTime.minute, second: 0, of: now
        ) ?? now
        let windowEnd: Date? = schedule.type == .window
            ? schedule.windowDurationMinutes.map {
                ScheduleMath.windowEnd(for: scheduledDate, durationMinutes: $0, calendar: calendar)
            }
            : nil
        let sessionID = existing.first?.sessionID ?? UUID()

        var created: [ExerciseOccurrence] = []
        for activity in activitiesToCreate {
            let occurrence = ExerciseOccurrence(
                scheduledDate: scheduledDate,
                windowEnd: windowEnd,
                sourceScheduleTimeID: scheduleTime.id,
                sessionID: sessionID,
                ruleWeekday: scheduleTime.weekday,
                ruleHour: scheduleTime.hour,
                ruleMinute: scheduleTime.minute,
                activityName: activity.name,
                activitySymbolName: activity.symbolName,
                activityTargetDescription: activity.targetDescription
            )
            occurrence.activity = activity
            context.insert(occurrence)
            created.append(occurrence)
        }
        try context.save()

        return activityIDs.compactMap { existingByActivity[$0] } + created
    }
}
