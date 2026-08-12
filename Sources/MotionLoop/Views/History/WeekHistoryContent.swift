import SwiftUI
import SwiftData

/// Section content for "Week" mode -- embedded inside HistoryView's List, not a
/// List of its own. Days with anything scheduled are tappable (via
/// `navigationDestination(for: Date.self)`, wired up by HistoryView) to drill
/// into DayDetailView; empty days are shown but not interactive.
struct WeekHistoryContent: View {
    let allOccurrences: [ExerciseOccurrence]
    @Binding var selectedWeekAnchor: Date

    private var calendar: Calendar { .current }

    private var weekInterval: DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: selectedWeekAnchor)
            ?? DateInterval(start: selectedWeekAnchor, duration: 7 * 24 * 3600)
    }

    private var weekOccurrences: [SummarizableOccurrence] {
        allOccurrences
            .filter { weekInterval.contains($0.scheduledDate) }
            .map { SummarizableOccurrence(scheduledDate: $0.scheduledDate, status: $0.status) }
    }

    private var daySummaries: [DaySummary] {
        WeeklyStats.daySummaries(for: weekOccurrences, in: weekInterval, now: .now, calendar: calendar)
    }

    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let end = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        return "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: end))"
    }

    var body: some View {
        Section {
            HStack {
                Button {
                    selectedWeekAnchor = calendar.date(byAdding: .day, value: -7, to: selectedWeekAnchor) ?? selectedWeekAnchor
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(weekRangeText).font(.headline)
                Spacer()
                Button {
                    selectedWeekAnchor = calendar.date(byAdding: .day, value: 7, to: selectedWeekAnchor) ?? selectedWeekAnchor
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
        }

        Section("Days") {
            ForEach(daySummaries) { summary in
                let hasActivity = summary.completed + summary.missed + summary.pending + summary.upcoming > 0
                if hasActivity {
                    NavigationLink(value: summary.day) {
                        DaySummaryRow(summary: summary)
                    }
                } else {
                    DaySummaryRow(summary: summary)
                }
            }
        }
    }
}
