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

    /// Adds `minutes` to a bare (weekday, hour, minute) -- used to compute a
    /// reminder trigger time from a rule's time-of-day. Handles hour/day rollover
    /// (and wrapping Saturday -> Sunday) via real Calendar arithmetic on a stable
    /// anchor week rather than manual mod math.
    static func addingMinutes(
        _ minutes: Int,
        toWeekday weekday: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> (weekday: Int, hour: Int, minute: Int) {
        // January 5, 2025 is a Sunday (weekday 1); weekday N is that anchor week's
        // (N-1)th day, so this works for any weekday 1...7 without special-casing.
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 5 + (weekday - 1)
        components.hour = hour
        components.minute = minute
        guard
            let anchor = calendar.date(from: components),
            let shifted = calendar.date(byAdding: .minute, value: minutes, to: anchor)
        else {
            return (weekday, hour, minute)
        }
        return (
            calendar.component(.weekday, from: shifted),
            calendar.component(.hour, from: shifted),
            calendar.component(.minute, from: shifted)
        )
    }
}
