import SwiftUI
import SwiftData

/// Section content for "Month" mode -- a calendar grid so missed days are
/// visible at a glance across the whole month, each day tappable (via
/// `navigationDestination(for: Date.self)`, wired up by HistoryView) into
/// DayDetailView.
struct MonthHistoryContent: View {
    let allOccurrences: [ExerciseOccurrence]
    @Binding var selectedMonthAnchor: Date

    private var calendar: Calendar { .current }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: selectedMonthAnchor)
            ?? DateInterval(start: selectedMonthAnchor, duration: 30 * 24 * 3600)
    }

    private var monthOccurrences: [SummarizableOccurrence] {
        allOccurrences
            .filter { monthInterval.contains($0.scheduledDate) }
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
        WeeklyStats.daySummaries(for: monthOccurrences, in: monthInterval, now: .now, calendar: calendar)
    }

    private var activitySummaries: [ActivitySummary] {
        WeeklyStats.activitySummaries(for: monthOccurrences)
    }

    private var totalMissed: Int { daySummaries.reduce(0) { $0 + $1.missed } }
    private var totalCompleted: Int { daySummaries.reduce(0) { $0 + $1.completed } }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonthAnchor)
    }

    var body: some View {
        Section {
            HStack {
                Button {
                    selectedMonthAnchor = calendar.date(byAdding: .month, value: -1, to: selectedMonthAnchor) ?? selectedMonthAnchor
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()
                Button {
                    selectedMonthAnchor = calendar.date(byAdding: .month, value: 1, to: selectedMonthAnchor) ?? selectedMonthAnchor
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)

            if totalMissed > 0 || totalCompleted > 0 {
                HStack(spacing: 16) {
                    Label("\(totalCompleted) completed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(totalMissed) missed", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.caption)
                .labelStyle(.titleAndIcon)
            }
        }

        Section {
            MonthCalendarView(daySummaries: daySummaries, calendar: calendar)
                .padding(.vertical, 4)
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
}
