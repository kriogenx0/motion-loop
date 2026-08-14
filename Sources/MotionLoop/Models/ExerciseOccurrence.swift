import Foundation
import SwiftData

/// One concrete scheduled instance of an Activity on a specific day, and
/// whether the user completed it. `windowEnd` is set only for window-type
/// schedules (a deadline to complete by); reminder-type and freeform
/// occurrences have no deadline at all.
@Model
final class ExerciseOccurrence {
    @Attribute(.unique) var id: UUID
    var scheduledDate: Date
    /// nil for reminder-type occurrences and freeform completions -- there is
    /// no deadline, so there is nothing for OccurrenceReconciler to expire.
    var windowEnd: Date?
    /// Backing storage for `status`. Stored as a raw String rather than the enum
    /// itself because SwiftData #Predicate filtering on custom enums is unreliable.
    var statusRaw: String
    var respondedAt: Date?
    var createdAt: Date

    /// Plain UUID reference to the ScheduleTime that generated this occurrence --
    /// intentionally NOT a SwiftData relationship, so editing/removing the time
    /// later never touches already-generated history. nil for freeform.
    var sourceScheduleTimeID: UUID?
    var ruleWeekday: Int
    var ruleHour: Int
    var ruleMinute: Int

    /// Shared by every activity's occurrence generated from the same
    /// (ScheduleTime, day) slot on a Schedule -- this is what makes those
    /// occurrences one "session": one notification, one SessionView. nil for
    /// freeform completions, which are always a session of one.
    var sessionID: UUID?

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
        windowEnd: Date?,
        status: OccurrenceStatus = .pending,
        respondedAt: Date? = nil,
        createdAt: Date = .now,
        sourceScheduleTimeID: UUID?,
        sessionID: UUID?,
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
        self.sourceScheduleTimeID = sourceScheduleTimeID
        self.sessionID = sessionID
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

    /// Display-only reinterpretation of `status` -- see OccurrenceDisplay for
    /// why this exists and never mutates the stored status.
    func effectiveStatus(now: Date = .now, calendar: Calendar = .current) -> OccurrenceStatus {
        OccurrenceDisplay.effectiveStatus(
            status: status, scheduledDate: scheduledDate, windowEnd: windowEnd, now: now, calendar: calendar
        )
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
