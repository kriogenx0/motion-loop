import Foundation

/// Immutable snapshot of a ScheduleRule's fields, decoupled from SwiftData so the
/// scheduling math below can be pure Foundation code, testable with injected
/// Calendar/TimeZone/Date.
struct ScheduleRuleSnapshot: Hashable {
    let ruleID: UUID
    let activityID: UUID
    /// 1 = Sunday ... 7 = Saturday
    let weekday: Int
    let hour: Int
    let minute: Int
    let windowDurationMinutes: Int
}

enum ScheduleMath {
    /// Finds the next `count` dates matching the rule's weekday/hour/minute, strictly
    /// after `date`. Walks forward day-by-day rather than using Foundation's
    /// `nextDate(matching:)`, whose multi-component matching has surprising edge
    /// cases -- this keeps DST behavior explicit and easy to unit test.
    static func nextOccurrenceDates(
        for rule: ScheduleRuleSnapshot,
        after date: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }
        var results: [Date] = []
        var cursor = calendar.startOfDay(for: date)
        var daysScanned = 0
        let maxDaysToScan = 7 * 53 * max(count, 1)

        while results.count < count && daysScanned < maxDaysToScan {
            if calendar.component(.weekday, from: cursor) == rule.weekday,
               let candidate = calendar.date(
                   bySettingHour: rule.hour, minute: rule.minute, second: 0, of: cursor
               ),
               candidate > date {
                results.append(candidate)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            daysScanned += 1
        }
        return results
    }

    /// End of the completion window. Falls back to a raw time-interval add on the
    /// rare case `date(byAdding:)` returns nil, so callers never have to unwrap.
    static func windowEnd(
        for scheduledDate: Date,
        durationMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(byAdding: .minute, value: durationMinutes, to: scheduledDate)
            ?? scheduledDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
}
