import XCTest
@testable import WorkIt

final class ActivityTargetTests: XCTestCase {
    func testNoneTypeHasNoDescription() {
        let description = ActivityTargetFormatter.describe(type: .none, durationSeconds: 1200, sets: 3, reps: 12)
        XCTAssertNil(description)
    }

    func testDurationDescribesMinutes() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationSeconds: 1200, sets: nil, reps: nil)
        XCTAssertEqual(description, "20 min")
    }

    func testDurationSingularMinute() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationSeconds: 60, sets: nil, reps: nil)
        XCTAssertEqual(description, "1 min")
    }

    func testDurationDescribesSecondsOnly() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationSeconds: 45, sets: nil, reps: nil)
        XCTAssertEqual(description, "45 sec")
    }

    func testDurationDescribesMinutesAndSeconds() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationSeconds: 75, sets: nil, reps: nil)
        XCTAssertEqual(description, "1 min 15 sec")
    }

    func testDurationWithMissingValueHasNoDescription() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationSeconds: nil, sets: nil, reps: nil)
        XCTAssertNil(description)
    }

    func testSetsRepsDescribesBoth() {
        let description = ActivityTargetFormatter.describe(type: .setsReps, durationSeconds: nil, sets: 3, reps: 12)
        XCTAssertEqual(description, "3 \u{00d7} 12")
    }

    func testSetsRepsWithMissingValueHasNoDescription() {
        let description = ActivityTargetFormatter.describe(type: .setsReps, durationSeconds: nil, sets: 3, reps: nil)
        XCTAssertNil(description)
    }
}
