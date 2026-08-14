import Foundation
import SwiftData

/// A single recurring (weekday, time-of-day) slot belonging to one Schedule.
/// Selecting several weekdays in the UI for one time fans out into multiple
/// ScheduleTime rows -- each row always represents exactly one weekday.
@Model
final class ScheduleTime {
    @Attribute(.unique) var id: UUID
    /// 1 = Sunday ... 7 = Saturday, matching Calendar.Component.weekday.
    var weekday: Int
    var hour: Int
    var minute: Int
    var isEnabled: Bool

    var schedule: Schedule?

    init(
        id: UUID = UUID(),
        weekday: Int,
        hour: Int,
        minute: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
    }

    var snapshot: ScheduleTimeSnapshot {
        ScheduleTimeSnapshot(
            scheduleTimeID: id,
            scheduleID: schedule?.id ?? UUID(),
            weekday: weekday,
            hour: hour,
            minute: minute
        )
    }
}
