import XCTest
@testable import MotionLoop

final class OccurrenceDisplayTests: XCTestCase {
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

    func testTodaysPendingReminderDisplaysAsPending() {
        let now = date(2025, 6, 4, 15, 0)
        let scheduled = date(2025, 6, 4, 9, 0)

        let effective = OccurrenceDisplay.effectiveStatus(
            status: .pending, scheduledDate: scheduled, windowEnd: nil, now: now, calendar: calendar
        )

        XCTAssertEqual(effective, .pending)
    }

    func testYesterdaysPendingReminderDisplaysAsMissed() {
        let now = date(2025, 6, 4, 15, 0)
        let scheduled = date(2025, 6, 3, 9, 0)

        let effective = OccurrenceDisplay.effectiveStatus(
            status: .pending, scheduledDate: scheduled, windowEnd: nil, now: now, calendar: calendar
        )

        XCTAssertEqual(effective, .missed)
    }

    func testWindowTypePassesThroughUnaffected() {
        let now = date(2025, 6, 3, 15, 0)
        let scheduled = date(2025, 6, 3, 9, 0)
        let windowEnd = date(2025, 6, 3, 10, 0)

        let effective = OccurrenceDisplay.effectiveStatus(
            status: .pending, scheduledDate: scheduled, windowEnd: windowEnd, now: now, calendar: calendar
        )

        // Window-type is handled by OccurrenceReconciler flipping the real
        // status; effectiveStatus only reinterprets no-window occurrences, so
        // a still-.pending window occurrence passes through unchanged here.
        XCTAssertEqual(effective, .pending)
    }

    func testCompletedAndMissedStatusesAlwaysPassThrough() {
        let now = date(2025, 6, 10, 0, 0)
        let scheduled = date(2025, 6, 1, 9, 0)

        XCTAssertEqual(
            OccurrenceDisplay.effectiveStatus(status: .completed, scheduledDate: scheduled, windowEnd: nil, now: now, calendar: calendar),
            .completed
        )
        XCTAssertEqual(
            OccurrenceDisplay.effectiveStatus(status: .missed, scheduledDate: scheduled, windowEnd: nil, now: now, calendar: calendar),
            .missed
        )
    }
}
