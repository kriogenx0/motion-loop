import SwiftUI
import SwiftData

/// Read-only: shows what happened on a specific day, missed items first since
/// that's what History is most often opened to check. No retroactive editing --
/// consistent with the rest of History being a record, not an editor.
struct DayDetailView: View {
    let day: Date

    @Query private var occurrences: [ExerciseOccurrence]

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _occurrences = Query(
            filter: #Predicate<ExerciseOccurrence> { $0.scheduledDate >= start && $0.scheduledDate < end },
            sort: \.scheduledDate
        )
    }

    private var missed: [ExerciseOccurrence] { occurrences.filter { $0.status == .missed } }
    private var completed: [ExerciseOccurrence] { occurrences.filter { $0.status == .completed } }
    private var pending: [ExerciseOccurrence] { occurrences.filter { $0.status == .pending } }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day)
    }

    var body: some View {
        List {
            if occurrences.isEmpty {
                ContentUnavailableView(
                    "Nothing Scheduled",
                    systemImage: "calendar",
                    description: Text("No activities were scheduled on this day.")
                )
            }
            section("Missed", items: missed)
            section("Completed", items: completed)
            section("Pending", items: pending)
        }
        .navigationTitle(dayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ title: String, items: [ExerciseOccurrence]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { occurrence in
                    TodayOccurrenceRow(occurrence: occurrence)
                }
            }
        }
    }
}
