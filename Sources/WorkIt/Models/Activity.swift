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
    var targetDurationSeconds: Int?
    var targetSets: Int?
    var targetReps: Int?

    @Relationship(deleteRule: .cascade, inverse: \ScheduleRule.activity)
    var scheduleRules: [ScheduleRule] = []

    /// `.nullify`, not `.cascade`: deleting an Activity must not erase its
    /// resolved (completed/missed) history. Callers that actually delete an
    /// Activity are responsible for first deleting its still-`.pending`
    /// occurrences (see AddEditActivityView.deleteActivity) -- the resolved
    /// ones survive with `activity == nil`, reading from their own snapshot
    /// fields (ExerciseOccurrence.activityName etc.) from then on.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseOccurrence.activity)
    var occurrences: [ExerciseOccurrence] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        createdAt: Date = .now,
        isArchived: Bool = false,
        targetType: ActivityTargetType = .none,
        targetDurationSeconds: Int? = nil,
        targetSets: Int? = nil,
        targetReps: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.targetTypeRaw = targetType.rawValue
        self.targetDurationSeconds = targetDurationSeconds
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
            durationSeconds: targetDurationSeconds,
            sets: targetSets,
            reps: targetReps
        )
    }
}
