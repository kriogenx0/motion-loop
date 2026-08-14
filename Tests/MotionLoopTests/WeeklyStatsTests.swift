import XCTest
@testable import MotionLoop

final class WeeklyStatsTests: XCTestCase {
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

    func testDaySummariesBucketByCalendarDayAndStatus() {
        let interval = DateInterval(start: date(2025, 6, 2), end: date(2025, 6, 9))
        let now = date(2025, 6, 10) // after everything, so no "upcoming" ambiguity
        let occurrences = [
            SummarizableOccurrence(scheduledDate: date(2025, 6, 2, 7), windowEnd: date(2025, 6, 2, 8), status: .completed),
            SummarizableOccurrence(scheduledDate: date(2025, 6, 4, 7), windowEnd: date(2025, 6, 4, 8), status: .missed),
        ]

        let summaries = WeeklyStats.daySummaries(for: occurrences, in: interval, now: now, calendar: calendar)

        XCTAssertEqual(summaries.count, 7)
        let mondaySummary = summaries.first { calendar.isDate($0.day, inSameDayAs: date(2025, 6, 2)) }
        XCTAssertEqual(mondaySummary?.completed, 1)
        let wednesdaySummary = summaries.first { calendar.isDate($0.day, inSameDayAs: date(2025, 6, 4)) }
        XCTAssertEqual(wednesdaySummary?.missed, 1)
        let emptyDaySummary = summaries.first { calendar.isDate($0.day, inSameDayAs: date(2025, 6, 3)) }
        XCTAssertEqual(emptyDaySummary?.completed, 0)
        XCTAssertEqual(emptyDaySummary?.missed, 0)
    }

    func testPastDayReminderOccurrenceWithNoWindowBucketsAsMissed() {
        let interval = DateInterval(start: date(2025, 6, 2), end: date(2025, 6, 9))
        let now = date(2025, 6, 10)
        let occurrences = [
            SummarizableOccurrence(scheduledDate: date(2025, 6, 2, 9), windowEnd: nil, status: .pending),
        ]

        let summaries = WeeklyStats.daySummaries(for: occurrences, in: interval, now: now, calendar: calendar)

        let mondaySummary = summaries.first { calendar.isDate($0.day, inSameDayAs: date(2025, 6, 2)) }
        XCTAssertEqual(mondaySummary?.missed, 1)
        XCTAssertEqual(mondaySummary?.pending, 0)
    }

    func testTodayReminderOccurrenceWithNoWindowStaysPending() {
        let interval = DateInterval(start: date(2025, 6, 2), end: date(2025, 6, 9))
        let now = date(2025, 6, 4, 12, 0)
        let occurrences = [
            SummarizableOccurrence(scheduledDate: date(2025, 6, 4, 9), windowEnd: nil, status: .pending),
        ]

        let summaries = WeeklyStats.daySummaries(for: occurrences, in: interval, now: now, calendar: calendar)

        let wednesdaySummary = summaries.first { calendar.isDate($0.day, inSameDayAs: date(2025, 6, 4)) }
        XCTAssertEqual(wednesdaySummary?.pending, 1)
        XCTAssertEqual(wednesdaySummary?.missed, 0)
    }
}
