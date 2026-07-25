import XCTest
@testable import WorkIt

final class ActivityTargetTests: XCTestCase {
    func testNoneTypeHasNoDescription() {
        let description = ActivityTargetFormatter.describe(type: .none, durationMinutes: 20, sets: 3, reps: 12)
        XCTAssertNil(description)
    }

    func testDurationDescribesMinutes() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationMinutes: 20, sets: nil, reps: nil)
        XCTAssertEqual(description, "20 min")
    }

    func testDurationSingularMinute() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationMinutes: 1, sets: nil, reps: nil)
        XCTAssertEqual(description, "1 min")
    }

    func testDurationWithMissingValueHasNoDescription() {
        let description = ActivityTargetFormatter.describe(type: .duration, durationMinutes: nil, sets: nil, reps: nil)
        XCTAssertNil(description)
    }

    func testSetsRepsDescribesBoth() {
        let description = ActivityTargetFormatter.describe(type: .setsReps, durationMinutes: nil, sets: 3, reps: 12)
        XCTAssertEqual(description, "3 \u{00d7} 12")
    }

    func testSetsRepsWithMissingValueHasNoDescription() {
        let description = ActivityTargetFormatter.describe(type: .setsReps, durationMinutes: nil, sets: 3, reps: nil)
        XCTAssertNil(description)
    }
}
