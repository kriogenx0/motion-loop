import SwiftUI
import SwiftData

struct WeeklySummaryView: View {
    @Query(sort: \ExerciseOccurrence.scheduledDate) private var allOccurrences: [ExerciseOccurrence]
    @State private var selectedWeekAnchor = Date.now

    private var calendar: Calendar { .current }

    private var weekInterval: DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: selectedWeekAnchor)
            ?? DateInterval(start: selectedWeekAnchor, duration: 7 * 24 * 3600)
    }

    private var weekOccurrences: [SummarizableOccurrence] {
        allOccurrences
            .filter { weekInterval.contains($0.scheduledDate) }
            .map {
                SummarizableOccurrence(
                    activityID: $0.activity?.id ?? UUID(),
                    activityName: $0.activity?.name ?? "Activity",
                    scheduledDate: $0.scheduledDate,
                    windowEnd: $0.windowEnd,
                    status: $0.status
                )
            }
    }

    private var daySummaries: [DaySummary] {
        WeeklyStats.daySummaries(for: weekOccurrences, in: weekInterval, now: .now, calendar: calendar)
    }

    private var activitySummaries: [ActivitySummary] {
        WeeklyStats.activitySummaries(for: weekOccurrences)
    }

    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let end = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        return "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: end))"
    }

    var body: some View {
        NavigationStack {
            List {
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
                        DaySummaryRow(summary: summary)
                    }
                }

                if !activitySummaries.isEmpty {
                    Section("By Activity") {
                        ForEach(activitySummaries) { summary in
                            HStack {
                                Text(summary.activityName)
                                Spacer()
                                Text("\(summary.completed)/\(summary.total) completed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
