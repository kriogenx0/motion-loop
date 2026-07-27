import SwiftUI
import SwiftData

private enum HistoryMode: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    var id: String { rawValue }
}

struct HistoryView: View {
    @Query(sort: \ExerciseOccurrence.scheduledDate) private var allOccurrences: [ExerciseOccurrence]

    @State private var mode: HistoryMode = .week
    @State private var selectedWeekAnchor = Date.now
    @State private var selectedMonthAnchor = Date.now

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("View", selection: $mode) {
                        ForEach(HistoryMode.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowSeparator(.hidden)

                switch mode {
                case .week:
                    WeekHistoryContent(allOccurrences: allOccurrences, selectedWeekAnchor: $selectedWeekAnchor)
                case .month:
                    MonthHistoryContent(allOccurrences: allOccurrences, selectedMonthAnchor: $selectedMonthAnchor)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Date.self) { day in
                DayDetailView(day: day)
            }
        }
    }
}
