import SwiftUI

/// A calendar grid for one month, one cell per day, colored by whether that day
/// had anything missed/completed/pending. Days with anything scheduled are
/// tappable via `onSelectDay`. Purely a rendering component -- `daySummaries` is
/// expected to already cover exactly the days of one month, in order.
///
/// Deliberately uses a plain Button + callback rather than
/// NavigationLink(value:): a NavigationLink nested inside custom grid content
/// (as opposed to being a List row via ForEach) gets its disclosure chevron
/// promoted to the whole enclosing List row by UIKit, and taps can resolve to
/// the wrong link -- both show up as "the day cell has a stray arrow and opens
/// the wrong day." Routing the tap through a closure to the presenting view's
/// own NavigationPath avoids that entirely.
struct MonthCalendarView: View {
    let daySummaries: [DaySummary]
    let calendar: Calendar
    var onSelectDay: (Date) -> Void

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
                    let hasActivity = summary.completed + summary.missed + summary.pending + summary.upcoming > 0
                    if hasActivity {
                        Button {
                            onSelectDay(summary.day)
                        } label: {
                            MonthDayCell(summary: summary, calendar: calendar)
                        }
                        .buttonStyle(.plain)
                    } else {
                        MonthDayCell(summary: summary, calendar: calendar)
                    }
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
