import XCTest
@testable import MotionLoop

final class SessionGroupingTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testOccurrencesWithTheSameSessionIDGroupTogether() {
        let sessionID = UUID()
        let a = SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: nil, status: .pending)
        let b = SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: nil, status: .pending)

        let groups = SessionGrouping.groupIntoSessions([a, b])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 2)
    }

    func testOccurrencesWithNoSessionIDGroupAsSingletons() {
        let a = SessionOccurrenceSnapshot(id: UUID(), sessionID: nil, scheduledDate: date(2025, 6, 4, 9), windowEnd: nil, status: .completed)
        let b = SessionOccurrenceSnapshot(id: UUID(), sessionID: nil, scheduledDate: date(2025, 6, 4, 9), windowEnd: nil, status: .completed)

        let groups = SessionGrouping.groupIntoSessions([a, b])

        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.allSatisfy { $0.count == 1 })
    }

    func testBucketAllCompletedIsCompleted() {
        let sessionID = UUID()
        let now = date(2025, 6, 4, 12, 0)
        let session = [
            SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: date(2025, 6, 4, 10), status: .completed),
            SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: date(2025, 6, 4, 10), status: .completed),
        ]

        XCTAssertEqual(SessionGrouping.bucket(for: session, now: now), .completed)
    }

    func testBucketAnyMissedAmongResolvedSessionIsMissed() {
        // Fully resolved (nothing pending), but only partially completed --
        // a partial session reads as missed overall, not completed.
        let sessionID = UUID()
        let now = date(2025, 6, 4, 12, 0)
        let session = [
            SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: date(2025, 6, 4, 10), status: .completed),
            SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: date(2025, 6, 4, 10), status: .missed),
        ]

        XCTAssertEqual(SessionGrouping.bucket(for: session, now: now), .missed)
    }

    func testBucketOpenWindowIsActiveNow() {
        let sessionID = UUID()
        let now = date(2025, 6, 4, 9, 30)
        let session = [
            SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: date(2025, 6, 4, 10), status: .pending),
        ]

        XCTAssertEqual(SessionGrouping.bucket(for: session, now: now), .activeNow)
    }

    func testBucketFutureSlotIsUpcoming() {
        let sessionID = UUID()
        let now = date(2025, 6, 4, 7, 0)
        let session = [
            SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: date(2025, 6, 4, 10), status: .pending),
        ]

        XCTAssertEqual(SessionGrouping.bucket(for: session, now: now), .upcoming)
    }

    func testBucketReminderTypeWithNoWindowIsActiveNowOnceTimeArrives() {
        let sessionID = UUID()
        let now = date(2025, 6, 4, 9, 5)
        let session = [
            SessionOccurrenceSnapshot(id: UUID(), sessionID: sessionID, scheduledDate: date(2025, 6, 4, 9), windowEnd: nil, status: .pending),
        ]

        XCTAssertEqual(SessionGrouping.bucket(for: session, now: now), .activeNow)
    }
}
