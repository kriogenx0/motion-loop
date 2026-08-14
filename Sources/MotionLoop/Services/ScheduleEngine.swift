import Foundation
import SwiftData

/// Thin SwiftData-facing shell around the pure Scheduling/ functions: fetches
/// current state, calls the pure logic, writes back the results.
enum ScheduleEngine {
    static let horizonDays = 14

    /// Flips overdue pending window-type occurrences to missed, then generates
    /// any new occurrences needed to fill the rolling horizon. Safe to call as
    /// often as needed (on launch, on foreground, after editing a schedule).
    static func reconcileAndGenerate(
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        try reconcile(context: context, now: now)
        try generate(context: context, referenceDate: now, calendar: calendar)
        try context.save()
    }

    private static func reconcile(context: ModelContext, now: Date) throws {
        let pendingDescriptor = FetchDescriptor<ExerciseOccurrence>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )
        let pending = try context.fetch(pendingDescriptor)

        let snapshots = pending.map {
            OccurrenceSnapshot(id: $0.id, windowEnd: $0.windowEnd, status: $0.status)
        }
        let changes = OccurrenceReconciler.reconcile(occurrences: snapshots, now: now)
        guard !changes.isEmpty else { return }

        let changeMap = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0.newStatus) })
        for occurrence in pending {
            if let newStatus = changeMap[occurrence.id] {
                occurrence.status = newStatus
                occurrence.respondedAt = occurrence.respondedAt ?? now
            }
        }
    }

    /// Groups the currently active (non-archived, scheduled) activities by the
    /// Schedule they're attached to -- each group is exactly one "session".
    private static func activeScheduleGroups(context: ModelContext) throws -> [UUID: [Activity]] {
        let activitiesDescriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.isArchived == false }
        )
        let activities = try context.fetch(activitiesDescriptor)
        let scheduledActivities = activities.filter { $0.schedule != nil }
        return Dictionary(grouping: scheduledActivities) { $0.schedule!.id }
    }

    private static func generate(context: ModelContext, referenceDate: Date, calendar: Calendar) throws {
        let schedulesByID = try activeScheduleGroups(context: context)
        let scheduleSnapshots: [ScheduleSnapshot] = schedulesByID.compactMap { scheduleID, activitiesInSchedule in
            guard let schedule = activitiesInSchedule.first?.schedule else { return nil }
            let enabledTimes = schedule.times.filter(\.isEnabled).map(\.snapshot)
            guard !enabledTimes.isEmpty else { return nil }
            return ScheduleSnapshot(
                scheduleID: scheduleID,
                type: schedule.type,
                windowDurationMinutes: schedule.windowDurationMinutes,
                activityIDs: activitiesInSchedule.map(\.id),
                times: enabledTimes
            )
        }
        guard !scheduleSnapshots.isEmpty else { return }

        let horizonStart = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        let existingDescriptor = FetchDescriptor<ExerciseOccurrence>(
            predicate: #Predicate { $0.scheduledDate >= horizonStart }
        )
        let existing = try context.fetch(existingDescriptor)

        var existingKeys: Set<OccurrenceKey> = []
        var existingSessionIDs: [SlotKey: UUID] = [:]
        for occurrence in existing {
            guard let scheduleTimeID = occurrence.sourceScheduleTimeID, let activityID = occurrence.activity?.id else { continue }
            let day = calendar.startOfDay(for: occurrence.scheduledDate)
            existingKeys.insert(OccurrenceKey(scheduleTimeID: scheduleTimeID, day: day, activityID: activityID))
            if let sessionID = occurrence.sessionID {
                existingSessionIDs[SlotKey(scheduleTimeID: scheduleTimeID, day: day)] = sessionID
            }
        }

        let planned = OccurrenceGenerator.generateOccurrences(
            for: scheduleSnapshots,
            existingKeys: existingKeys,
            existingSessionIDs: existingSessionIDs,
            referenceDate: referenceDate,
            horizonDays: horizonDays,
            calendar: calendar
        )
        guard !planned.isEmpty else { return }

        let activitiesByID = Dictionary(
            uniqueKeysWithValues: schedulesByID.values.flatMap { $0 }.map { ($0.id, $0) }
        )
        for plan in planned {
            guard let activity = activitiesByID[plan.activityID] else { continue }
            let occurrence = ExerciseOccurrence(
                scheduledDate: plan.scheduledDate,
                windowEnd: plan.windowEnd,
                sourceScheduleTimeID: plan.scheduleTimeID,
                sessionID: plan.sessionID,
                ruleWeekday: plan.ruleWeekday,
                ruleHour: plan.ruleHour,
                ruleMinute: plan.ruleMinute,
                activityName: activity.name,
                activitySymbolName: activity.symbolName,
                activityTargetDescription: activity.targetDescription
            )
            occurrence.activity = activity
            context.insert(occurrence)
        }
    }

    /// Rebuilds all local notification requests from the currently active
    /// schedules -- one session (Schedule) per group of activities sharing it.
    static func syncNotifications(context: ModelContext) throws {
        let schedulesByID = try activeScheduleGroups(context: context)
        let sessions: [NotificationManager.SessionSchedule] = schedulesByID.compactMap { scheduleID, activitiesInSchedule in
            guard let schedule = activitiesInSchedule.first?.schedule else { return nil }
            let enabledTimes = schedule.times.filter(\.isEnabled).map(\.snapshot)
            guard !enabledTimes.isEmpty else { return nil }
            return NotificationManager.SessionSchedule(
                scheduleID: scheduleID,
                type: schedule.type,
                windowDurationMinutes: schedule.windowDurationMinutes,
                leadTimeMinutes: schedule.leadTimeMinutes,
                activityIDs: activitiesInSchedule.map(\.id),
                activityNames: activitiesInSchedule.map(\.name),
                times: enabledTimes
            )
        }
        NotificationManager.syncNotifications(for: sessions)
    }

    /// Deletes any Schedule with no Activities attached (cascades its
    /// ScheduleTimes) -- called after every activity save/delete so the
    /// "Existing Schedule" picker never shows dead entries left behind by an
    /// activity switching away or being removed.
    static func pruneOrphanedSchedules(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Schedule>()
        let schedules = try context.fetch(descriptor)
        var didDelete = false
        for schedule in schedules where schedule.activities.isEmpty {
            context.delete(schedule)
            didDelete = true
        }
        if didDelete {
            try context.save()
        }
    }
}
