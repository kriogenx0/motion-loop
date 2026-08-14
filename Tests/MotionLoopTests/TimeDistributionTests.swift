import XCTest
@testable import MotionLoop

final class TimeDistributionTests: XCTestCase {
    func testThreeTimesEightAmToEightPmOneHourGap() {
        let result = TimeDistribution.evenlySpaced(
            count: 3, rangeStart: (hour: 8, minute: 0), rangeEnd: (hour: 20, minute: 0), minimumGapMinutes: 60
        )

        XCTAssertNotNil(result)
        guard let result else { return }
        XCTAssertEqual(result.map(\.hour), [8, 14, 20])
        XCTAssertTrue(result.allSatisfy { $0.minute == 0 })
    }

    func testCountOfOneReturnsRangeStart() {
        let result = TimeDistribution.evenlySpaced(
            count: 1, rangeStart: (hour: 9, minute: 0), rangeEnd: (hour: 20, minute: 0), minimumGapMinutes: 60
        )

        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?[0].hour, 9)
    }

    func testCountOfTwoReturnsBothEndpoints() {
        let result = TimeDistribution.evenlySpaced(
            count: 2, rangeStart: (hour: 8, minute: 0), rangeEnd: (hour: 20, minute: 0), minimumGapMinutes: 60
        )

        XCTAssertEqual(result?.map(\.hour), [8, 20])
    }

    func testUnsatisfiableConstraintsReturnNil() {
        // 5 times with a 4hr minimum gap can't fit in a 12hr window.
        let result = TimeDistribution.evenlySpaced(
            count: 5, rangeStart: (hour: 8, minute: 0), rangeEnd: (hour: 20, minute: 0), minimumGapMinutes: 240
        )

        XCTAssertNil(result)
    }

    func testInvertedRangeReturnsNil() {
        let result = TimeDistribution.evenlySpaced(
            count: 2, rangeStart: (hour: 20, minute: 0), rangeEnd: (hour: 8, minute: 0), minimumGapMinutes: 60
        )

        XCTAssertNil(result)
    }
}
