import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var occurrences: [ExerciseOccurrence]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var now = Date.now
    @State private var checkInOccurrence: ExerciseOccurrence?

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _occurrences = Query(
            filter: #Predicate<ExerciseOccurrence> { $0.scheduledDate >= start && $0.scheduledDate < end },
            sort: \.scheduledDate
        )
    }

    private var activeNow: [ExerciseOccurrence] {
        occurrences.filter { $0.status == .pending && $0.scheduledDate <= now && now < $0.windowEnd }
    }
    private var upcoming: [ExerciseOccurrence] {
        occurrences.filter { $0.status == .pending && $0.scheduledDate > now }
    }
    private var completed: [ExerciseOccurrence] {
        occurrences.filter { $0.status == .completed }
    }
    private var missed: [ExerciseOccurrence] {
        occurrences.filter { $0.status == .missed }
    }

    var body: some View {
        NavigationStack {
            List {
                if occurrences.isEmpty {
                    ContentUnavailableView(
                        "Nothing Scheduled Today",
                        systemImage: "checkmark.circle",
                        description: Text("Add an activity with a schedule to see it here.")
                    )
                }

                section("Active Now", items: activeNow, showActions: true)
                section("Upcoming", items: upcoming, showActions: false)
                section("Completed", items: completed, showActions: false)
                section("Missed", items: missed, showActions: false)
            }
            .navigationTitle("Today")
            .onReceive(timer) { date in
                now = date
                try? ScheduleEngine.reconcileAndGenerate(context: modelContext, now: date)
            }
            .onChange(of: router.pendingCheckInOccurrenceID) { _, newValue in
                presentCheckIn(for: newValue)
            }
            .onAppear {
                presentCheckIn(for: router.pendingCheckInOccurrenceID)
            }
            .sheet(item: $checkInOccurrence) { occurrence in
                CheckInSheet(
                    occurrence: occurrence,
                    onComplete: { complete(occurrence) },
                    onMissed: { markMissed(occurrence) }
                )
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [ExerciseOccurrence], showActions: Bool) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { occurrence in
                    TodayOccurrenceRow(
                        occurrence: occurrence,
                        onComplete: showActions ? { complete(occurrence) } : nil,
                        onMissed: showActions ? { markMissed(occurrence) } : nil
                    )
                }
            }
        }
    }

    private func presentCheckIn(for occurrenceID: UUID?) {
        guard let occurrenceID, let occurrence = occurrences.first(where: { $0.id == occurrenceID }) else { return }
        checkInOccurrence = occurrence
        router.pendingCheckInOccurrenceID = nil
    }

    private func complete(_ occurrence: ExerciseOccurrence) {
        occurrence.status = .completed
        occurrence.respondedAt = .now
        try? modelContext.save()
    }

    private func markMissed(_ occurrence: ExerciseOccurrence) {
        occurrence.status = .missed
        occurrence.respondedAt = .now
        try? modelContext.save()
    }
}
