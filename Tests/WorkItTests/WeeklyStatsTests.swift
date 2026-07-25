import XCTest
@testable import WorkIt

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
        let activityID = UUID()
        let interval = DateInterval(start: date(2025, 6, 2), end: date(2025, 6, 9))
        let now = date(2025, 6, 10) // after everything, so no "upcoming" ambiguity
        let occurrences = [
            SummarizableOccurrence(activityID: activityID, activityName: "Push-ups", scheduledDate: date(2025, 6, 2, 7), windowEnd: date(2025, 6, 2, 8), status: .completed),
            SummarizableOccurrence(activityID: activityID, activityName: "Push-ups", scheduledDate: date(2025, 6, 4, 7), windowEnd: date(2025, 6, 4, 8), status: .missed),
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

    func testActivitySummariesAggregateAcrossDays() {
        let pushUpsID = UUID()
        let squatsID = UUID()
        let occurrences = [
            SummarizableOccurrence(activityID: pushUpsID, activityName: "Push-ups", scheduledDate: date(2025, 6, 2, 7), windowEnd: date(2025, 6, 2, 8), status: .completed),
            SummarizableOccurrence(activityID: pushUpsID, activityName: "Push-ups", scheduledDate: date(2025, 6, 4, 7), windowEnd: date(2025, 6, 4, 8), status: .missed),
            SummarizableOccurrence(activityID: squatsID, activityName: "Squats", scheduledDate: date(2025, 6, 3, 7), windowEnd: date(2025, 6, 3, 8), status: .completed),
        ]

        let summaries = WeeklyStats.activitySummaries(for: occurrences)

        let pushUps = summaries.first { $0.activityID == pushUpsID }
        XCTAssertEqual(pushUps?.completed, 1)
        XCTAssertEqual(pushUps?.missed, 1)
        XCTAssertEqual(pushUps?.total, 2)

        let squats = summaries.first { $0.activityID == squatsID }
        XCTAssertEqual(squats?.completed, 1)
        XCTAssertEqual(squats?.total, 1)
    }
}
