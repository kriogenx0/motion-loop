import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbolName: String
    var createdAt: Date
    var isArchived: Bool

    /// Backing storage for `targetType` -- stored as a raw String for the same
    /// reason ExerciseOccurrence.statusRaw is: SwiftData #Predicate filtering on
    /// custom enums is unreliable.
    var targetTypeRaw: String
    var targetDurationMinutes: Int?
    var targetSets: Int?
    var targetReps: Int?

    @Relationship(deleteRule: .cascade, inverse: \ScheduleRule.activity)
    var scheduleRules: [ScheduleRule] = []

    @Relationship(deleteRule: .cascade, inverse: \ExerciseOccurrence.activity)
    var occurrences: [ExerciseOccurrence] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        createdAt: Date = .now,
        isArchived: Bool = false,
        targetType: ActivityTargetType = .none,
        targetDurationMinutes: Int? = nil,
        targetSets: Int? = nil,
        targetReps: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.targetTypeRaw = targetType.rawValue
        self.targetDurationMinutes = targetDurationMinutes
        self.targetSets = targetSets
        self.targetReps = targetReps
    }

    var targetType: ActivityTargetType {
        get { ActivityTargetType(rawValue: targetTypeRaw) ?? .none }
        set { targetTypeRaw = newValue.rawValue }
    }

    var targetDescription: String? {
        ActivityTargetFormatter.describe(
            type: targetType,
            durationMinutes: targetDurationMinutes,
            sets: targetSets,
            reps: targetReps
        )
    }
}
