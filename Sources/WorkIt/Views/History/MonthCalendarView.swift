import SwiftUI

/// A calendar grid for one month, one cell per day, colored by whether that day
/// had anything missed/completed/pending. Tapping a day navigates (via
/// `navigationDestination(for: Date.self)`, wired up by the presenting view) to
/// its detail. Purely a rendering component -- `daySummaries` is expected to
/// already cover exactly the days of one month, in order.
struct MonthCalendarView: View {
    let daySummaries: [DaySummary]
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var leadingEmptyCount: Int {
        guard let first = daySummaries.first?.day else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdayHeaderSymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(Array(weekdayHeaderSymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<leadingEmptyCount, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(daySummaries) { summary in
                    NavigationLink(value: summary.day) {
                        MonthDayCell(summary: summary, calendar: calendar)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MonthDayCell: View {
    let summary: DaySummary
    let calendar: Calendar

    private var dayNumber: Int { calendar.component(.day, from: summary.day) }
    private var isToday: Bool { calendar.isDateInToday(summary.day) }

    private var indicatorColor: Color? {
        if summary.missed > 0 { return .red }
        if summary.completed > 0 { return .green }
        if summary.pending > 0 { return .orange }
        return nil
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(.primary)
            Circle()
                .fill(indicatorColor ?? .clear)
                .frame(width: 6, height: 6)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            isToday ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}
