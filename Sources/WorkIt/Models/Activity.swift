import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbolName: String
    var createdAt: Date
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \ScheduleRule.activity)
    var scheduleRules: [ScheduleRule] = []

    @Relationship(deleteRule: .cascade, inverse: \ExerciseOccurrence.activity)
    var occurrences: [ExerciseOccurrence] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}
