import XCTest
@testable import MotionLoop

final class StreakCalculatorTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    // MARK: - Freeform

    func testFreeformDayOutcomeMetGoalWithAnyCompletion() {
        let occurrences = [StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .completed)]
        let outcome = StreakCalculator.dayOutcome(occurrencesOnDay: occurrences, hasSchedule: false, isPastDay: true)
        XCTAssertEqual(outcome, .metGoal)
    }

    func testFreeformDayOutcomeMissedGoalWhenPastDayWithNoCompletion() {
        let outcome = StreakCalculator.dayOutcome(occurrencesOnDay: [], hasSchedule: false, isPastDay: true)
        XCTAssertEqual(outcome, .missedGoal)
    }

    func testFreeformDayOutcomeUndecidedWhenTodayWithNoCompletionYet() {
        let outcome = StreakCalculator.dayOutcome(occurrencesOnDay: [], hasSchedule: false, isPastDay: false)
        XCTAssertEqual(outcome, .undecided)
    }

    func testFreeformCurrentStreakCountsConsecutiveCompletedDays() {
        let occurrences = [
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 2, 9), status: .completed),
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 3, 9), status: .completed),
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .completed),
        ]
        let now = date(2025, 6, 4, 20, 0)

        let streak = StreakCalculator.currentStreak(occurrences: occurrences, hasSchedule: false, today: now, now: now, calendar: calendar)

        XCTAssertEqual(streak, 3)
    }

    // MARK: - Scheduled

    func testScheduledDayOutcomeNotScheduledWhenNoOccurrences() {
        let outcome = StreakCalculator.dayOutcome(occurrencesOnDay: [], hasSchedule: true, isPastDay: true)
        XCTAssertEqual(outcome, .notScheduled)
    }

    func testScheduledDayOutcomeMissedGoalWhenAnyOccurrenceIsMissed() {
        let occurrences = [
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .completed),
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 18), status: .missed),
        ]
        let outcome = StreakCalculator.dayOutcome(occurrencesOnDay: occurrences, hasSchedule: true, isPastDay: true)
        XCTAssertEqual(outcome, .missedGoal)
    }

    func testScheduledDayOutcomeMetGoalWhenAllCompleted() {
        let occurrences = [
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .completed),
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 18), status: .completed),
        ]
        let outcome = StreakCalculator.dayOutcome(occurrencesOnDay: occurrences, hasSchedule: true, isPastDay: true)
        XCTAssertEqual(outcome, .metGoal)
    }

    func testNotScheduledDaysAreSkippedWithoutBreakingTheStreak() {
        // Mon/Wed/Fri activity, completed every occurrence -- the intervening
        // Tue/Thu (zero occurrences) must not break the streak.
        let occurrences = [
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 2, 9), status: .completed), // Mon
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .completed), // Wed
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 6, 9), status: .completed), // Fri
        ]
        let now = date(2025, 6, 6, 20, 0)

        let streak = StreakCalculator.currentStreak(occurrences: occurrences, hasSchedule: true, today: now, now: now, calendar: calendar)

        XCTAssertEqual(streak, 3)
    }

    func testReminderPastDayWithLeftoverPendingCountsAsAMiss() {
        // Caller applies effectiveStatus before passing occurrences in, so a
        // past-day reminder that was never completed already reads as .missed
        // here -- this test documents that StreakCalculator breaks the streak
        // on it like any other missed day.
        let occurrences = [
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 3, 9), status: .completed),
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .missed), // effectiveStatus already applied
        ]
        let now = date(2025, 6, 5, 8, 0)

        let streak = StreakCalculator.currentStreak(occurrences: occurrences, hasSchedule: true, today: now, now: now, calendar: calendar)

        XCTAssertEqual(streak, 0)
    }

    func testStreakResetsTheDayAfterAMissedDay() {
        let occurrences = [
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 3, 9), status: .missed),
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .completed),
        ]
        let now = date(2025, 6, 4, 20, 0)

        let streak = StreakCalculator.currentStreak(occurrences: occurrences, hasSchedule: true, today: now, now: now, calendar: calendar)

        XCTAssertEqual(streak, 1)
    }

    func testTodayOnlyCountsOnceFullyCompleted() {
        let now = date(2025, 6, 4, 10, 0)
        let occurrences = [
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 9), status: .completed),
            StreakCalculator.StreakOccurrence(scheduledDate: date(2025, 6, 4, 18), status: .pending),
        ]

        let streak = StreakCalculator.currentStreak(occurrences: occurrences, hasSchedule: true, today: now, now: now, calendar: calendar)

        // Today isn't fully resolved yet (one pending occurrence remains) --
        // undecided, so it doesn't count and doesn't break anything either.
        XCTAssertEqual(streak, 0)
    }
}
