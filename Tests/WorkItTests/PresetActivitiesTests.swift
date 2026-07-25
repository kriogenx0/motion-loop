import XCTest
@testable import WorkIt

final class PresetActivitiesTests: XCTestCase {
    func testPresetsLoadFromBundledJSON() {
        XCTAssertFalse(PresetActivities.all.isEmpty, "PresetActivities.json should be bundled and decode successfully")
    }

    func testFeaturedIsNonEmptySubsetOfAll() {
        XCTAssertFalse(PresetActivities.featured.isEmpty)
        let allNames = Set(PresetActivities.all.map(\.name))
        XCTAssertTrue(PresetActivities.featured.allSatisfy { allNames.contains($0.name) })
    }

    func testEveryPresetHasEitherDurationOrSetsAndReps() {
        for preset in PresetActivities.all {
            let hasDuration = preset.defaultDurationMinutes != nil
            let hasSetsReps = preset.defaultSets != nil && preset.defaultReps != nil
            XCTAssertTrue(hasDuration || hasSetsReps, "\(preset.name) has no default target")
        }
    }
}
