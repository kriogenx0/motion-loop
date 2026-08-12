import XCTest
@testable import MotionLoop

final class ScheduleMathTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    func testNextOccurrenceDateMatchesWeekdayAndTime() {
        // Wednesday June 4, 2025 -- look for the next Monday (weekday = 2) at 7:00am.
        let after = date(2025, 6, 4, 12, 0)
        let rule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 2, hour: 7, minute: 0, windowDurationMinutes: 60)

        let results = ScheduleMath.nextOccurrenceDates(for: rule, after: after, count: 1, calendar: calendar)

        XCTAssertEqual(results.count, 1)
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: results[0])
        XCTAssertEqual(components.weekday, 2)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 0)
        XCTAssertGreaterThan(results[0], after)
    }

    func testNextOccurrenceDatesReturnsWeeklyRecurrences() {
        let after = date(2025, 6, 1, 0, 0)
        let rule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 3, hour: 9, minute: 30, windowDurationMinutes: 60)

        let results = ScheduleMath.nextOccurrenceDates(for: rule, after: after, count: 4, calendar: calendar)

        XCTAssertEqual(results.count, 4)
        for pair in zip(results, results.dropFirst()) {
            let interval = pair.1.timeIntervalSince(pair.0)
            XCTAssertEqual(interval, 7 * 24 * 3600, accuracy: 3600) // one week apart, tolerant of DST shifts
        }
    }

    func testNextOccurrenceDatesAreStrictlyAfterReferenceDate() {
        // If "after" is exactly the scheduled moment, that same instant should not be returned again.
        let exact = date(2025, 6, 2, 7, 0) // a Monday
        let rule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 2, hour: 7, minute: 0, windowDurationMinutes: 60)

        let results = ScheduleMath.nextOccurrenceDates(for: rule, after: exact, count: 1, calendar: calendar)

        XCTAssertEqual(results.count, 1)
        XCTAssertGreaterThan(results[0], exact)
    }

    func testWindowEndIsSixtyMinutesLater() {
        let start = date(2025, 6, 2, 7, 0)
        let end = ScheduleMath.windowEnd(for: start, durationMinutes: 60, calendar: calendar)
        XCTAssertEqual(end.timeIntervalSince(start), 3600)
    }

    func testAddingMinutesWithinSameHour() {
        let result = ScheduleMath.addingMinutes(30, toWeekday: 4, hour: 7, minute: 0, calendar: calendar)
        XCTAssertEqual(result.weekday, 4)
        XCTAssertEqual(result.hour, 7)
        XCTAssertEqual(result.minute, 30)
    }

    func testAddingMinutesRollsOverToNextHour() {
        let result = ScheduleMath.addingMinutes(30, toWeekday: 4, hour: 7, minute: 45, calendar: calendar)
        XCTAssertEqual(result.weekday, 4)
        XCTAssertEqual(result.hour, 8)
        XCTAssertEqual(result.minute, 15)
    }

    func testAddingMinutesRollsOverToNextWeekday() {
        // Saturday (weekday 7) 23:45 + 30 min -> Sunday (weekday 1) 00:15
        let result = ScheduleMath.addingMinutes(30, toWeekday: 7, hour: 23, minute: 45, calendar: calendar)
        XCTAssertEqual(result.weekday, 1)
        XCTAssertEqual(result.hour, 0)
        XCTAssertEqual(result.minute, 15)
    }

    func testNextOccurrenceDatesAcrossSpringForwardStaysMonotonicAndOnWeekday() {
        // US spring-forward in 2025 is March 9. Ask for Sundays (weekday=1) at 2:30am,
        // a wall-clock time that doesn't exist on the transition day itself.
        let after = date(2025, 3, 1, 0, 0)
        let rule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 1, hour: 2, minute: 30, windowDurationMinutes: 60)

        let results = ScheduleMath.nextOccurrenceDates(for: rule, after: after, count: 3, calendar: calendar)

        // The nonexistent instant on the transition day may be skipped entirely, so we only
        // assert what must always hold: dates are increasing and each is a Sunday.
        for value in results {
            XCTAssertEqual(calendar.component(.weekday, from: value), 1)
        }
        for pair in zip(results, results.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1)
        }
    }
}
