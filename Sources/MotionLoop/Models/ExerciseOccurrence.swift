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

    /// Snapshot of the activity's display fields at the moment this occurrence
    /// was created. Read by every view instead of `activity?.name` etc., so
    /// renaming/re-iconing/deleting the Activity later never retroactively
    /// changes how an already-generated occurrence reads, in Today or History --
    /// mirrors the existing ruleWeekday/ruleHour/ruleMinute snapshot below.
    var activityName: String = ""
    var activitySymbolName: String = "figure.run"
    var activityTargetDescription: String?

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
        ruleMinute: Int,
        activityName: String,
        activitySymbolName: String,
        activityTargetDescription: String?
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
        self.activityName = activityName
        self.activitySymbolName = activitySymbolName
        self.activityTargetDescription = activityTargetDescription
    }

    var status: OccurrenceStatus {
        get { OccurrenceStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Occurrences created before activity snapshots were introduced migrate
    /// with an empty name. Fall back to their relationship so those existing
    /// rows keep displaying correctly; newly generated and orphaned history
    /// continue to use the immutable snapshot.
    var displayActivityName: String {
        guard !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return activity?.name ?? "Activity"
        }
        return activityName
    }

    var displayActivitySymbolName: String {
        activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? activity?.symbolName ?? activitySymbolName
            : activitySymbolName
    }

    var displayActivityTargetDescription: String? {
        activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? activity?.targetDescription
            : activityTargetDescription
    }
}
