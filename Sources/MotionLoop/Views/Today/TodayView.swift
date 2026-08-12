import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var occurrences: [ExerciseOccurrence]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var now = Date.now
    @State private var checkInOccurrence: ExerciseOccurrence?

    @State private var dailyEncouragement = Encouragement.random(from: Encouragement.daily)
    @State private var activeEncouragement = Encouragement.random(from: Encouragement.preActivity)
    @State private var confettiTrigger = 0
    @State private var completionMessage: String?

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
                Text(dailyEncouragement)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)

                if occurrences.isEmpty {
                    ContentUnavailableView(
                        "Nothing Scheduled Today",
                        systemImage: "checkmark.circle",
                        description: Text("Add an activity with a schedule to see it here.")
                    )
                }

                section("Active Now", items: activeNow, showActions: true, note: activeEncouragement)
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
                    onComplete: { complete(occurrence) }
                )
            }
            .overlay {
                ConfettiView(trigger: confettiTrigger)
            }
            .overlay(alignment: .top) {
                if let completionMessage {
                    Text(completionMessage)
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: Capsule())
                        .shadow(radius: 4)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.spring(duration: 0.4), value: completionMessage)
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [ExerciseOccurrence], showActions: Bool, note: String? = nil) -> some View {
        if !items.isEmpty {
            Section(title) {
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .listRowSeparator(.hidden)
                }
                ForEach(items) { occurrence in
                    TodayOccurrenceRow(
                        occurrence: occurrence,
                        now: now,
                        onComplete: showActions ? { complete(occurrence) } : nil
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

        confettiTrigger += 1
        completionMessage = Encouragement.random(from: Encouragement.completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            completionMessage = nil
        }
    }

}
