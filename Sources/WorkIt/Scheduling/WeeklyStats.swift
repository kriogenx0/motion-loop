import Foundation

struct DaySummary: Identifiable {
    var id: Date { day }
    let day: Date
    let completed: Int
    let missed: Int
    let pending: Int
    let upcoming: Int
}

/// Minimal occurrence view needed to build day summaries, decoupled from SwiftData.
struct SummarizableOccurrence {
    let scheduledDate: Date
    let status: OccurrenceStatus
}

enum WeeklyStats {
    /// Buckets occurrences by calendar day, computing done/missed/pending/upcoming
    /// counts per day. `pending` occurrences whose window is still open count as
    /// "pending"; ones whose window is in the future count as "upcoming".
    static func daySummaries(
        for occurrences: [SummarizableOccurrence],
        in interval: DateInterval,
        now: Date,
        calendar: Calendar = .current
    ) -> [DaySummary] {
        var byDay: [Date: [SummarizableOccurrence]] = [:]
        for occurrence in occurrences {
            let day = calendar.startOfDay(for: occurrence.scheduledDate)
            byDay[day, default: []].append(occurrence)
        }

        var days: [DaySummary] = []
        var cursor = calendar.startOfDay(for: interval.start)
        let end = interval.end
        while cursor < end {
            let dayOccurrences = byDay[cursor] ?? []
            var completed = 0, missed = 0, pending = 0, upcoming = 0
            for occurrence in dayOccurrences {
                switch occurrence.status {
                case .completed: completed += 1
                case .missed: missed += 1
                case .pending:
                    if occurrence.scheduledDate > now { upcoming += 1 } else { pending += 1 }
                }
            }
            days.append(DaySummary(day: cursor, completed: completed, missed: missed, pending: pending, upcoming: upcoming))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
}
