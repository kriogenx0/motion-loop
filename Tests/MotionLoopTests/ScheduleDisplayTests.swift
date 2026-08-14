import XCTest
@testable import MotionLoop

final class ScheduleDisplayTests: XCTestCase {
    func testAllSevenWeekdaysGroupAsEveryDay() {
        let entries = (1...7).map { (weekday: $0, hour: 7, minute: 0) }

        let groups = ScheduleDisplay.groups(from: entries)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].weekdays.count, 7)
        XCTAssertTrue(groups[0].displayText.hasPrefix("Every day"))
    }

    func testDifferentTimesOnSameDayProduceSeparateGroups() {
        // "3x a day, every day" -> one group per time, each spanning all 7 weekdays.
        let entries = (1...7).flatMap { weekday in
            [(weekday: weekday, hour: 7, minute: 0), (weekday: weekday, hour: 13, minute: 0), (weekday: weekday, hour: 18, minute: 0)]
        }

        let groups = ScheduleDisplay.groups(from: entries)

        XCTAssertEqual(groups.count, 3)
        XCTAssertTrue(groups.allSatisfy { $0.weekdays.count == 7 })
        // Sorted by time of day.
        XCTAssertEqual(groups.map(\.hour), [7, 13, 18])
    }

    func testSpecificWeekdaysDoNotClaimToBeEveryDay() {
        let entries: [(weekday: Int, hour: Int, minute: Int)] = [
            (weekday: 2, hour: 7, minute: 0), // Monday
            (weekday: 4, hour: 7, minute: 0), // Wednesday
            (weekday: 6, hour: 7, minute: 0), // Friday
        ]

        let groups = ScheduleDisplay.groups(from: entries)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].weekdays, [2, 4, 6])
        XCTAssertFalse(groups[0].displayText.hasPrefix("Every day"))
    }

    func testEntriesFromDifferentActionsAtSameTimeMergeIntoOneGroup() {
        // Simulates adding "Mon at 7am" in one pass and "Wed at 7am" in another --
        // they should merge into a single displayed group for that time.
        let firstPass: [(weekday: Int, hour: Int, minute: Int)] = [(weekday: 2, hour: 7, minute: 0)]
        let secondPass: [(weekday: Int, hour: Int, minute: Int)] = [(weekday: 4, hour: 7, minute: 0)]

        let groups = ScheduleDisplay.groups(from: firstPass + secondPass)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].weekdays, [2, 4])
    }

    func testSessionTitleForOneActivity() {
        XCTAssertEqual(ScheduleDisplay.sessionTitle(activityNames: ["Push-ups"]), "Push-ups")
    }

    func testSessionTitleForTwoActivities() {
        XCTAssertEqual(ScheduleDisplay.sessionTitle(activityNames: ["Push-ups", "Crunches"]), "Push-ups & Crunches")
    }

    func testSessionTitleForThreeOrMoreActivities() {
        XCTAssertEqual(
            ScheduleDisplay.sessionTitle(activityNames: ["Push-ups", "Crunches", "Squats", "Lunges"]),
            "Push-ups, Crunches & 2 more"
        )
    }
}
