import XCTest
@testable import MotionLoop

final class StreakDisplayTests: XCTestCase {
    func testTierBoundaries() {
        XCTAssertEqual(StreakDisplay.tier(for: 0), .none)
        XCTAssertEqual(StreakDisplay.tier(for: 2), .none)
        XCTAssertEqual(StreakDisplay.tier(for: 3), .warm)
        XCTAssertEqual(StreakDisplay.tier(for: 6), .warm)
        XCTAssertEqual(StreakDisplay.tier(for: 7), .hot)
        XCTAssertEqual(StreakDisplay.tier(for: 13), .hot)
        XCTAssertEqual(StreakDisplay.tier(for: 14), .blazing)
        XCTAssertEqual(StreakDisplay.tier(for: 29), .blazing)
        XCTAssertEqual(StreakDisplay.tier(for: 30), .inferno)
        XCTAssertEqual(StreakDisplay.tier(for: 100), .inferno)
    }

    func testFlameCountsPerTier() {
        XCTAssertEqual(StreakDisplay.flameCount(for: .none), 0)
        XCTAssertEqual(StreakDisplay.flameCount(for: .warm), 1)
        XCTAssertEqual(StreakDisplay.flameCount(for: .hot), 1)
        XCTAssertEqual(StreakDisplay.flameCount(for: .blazing), 2)
        XCTAssertEqual(StreakDisplay.flameCount(for: .inferno), 3)
    }

    func testLabelPluralization() {
        XCTAssertEqual(StreakDisplay.label(for: 1), "1 day streak")
        XCTAssertEqual(StreakDisplay.label(for: 7), "7 day streak")
    }
}
