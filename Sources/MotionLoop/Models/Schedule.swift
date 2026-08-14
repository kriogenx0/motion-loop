import Foundation
import SwiftData

enum ScheduleType: String, Codable, CaseIterable {
    case window
    case reminder
}

/// A shareable set of (weekday, time-of-day) slots that one or more Activities
/// can point to -- Activities sharing a Schedule form a "session": they fire
/// together as one notification and get checked off together in one SessionView.
///
/// `.window` schedules have a mandatory completion deadline (`windowDurationMinutes`);
/// missing it flips the occurrence to `.missed`. `.reminder` schedules have no
/// deadline at all -- they're just notification nudges -- and instead enforce a
/// minimum gap between completions (`minimumGapMinutes`) so multiple check-ins a
/// day can't be logged back-to-back.
@Model
final class Schedule {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    /// Backing storage for `type` -- stored as a raw String for the same reason
    /// Activity.targetTypeRaw is: SwiftData #Predicate filtering on custom enums
    /// is unreliable.
    var typeRaw: String
    /// Set iff type == .window; the deadline after which a pending occurrence
    /// becomes missed.
    var windowDurationMinutes: Int?
    /// Set iff type == .reminder; the minimum time that must pass between two
    /// completions of an activity on this schedule.
    var minimumGapMinutes: Int?
    /// Optional pre-notification lead time, either type. nil = no lead-time
    /// notification is scheduled.
    var leadTimeMinutes: Int?

    @Relationship(deleteRule: .cascade, inverse: \ScheduleTime.schedule)
    var times: [ScheduleTime] = []

    /// `.nullify`, not `.cascade`: a Schedule must never be silently deleted out
    /// from under an Activity. Schedules become unreferenced only when every
    /// Activity using them switches away or is deleted, and are then pruned
    /// explicitly by ScheduleEngine.pruneOrphanedSchedules.
    @Relationship(deleteRule: .nullify, inverse: \Activity.schedule)
    var activities: [Activity] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        type: ScheduleType,
        windowDurationMinutes: Int? = nil,
        minimumGapMinutes: Int? = nil,
        leadTimeMinutes: Int? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.typeRaw = type.rawValue
        self.windowDurationMinutes = windowDurationMinutes
        self.minimumGapMinutes = minimumGapMinutes
        self.leadTimeMinutes = leadTimeMinutes
    }

    var type: ScheduleType {
        get { ScheduleType(rawValue: typeRaw) ?? .window }
        set { typeRaw = newValue.rawValue }
    }
}
