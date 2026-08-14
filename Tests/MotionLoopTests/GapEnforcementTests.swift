import XCTest
@testable import MotionLoop

final class GapEnforcementTests: XCTestCase {
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

    func testAllowedWhenNoPriorCompletion() {
        let now = date(2025, 6, 4, 9, 0)
        XCTAssertTrue(GapEnforcer.isCompletionAllowed(lastNonBonusCompletionAt: nil, minimumGapMinutes: 60, now: now, calendar: calendar))
        XCTAssertNil(GapEnforcer.nextAllowedCompletionDate(lastNonBonusCompletionAt: nil, minimumGapMinutes: 60, now: now, calendar: calendar))
    }

    func testBlockedWithinTheGapWindow() {
        let last = date(2025, 6, 4, 9, 0)
        let now = date(2025, 6, 4, 9, 30) // only 30 min later, gap is 60
        XCTAssertFalse(GapEnforcer.isCompletionAllowed(lastNonBonusCompletionAt: last, minimumGapMinutes: 60, now: now, calendar: calendar))
    }

    func testAllowedExactlyAtTheGapBoundary() {
        let last = date(2025, 6, 4, 9, 0)
        let now = date(2025, 6, 4, 10, 0) // exactly 60 min later
        XCTAssertTrue(GapEnforcer.isCompletionAllowed(lastNonBonusCompletionAt: last, minimumGapMinutes: 60, now: now, calendar: calendar))
    }

    func testAllowedAfterTheGapBoundary() {
        let last = date(2025, 6, 4, 9, 0)
        let now = date(2025, 6, 4, 10, 1)
        XCTAssertTrue(GapEnforcer.isCompletionAllowed(lastNonBonusCompletionAt: last, minimumGapMinutes: 60, now: now, calendar: calendar))
    }

    func testViolatesMinimumGapFlagsSameWeekdayClosePairs() {
        let entries = [
            GapEnforcer.TimeEntry(weekday: 2, hour: 9, minute: 0),
            GapEnforcer.TimeEntry(weekday: 2, hour: 9, minute: 30),
        ]
        XCTAssertTrue(GapEnforcer.violatesMinimumGap(entries, minimumGapMinutes: 60))
    }

    func testViolatesMinimumGapIgnoresDifferentWeekdayPairs() {
        let entries = [
            GapEnforcer.TimeEntry(weekday: 2, hour: 23, minute: 45),
            GapEnforcer.TimeEntry(weekday: 3, hour: 0, minute: 15),
        ]
        // Different weekdays -- this pairwise check deliberately doesn't
        // handle midnight wraparound (see doc comment); the runtime gap check
        // is the real backstop for that case.
        XCTAssertFalse(GapEnforcer.violatesMinimumGap(entries, minimumGapMinutes: 60))
    }

    func testViolatesMinimumGapIgnoresASingleTime() {
        let entries = [GapEnforcer.TimeEntry(weekday: 2, hour: 9, minute: 0)]
        XCTAssertFalse(GapEnforcer.violatesMinimumGap(entries, minimumGapMinutes: 60))
    }

    func testViolatesMinimumGapAllowsPairsFarEnoughApart() {
        let entries = [
            GapEnforcer.TimeEntry(weekday: 2, hour: 8, minute: 0),
            GapEnforcer.TimeEntry(weekday: 2, hour: 14, minute: 0),
            GapEnforcer.TimeEntry(weekday: 2, hour: 20, minute: 0),
        ]
        XCTAssertFalse(GapEnforcer.violatesMinimumGap(entries, minimumGapMinutes: 60))
    }
}
