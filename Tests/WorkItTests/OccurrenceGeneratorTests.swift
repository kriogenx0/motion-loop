import XCTest
@testable import WorkIt

final class OccurrenceGeneratorTests: XCTestCase {
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

    func testGeneratesOneOccurrencePerWeekWithinHorizon() {
        let reference = date(2025, 6, 1, 0, 0) // Sunday
        let rule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 2, hour: 7, minute: 0, windowDurationMinutes: 60) // Mondays

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [rule], existingKeys: [], referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        // Two Mondays fall within a 14-day horizon starting the preceding Sunday.
        XCTAssertEqual(planned.count, 2)
        XCTAssertTrue(planned.allSatisfy { $0.ruleWeekday == 2 && $0.ruleHour == 7 && $0.ruleMinute == 0 })
    }

    func testSkipsSlotsThatAlreadyExist() {
        let reference = date(2025, 6, 1, 0, 0)
        let rule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 2, hour: 7, minute: 0, windowDurationMinutes: 60)

        let firstPass = OccurrenceGenerator.generateOccurrences(
            for: [rule], existingKeys: [], referenceDate: reference, horizonDays: 14, calendar: calendar
        )
        let existingKeys = Set(firstPass.map {
            OccurrenceKey(ruleID: $0.ruleID, day: calendar.startOfDay(for: $0.scheduledDate))
        })

        let secondPass = OccurrenceGenerator.generateOccurrences(
            for: [rule], existingKeys: existingKeys, referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        XCTAssertTrue(secondPass.isEmpty)
    }

    func testMultipleRulesGenerateIndependently() {
        let reference = date(2025, 6, 1, 0, 0)
        let mondayRule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 2, hour: 7, minute: 0, windowDurationMinutes: 60)
        let fridayRule = ScheduleRuleSnapshot(ruleID: UUID(), activityID: UUID(), weekday: 6, hour: 18, minute: 0, windowDurationMinutes: 60)

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [mondayRule, fridayRule], existingKeys: [], referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        XCTAssertEqual(planned.filter { $0.ruleID == mondayRule.ruleID }.count, 2)
        XCTAssertEqual(planned.filter { $0.ruleID == fridayRule.ruleID }.count, 2)
    }
}
