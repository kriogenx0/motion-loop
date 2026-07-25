import Foundation
import SwiftData

/// One concrete scheduled instance of an Activity: a specific hour-long window
/// on a specific day, and whether the user completed it.
@Model
final class ExerciseOccurrence {
    @Attribute(.unique) var id: UUID
    var scheduledDate: Date
    var windowEnd: Date
    /// Backing storage for `status`. Stored as a raw String rather than the enum
    /// itself because SwiftData #Predicate filtering on custom enums is unreliable.
    var statusRaw: String
    var respondedAt: Date?
    var createdAt: Date

    /// Plain UUID reference to the ScheduleRule that generated this occurrence --
    /// intentionally NOT a SwiftData relationship, so editing/removing the rule
    /// later never touches already-generated history.
    var sourceRuleID: UUID?
    var ruleWeekday: Int
    var ruleHour: Int
    var ruleMinute: Int

    var activity: Activity?

    init(
        id: UUID = UUID(),
        scheduledDate: Date,
        windowEnd: Date,
        status: OccurrenceStatus = .pending,
        respondedAt: Date? = nil,
        createdAt: Date = .now,
        sourceRuleID: UUID?,
        ruleWeekday: Int,
        ruleHour: Int,
        ruleMinute: Int
    ) {
        self.id = id
        self.scheduledDate = scheduledDate
        self.windowEnd = windowEnd
        self.statusRaw = status.rawValue
        self.respondedAt = respondedAt
        self.createdAt = createdAt
        self.sourceRuleID = sourceRuleID
        self.ruleWeekday = ruleWeekday
        self.ruleHour = ruleHour
        self.ruleMinute = ruleMinute
    }

    var status: OccurrenceStatus {
        get { OccurrenceStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
