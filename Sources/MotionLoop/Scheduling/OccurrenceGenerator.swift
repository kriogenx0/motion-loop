import Foundation

/// Identifies one occurrence's "slot" -- a given rule firing on a given calendar day --
/// used to avoid generating duplicate occurrences for the same slot.
struct OccurrenceKey: Hashable {
    let ruleID: UUID
    let day: Date
}

struct PlannedOccurrence {
    let activityID: UUID
    let ruleID: UUID
    let scheduledDate: Date
    let windowEnd: Date
    let ruleWeekday: Int
    let ruleHour: Int
    let ruleMinute: Int
}

enum OccurrenceGenerator {
    /// Pure function: given the currently active rules and the set of slots that
    /// already have an occurrence, returns the occurrences that should be inserted
    /// to fill the rolling horizon starting at `referenceDate`.
    static func generateOccurrences(
        for rules: [ScheduleRuleSnapshot],
        existingKeys: Set<OccurrenceKey>,
        referenceDate: Date,
        horizonDays: Int = 14,
        calendar: Calendar = .current
    ) -> [PlannedOccurrence] {
        let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: referenceDate) ?? referenceDate

        var planned: [PlannedOccurrence] = []
        for rule in rules {
            // Strictly after `referenceDate` (not shifted back a day) -- a rule
            // whose time-of-day already passed today must never generate today's
            // slot, otherwise a newly-added activity immediately shows a "missed"
            // occurrence for a moment that existed before the activity did.
            let candidates = ScheduleMath.nextOccurrenceDates(
                for: rule,
                after: referenceDate,
                count: horizonDays + 1,
                calendar: calendar
            )
            for date in candidates where date <= horizonEnd {
                let key = OccurrenceKey(ruleID: rule.ruleID, day: calendar.startOfDay(for: date))
                guard !existingKeys.contains(key) else { continue }
                let end = ScheduleMath.windowEnd(
                    for: date, durationMinutes: rule.windowDurationMinutes, calendar: calendar
                )
                planned.append(
                    PlannedOccurrence(
                        activityID: rule.activityID,
                        ruleID: rule.ruleID,
                        scheduledDate: date,
                        windowEnd: end,
                        ruleWeekday: rule.weekday,
                        ruleHour: rule.hour,
                        ruleMinute: rule.minute
                    )
                )
            }
        }
        return planned
    }
}
