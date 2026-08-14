import XCTest
@testable import MotionLoop

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

    private func windowSchedule(
        scheduleID: UUID = UUID(),
        activityIDs: [UUID],
        times: [ScheduleTimeSnapshot]
    ) -> ScheduleSnapshot {
        ScheduleSnapshot(scheduleID: scheduleID, type: .window, windowDurationMinutes: 60, activityIDs: activityIDs, times: times)
    }

    private func time(scheduleID: UUID, weekday: Int, hour: Int, minute: Int = 0) -> ScheduleTimeSnapshot {
        ScheduleTimeSnapshot(scheduleTimeID: UUID(), scheduleID: scheduleID, weekday: weekday, hour: hour, minute: minute)
    }

    func testGeneratesOneOccurrencePerWeekWithinHorizon() {
        let reference = date(2025, 6, 1, 0, 0) // Sunday
        let scheduleID = UUID()
        let activityID = UUID()
        let scheduleTime = time(scheduleID: scheduleID, weekday: 2, hour: 7) // Mondays
        let schedule = windowSchedule(scheduleID: scheduleID, activityIDs: [activityID], times: [scheduleTime])

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [schedule], existingKeys: [], existingSessionIDs: [:], referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        // Two Mondays fall within a 14-day horizon starting the preceding Sunday.
        XCTAssertEqual(planned.count, 2)
        XCTAssertTrue(planned.allSatisfy { $0.ruleWeekday == 2 && $0.ruleHour == 7 && $0.ruleMinute == 0 })
        XCTAssertTrue(planned.allSatisfy { $0.windowEnd != nil })
    }

    func testSkipsSlotsThatAlreadyExist() {
        let reference = date(2025, 6, 1, 0, 0)
        let scheduleID = UUID()
        let activityID = UUID()
        let scheduleTime = time(scheduleID: scheduleID, weekday: 2, hour: 7)
        let schedule = windowSchedule(scheduleID: scheduleID, activityIDs: [activityID], times: [scheduleTime])

        let firstPass = OccurrenceGenerator.generateOccurrences(
            for: [schedule], existingKeys: [], existingSessionIDs: [:], referenceDate: reference, horizonDays: 14, calendar: calendar
        )
        let existingKeys = Set(firstPass.map {
            OccurrenceKey(scheduleTimeID: $0.scheduleTimeID, day: calendar.startOfDay(for: $0.scheduledDate), activityID: $0.activityID)
        })

        let secondPass = OccurrenceGenerator.generateOccurrences(
            for: [schedule], existingKeys: existingKeys, existingSessionIDs: [:], referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        XCTAssertTrue(secondPass.isEmpty)
    }

    func testNeverGeneratesASlotAtOrBeforeReferenceDate() {
        // Creating an "every day at 7am" activity at 3pm must not generate
        // today's 7am slot -- that moment passed before the activity existed,
        // and it must never show up as an immediate "missed" occurrence.
        let now = date(2025, 6, 4, 15, 0) // Wednesday 3pm
        let scheduleID = UUID()
        let activityID = UUID()
        let scheduleTime = time(scheduleID: scheduleID, weekday: 4, hour: 7)
        let schedule = windowSchedule(scheduleID: scheduleID, activityIDs: [activityID], times: [scheduleTime])

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [schedule], existingKeys: [], existingSessionIDs: [:], referenceDate: now, horizonDays: 14, calendar: calendar
        )

        XCTAssertTrue(planned.allSatisfy { $0.scheduledDate > now })
        XCTAssertFalse(planned.contains { calendar.isDate($0.scheduledDate, inSameDayAs: now) })
    }

    func testStillGeneratesTodayWhenRuleTimeHasNotYetPassed() {
        let now = date(2025, 6, 4, 15, 0) // Wednesday 3pm
        let scheduleID = UUID()
        let activityID = UUID()
        let scheduleTime = time(scheduleID: scheduleID, weekday: 4, hour: 18)
        let schedule = windowSchedule(scheduleID: scheduleID, activityIDs: [activityID], times: [scheduleTime])

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [schedule], existingKeys: [], existingSessionIDs: [:], referenceDate: now, horizonDays: 14, calendar: calendar
        )

        XCTAssertTrue(planned.contains { calendar.isDate($0.scheduledDate, inSameDayAs: now) })
    }

    func testMultipleSchedulesGenerateIndependently() {
        let reference = date(2025, 6, 1, 0, 0)
        let mondayScheduleID = UUID()
        let fridayScheduleID = UUID()
        let mondayTime = time(scheduleID: mondayScheduleID, weekday: 2, hour: 7)
        let fridayTime = time(scheduleID: fridayScheduleID, weekday: 6, hour: 18)
        let mondaySchedule = windowSchedule(scheduleID: mondayScheduleID, activityIDs: [UUID()], times: [mondayTime])
        let fridaySchedule = windowSchedule(scheduleID: fridayScheduleID, activityIDs: [UUID()], times: [fridayTime])

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [mondaySchedule, fridaySchedule], existingKeys: [], existingSessionIDs: [:], referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        XCTAssertEqual(planned.filter { $0.scheduleTimeID == mondayTime.scheduleTimeID }.count, 2)
        XCTAssertEqual(planned.filter { $0.scheduleTimeID == fridayTime.scheduleTimeID }.count, 2)
    }

    func testActivitiesSharingAScheduleShareASessionIDPerSlot() {
        let reference = date(2025, 6, 1, 0, 0)
        let scheduleID = UUID()
        let activityA = UUID()
        let activityB = UUID()
        let scheduleTime = time(scheduleID: scheduleID, weekday: 2, hour: 7)
        let schedule = windowSchedule(scheduleID: scheduleID, activityIDs: [activityA, activityB], times: [scheduleTime])

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [schedule], existingKeys: [], existingSessionIDs: [:], referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        let firstMonday = calendar.startOfDay(for: planned.map(\.scheduledDate).sorted()[0])
        let sameSlot = planned.filter { calendar.startOfDay(for: $0.scheduledDate) == firstMonday }
        XCTAssertEqual(sameSlot.count, 2)
        XCTAssertEqual(Set(sameSlot.map(\.sessionID)).count, 1)
    }

    func testActivityNewlyAttachedToAnExistingScheduleJoinsTheExistingSessionID() {
        let reference = date(2025, 6, 1, 0, 0)
        let scheduleID = UUID()
        let existingActivity = UUID()
        let newActivity = UUID()
        let scheduleTime = time(scheduleID: scheduleID, weekday: 2, hour: 7)
        let existingSessionID = UUID()

        let scheduleWithBoth = windowSchedule(scheduleID: scheduleID, activityIDs: [existingActivity, newActivity], times: [scheduleTime])
        let day = calendar.startOfDay(for: date(2025, 6, 2, 0, 0)) // first Monday on/after reference
        let existingKeys: Set<OccurrenceKey> = [
            OccurrenceKey(scheduleTimeID: scheduleTime.scheduleTimeID, day: day, activityID: existingActivity)
        ]
        let existingSessionIDs: [SlotKey: UUID] = [
            SlotKey(scheduleTimeID: scheduleTime.scheduleTimeID, day: day): existingSessionID
        ]

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [scheduleWithBoth], existingKeys: existingKeys, existingSessionIDs: existingSessionIDs,
            referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        let firstSlotForNewActivity = planned.first {
            $0.activityID == newActivity && calendar.startOfDay(for: $0.scheduledDate) == day
        }
        XCTAssertEqual(firstSlotForNewActivity?.sessionID, existingSessionID)
        XCTAssertFalse(planned.contains { $0.activityID == existingActivity && calendar.startOfDay(for: $0.scheduledDate) == day })
    }

    func testReminderTypeProducesNilWindowEnd() {
        let reference = date(2025, 6, 1, 0, 0)
        let scheduleID = UUID()
        let scheduleTime = time(scheduleID: scheduleID, weekday: 2, hour: 7)
        let schedule = ScheduleSnapshot(
            scheduleID: scheduleID, type: .reminder, windowDurationMinutes: nil, activityIDs: [UUID()], times: [scheduleTime]
        )

        let planned = OccurrenceGenerator.generateOccurrences(
            for: [schedule], existingKeys: [], existingSessionIDs: [:], referenceDate: reference, horizonDays: 14, calendar: calendar
        )

        XCTAssertFalse(planned.isEmpty)
        XCTAssertTrue(planned.allSatisfy { $0.windowEnd == nil })
    }
}
