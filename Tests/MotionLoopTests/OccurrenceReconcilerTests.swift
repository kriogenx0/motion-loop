import XCTest
@testable import MotionLoop

final class OccurrenceReconcilerTests: XCTestCase {
    func testPendingOccurrencePastWindowEndFlipsToMissed() {
        let now = Date()
        let occurrence = OccurrenceSnapshot(id: UUID(), windowEnd: now.addingTimeInterval(-60), status: .pending)

        let changes = OccurrenceReconciler.reconcile(occurrences: [occurrence], now: now)

        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].id, occurrence.id)
        XCTAssertEqual(changes[0].newStatus, .missed)
    }

    func testPendingOccurrenceStillWithinWindowIsUnchanged() {
        let now = Date()
        let occurrence = OccurrenceSnapshot(id: UUID(), windowEnd: now.addingTimeInterval(60), status: .pending)

        let changes = OccurrenceReconciler.reconcile(occurrences: [occurrence], now: now)

        XCTAssertTrue(changes.isEmpty)
    }

    func testPendingOccurrenceExactlyAtWindowEndFlipsToMissed() {
        let now = Date()
        let occurrence = OccurrenceSnapshot(id: UUID(), windowEnd: now, status: .pending)

        let changes = OccurrenceReconciler.reconcile(occurrences: [occurrence], now: now)

        XCTAssertEqual(changes.count, 1)
    }

    func testCompletedAndMissedOccurrencesAreNeverTouched() {
        let now = Date()
        let completed = OccurrenceSnapshot(id: UUID(), windowEnd: now.addingTimeInterval(-3600), status: .completed)
        let alreadyMissed = OccurrenceSnapshot(id: UUID(), windowEnd: now.addingTimeInterval(-3600), status: .missed)

        let changes = OccurrenceReconciler.reconcile(occurrences: [completed, alreadyMissed], now: now)

        XCTAssertTrue(changes.isEmpty)
    }

    func testPendingOccurrenceWithNoWindowIsNeverFlippedRegardlessOfAge() {
        // Reminder-type occurrences have no deadline at all -- not even a very
        // old, never-answered one should ever become "missed".
        let now = Date()
        let veryOld = OccurrenceSnapshot(id: UUID(), windowEnd: nil, status: .pending)

        let changes = OccurrenceReconciler.reconcile(occurrences: [veryOld], now: now)

        XCTAssertTrue(changes.isEmpty)
    }
}
