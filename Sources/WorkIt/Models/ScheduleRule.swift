import Foundation
import SwiftData

/// A single recurring (weekday, time-of-day) rule belonging to one Activity.
/// Selecting several weekdays in the UI for one time fans out into multiple
/// ScheduleRule rows -- each row always represents exactly one weekday.
@Model
final class ScheduleRule {
    @Attribute(.unique) var id: UUID
    /// 1 = Sunday ... 7 = Saturday, matching Calendar.Component.weekday.
    var weekday: Int
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    /// Fixed at 60 for v1 (the "up to one hour" requirement); stored rather than
    /// hardcoded so a future version could make it user-editable without a migration.
    var windowDurationMinutes: Int

    var activity: Activity?

    init(
        id: UUID = UUID(),
        weekday: Int,
        hour: Int,
        minute: Int,
        isEnabled: Bool = true,
        windowDurationMinutes: Int = 60
    ) {
        self.id = id
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.windowDurationMinutes = windowDurationMinutes
    }

    var snapshot: ScheduleRuleSnapshot {
        ScheduleRuleSnapshot(
            ruleID: id,
            activityID: activity?.id ?? UUID(),
            weekday: weekday,
            hour: hour,
            minute: minute,
            windowDurationMinutes: windowDurationMinutes
        )
    }
}
