import Foundation

struct DaySummary: Identifiable {
    var id: Date { day }
    let day: Date
    let completed: Int
    let missed: Int
    let pending: Int
    let upcoming: Int
}

struct ActivitySummary: Identifiable {
    var id: UUID { activityID }
    let activityID: UUID
    let activityName: String
    let completed: Int
    let missed: Int
    let total: Int
}

/// Minimal occurrence view needed to build day/week summaries, decoupled from SwiftData.
struct SummarizableOccurrence {
    let activityID: UUID
    let activityName: String
    let scheduledDate: Date
    let windowEnd: Date
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

    static func activitySummaries(for occurrences: [SummarizableOccurrence]) -> [ActivitySummary] {
        let grouped = Dictionary(grouping: occurrences, by: \.activityID)
        return grouped.map { activityID, occs in
            ActivitySummary(
                activityID: activityID,
                activityName: occs.first?.activityName ?? "",
                completed: occs.filter { $0.status == .completed }.count,
                missed: occs.filter { $0.status == .missed }.count,
                total: occs.count
            )
        }
        .sorted { $0.activityName < $1.activityName }
    }
}
