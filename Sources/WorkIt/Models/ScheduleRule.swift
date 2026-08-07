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
    /// How long after `hour:minute` the user has to mark this complete before
    /// it's considered missed. User-editable per schedule entry in
    /// ScheduleRuleEditorView (options: 15/30/45/60/90/120 minutes).
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
