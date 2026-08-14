import Foundation

enum ActivityDayOutcome: Equatable {
    case metGoal
    case missedGoal
    case notScheduled
    case undecided
}

/// Computes an activity's current daily streak. Bonus completions are never
/// passed in here at all (they aren't ExerciseOccurrence rows), which is what
/// makes them structurally unable to affect streaks -- not just a filter that
/// could be forgotten.
enum StreakCalculator {
    struct StreakOccurrence {
        let scheduledDate: Date
        /// Caller applies ExerciseOccurrence.effectiveStatus(now:) before
        /// passing this in, so a stale reminder from a past day already reads
        /// as .missed here without StreakCalculator needing its own now/window
        /// logic.
        let status: OccurrenceStatus
    }

    /// - hasSchedule: false for freeform activities (met by any completion
    ///   that day); true for window/reminder activities (met only if every
    ///   occurrence that day was completed).
    /// - isPastDay: true for any day strictly before `now`'s calendar day.
    static func dayOutcome(
        occurrencesOnDay: [StreakOccurrence],
        hasSchedule: Bool,
        isPastDay: Bool
    ) -> ActivityDayOutcome {
        if !hasSchedule {
            if occurrencesOnDay.contains(where: { $0.status == .completed }) { return .metGoal }
            return isPastDay ? .missedGoal : .undecided
        }

        guard !occurrencesOnDay.isEmpty else { return .notScheduled }
        if occurrencesOnDay.contains(where: { $0.status == .missed }) { return .missedGoal }
        if occurrencesOnDay.allSatisfy({ $0.status == .completed }) { return .metGoal }
        return isPastDay ? .missedGoal : .undecided
    }

    /// Walks backward day-by-day from `today`: a met day extends the streak, a
    /// notScheduled/undecided day is skipped without breaking it (so a
    /// Mon/Wed/Fri activity's streak isn't broken by the intervening Tue/Thu),
    /// and a missed day stops the walk.
    static func currentStreak(
        occurrences: [StreakOccurrence],
        hasSchedule: Bool,
        today: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        var byDay: [Date: [StreakOccurrence]] = [:]
        for occurrence in occurrences {
            let day = calendar.startOfDay(for: occurrence.scheduledDate)
            byDay[day, default: []].append(occurrence)
        }
        // No history at all -- nothing to walk back through. Also bounds the
        // walk below: days before the earliest known occurrence carry no
        // information (the activity/schedule didn't exist yet), so treating
        // them as an endless run of skippable "notScheduled" days would walk
        // back indefinitely instead of stopping.
        guard let earliestDay = byDay.keys.min() else { return 0 }

        let todayStart = calendar.startOfDay(for: today)
        var streak = 0
        var cursor = todayStart
        while cursor >= earliestDay {
            let isPastDay = cursor < calendar.startOfDay(for: now)
            let outcome = dayOutcome(
                occurrencesOnDay: byDay[cursor] ?? [], hasSchedule: hasSchedule, isPastDay: isPastDay
            )
            switch outcome {
            case .metGoal:
                streak += 1
            case .notScheduled, .undecided:
                break
            case .missedGoal:
                return streak
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
