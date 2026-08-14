import Foundation

/// Enforces the minimum-gap-since-last-completion rule for reminder-type
/// (no-window) schedules: since there's no deadline to block completion,
/// gapping prevents rapid back-to-back check-ins from satisfying "3x a day"
/// with three taps in the same minute. Only ever consulted for
/// `Activity.effectiveMode == .reminder`; bonus completions are never passed
/// in as `lastNonBonusCompletionAt` and are never themselves gap-checked, so
/// they can't be used to game or be blocked by this rule.
enum GapEnforcer {
    static func isCompletionAllowed(
        lastNonBonusCompletionAt: Date?,
        minimumGapMinutes: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let nextAllowed = nextAllowedCompletionDate(
            lastNonBonusCompletionAt: lastNonBonusCompletionAt,
            minimumGapMinutes: minimumGapMinutes,
            now: now,
            calendar: calendar
        ) else { return true }
        return now >= nextAllowed
    }

    /// nil = allowed right now (no prior completion to gap against).
    static func nextAllowedCompletionDate(
        lastNonBonusCompletionAt: Date?,
        minimumGapMinutes: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let lastCompletion = lastNonBonusCompletionAt else { return nil }
        return calendar.date(byAdding: .minute, value: minimumGapMinutes, to: lastCompletion)
            ?? lastCompletion.addingTimeInterval(TimeInterval(minimumGapMinutes * 60))
    }

    /// Authoring-time UX guidance only -- a best-effort, same-weekday pairwise
    /// check that does NOT handle midnight-adjacent wraparound (e.g. 11:45pm
    /// and 12:15am the next day). The runtime check above (at actual
    /// completion time) is the real correctness backstop.
    struct TimeEntry {
        let weekday: Int
        let hour: Int
        let minute: Int
    }

    static func violatesMinimumGap(_ entries: [TimeEntry], minimumGapMinutes: Int) -> Bool {
        let byWeekday = Dictionary(grouping: entries, by: \.weekday)
        for sameDayEntries in byWeekday.values {
            let minutesOfDay = sameDayEntries.map { $0.hour * 60 + $0.minute }.sorted()
            for index in 1..<minutesOfDay.count {
                if minutesOfDay[index] - minutesOfDay[index - 1] < minimumGapMinutes {
                    return true
                }
            }
        }
        return false
    }
}
