import Foundation

/// A single time-of-day with the set of weekdays it applies to, used to present
/// several one-weekday-one-time ScheduleRules as the "3x a day" / "3x a week"
/// groupings a user actually thinks in, without changing how they're stored.
struct ScheduleTimeGroup: Identifiable, Equatable {
    let id: String
    let hour: Int
    let minute: Int
    let weekdays: Set<Int>

    var displayText: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let time = Calendar.current.date(from: components) ?? .now
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeText = formatter.string(from: time)

        if weekdays.count == 7 {
            return "Every day at \(timeText)"
        }
        let symbols = DateFormatter().shortWeekdaySymbols ?? []
        let dayNames = weekdays.sorted().map { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : "?" }
        return "\(dayNames.joined(separator: ", ")) at \(timeText)"
    }
}

enum ScheduleDisplay {
    /// Groups flat (weekday, hour, minute) entries by time-of-day, unioning the
    /// weekdays that share a time -- regardless of which "Add Schedule" action
    /// created them -- so "every day at 7am" reads as one line, not seven.
    static func groups(from entries: [(weekday: Int, hour: Int, minute: Int)]) -> [ScheduleTimeGroup] {
        let grouped = Dictionary(grouping: entries) { "\($0.hour):\($0.minute)" }
        return grouped.map { key, values in
            ScheduleTimeGroup(
                id: key,
                hour: values[0].hour,
                minute: values[0].minute,
                weekdays: Set(values.map(\.weekday))
            )
        }
        .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    /// Human label for one of the fixed window-duration choices offered in
    /// ScheduleRuleEditorView -- e.g. 90 -> "1 hr 30 min".
    static func windowDurationLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        let hourText = hours == 1 ? "1 hr" : "\(hours) hr"
        return remainder == 0 ? hourText : "\(hourText) \(remainder) min"
    }
}
