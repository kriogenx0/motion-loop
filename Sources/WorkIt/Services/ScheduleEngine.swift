import Foundation
import SwiftData

/// Thin SwiftData-facing shell around the pure Scheduling/ functions: fetches
/// current state, calls the pure logic, writes back the results.
enum ScheduleEngine {
    static let horizonDays = 14

    /// Flips overdue pending occurrences to missed, then generates any new
    /// occurrences needed to fill the rolling horizon. Safe to call as often as
    /// needed (on launch, on foreground, after editing a schedule).
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

    private static func generate(context: ModelContext, referenceDate: Date, calendar: Calendar) throws {
        let activitiesDescriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.isArchived == false }
        )
        let activities = try context.fetch(activitiesDescriptor)
        let ruleSnapshots = activities
            .flatMap { $0.scheduleRules.filter(\.isEnabled) }
            .map(\.snapshot)
        guard !ruleSnapshots.isEmpty else { return }

        let horizonStart = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        let existingDescriptor = FetchDescriptor<ExerciseOccurrence>(
            predicate: #Predicate { $0.scheduledDate >= horizonStart }
        )
        let existing = try context.fetch(existingDescriptor)
        let existingKeys = Set(existing.compactMap { occurrence -> OccurrenceKey? in
            guard let ruleID = occurrence.sourceRuleID else { return nil }
            return OccurrenceKey(ruleID: ruleID, day: calendar.startOfDay(for: occurrence.scheduledDate))
        })

        let planned = OccurrenceGenerator.generateOccurrences(
            for: ruleSnapshots,
            existingKeys: existingKeys,
            referenceDate: referenceDate,
            horizonDays: horizonDays,
            calendar: calendar
        )
        guard !planned.isEmpty else { return }

        let activitiesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        for plan in planned {
            guard let activity = activitiesByID[plan.activityID] else { continue }
            let occurrence = ExerciseOccurrence(
                scheduledDate: plan.scheduledDate,
                windowEnd: plan.windowEnd,
                sourceRuleID: plan.ruleID,
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

    /// Rebuilds all local notification requests from the currently active rules.
    static func syncNotifications(context: ModelContext) throws {
        let activitiesDescriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.isArchived == false }
        )
        let activities = try context.fetch(activitiesDescriptor)
        let names = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0.name) })
        let rules = activities
            .flatMap { $0.scheduleRules.filter(\.isEnabled) }
            .map(\.snapshot)
        NotificationManager.syncNotifications(for: rules, activityNames: names)
    }
}
