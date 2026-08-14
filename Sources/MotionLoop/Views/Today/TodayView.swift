import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var occurrences: [ExerciseOccurrence]
    @Query(filter: #Predicate<Activity> { $0.isArchived == false && $0.schedule == nil }, sort: \Activity.createdAt)
    private var freeformActivities: [Activity]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var now = Date.now
    @State private var sessionSheetItem: SessionSheetItem?
    @State private var missedSessionSheetItem: SessionSheetItem?

    @State private var dailyEncouragement = Encouragement.random(from: Encouragement.daily)
    @State private var activeEncouragement = Encouragement.random(from: Encouragement.preActivity)
    @State private var confettiTrigger = 0
    @State private var completionMessage: String?

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private struct SessionSheetItem: Identifiable {
        let id = UUID()
        let occurrences: [ExerciseOccurrence]
    }

    private struct SessionGroup: Identifiable {
        let id: UUID
        let occurrences: [ExerciseOccurrence]
    }

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _occurrences = Query(
            filter: #Predicate<ExerciseOccurrence> { $0.scheduledDate >= start && $0.scheduledDate < end },
            sort: \.scheduledDate
        )
    }

    /// Sessions -- occurrences sharing a sessionID (or a singleton for
    /// freeform/unshared occurrences) -- bucketed the same way individual
    /// occurrences used to be, so a single-activity session behaves exactly
    /// like before.
    private var sessionsWithBuckets: [(bucket: SessionBucket, group: SessionGroup)] {
        let snapshots = occurrences.map {
            SessionOccurrenceSnapshot(id: $0.id, sessionID: $0.sessionID, scheduledDate: $0.scheduledDate, windowEnd: $0.windowEnd, status: $0.status)
        }
        let byID = Dictionary(uniqueKeysWithValues: occurrences.map { ($0.id, $0) })
        return SessionGrouping.groupIntoSessions(snapshots).compactMap { group -> (SessionBucket, SessionGroup)? in
            let fullOccurrences = group.compactMap { byID[$0.id] }
            guard let first = fullOccurrences.first else { return nil }
            let sessionGroup = SessionGroup(id: first.sessionID ?? first.id, occurrences: fullOccurrences)
            return (SessionGrouping.bucket(for: group, now: now), sessionGroup)
        }
    }

    private var activeNow: [SessionGroup] { sessionsWithBuckets.filter { $0.bucket == .activeNow }.map(\.group) }
    private var upcoming: [SessionGroup] { sessionsWithBuckets.filter { $0.bucket == .upcoming }.map(\.group) }
    private var completed: [SessionGroup] { sessionsWithBuckets.filter { $0.bucket == .completed }.map(\.group) }
    private var missed: [SessionGroup] { sessionsWithBuckets.filter { $0.bucket == .missed }.map(\.group) }

    var body: some View {
        NavigationStack {
            List {
                Text(dailyEncouragement)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if occurrences.isEmpty && freeformActivities.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Nothing Scheduled Today",
                            systemImage: "checkmark.circle",
                            description: Text("Add an activity with a schedule to see it here.")
                        )
                    }
                }

                anytimeSection

                section("Active Now", sessions: activeNow, showActions: true, note: activeEncouragement)
                section("Upcoming", sessions: upcoming, showActions: false)
                section("Completed", sessions: completed, showActions: false)
                section("Missed", sessions: missed, showActions: false)
            }
            .navigationTitle("Today")
            .onReceive(timer) { date in
                now = date
                try? ScheduleEngine.reconcileAndGenerate(context: modelContext, now: date)
            }
            .onChange(of: router.pendingRoute) { _, newValue in
                presentRoute(newValue)
            }
            .onAppear {
                presentRoute(router.pendingRoute)
            }
            .sheet(item: $sessionSheetItem) { item in
                SessionView(occurrences: item.occurrences, onComplete: { complete($0) }, now: now)
            }
            .sheet(item: $missedSessionSheetItem) { item in
                MissedSessionView(occurrences: item.occurrences)
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
    private var anytimeSection: some View {
        if !freeformActivities.isEmpty {
            Section("Anytime") {
                ForEach(freeformActivities) { activity in
                    FreeformActivityRow(
                        activity: activity,
                        completedToday: hasCompletedToday(activity),
                        onComplete: { completeFreeform(activity) }
                    )
                }
            }
        }
    }

    private func hasCompletedToday(_ activity: Activity) -> Bool {
        occurrences.contains { $0.activity?.id == activity.id && $0.status == .completed }
    }

    @ViewBuilder
    private func section(_ title: String, sessions: [SessionGroup], showActions: Bool, note: String? = nil) -> some View {
        if !sessions.isEmpty {
            Section(title) {
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .listRowSeparator(.hidden)
                }
                ForEach(sessions) { group in
                    SessionCardView(
                        occurrences: group.occurrences,
                        now: now,
                        showActions: showActions,
                        onComplete: { complete($0) },
                        onBonus: { logBonus($0) }
                    )
                }
            }
        }
    }

    private func presentRoute(_ route: PendingRoute?) {
        guard let route else { return }
        switch route {
        case .session(let ids):
            let matched = occurrences.filter { ids.contains($0.id) }
            if !matched.isEmpty { sessionSheetItem = SessionSheetItem(occurrences: matched) }
        case .missedSession(let ids):
            let matched = occurrences.filter { ids.contains($0.id) }
            if !matched.isEmpty { missedSessionSheetItem = SessionSheetItem(occurrences: matched) }
        }
        router.pendingRoute = nil
    }

    private func complete(_ occurrence: ExerciseOccurrence) {
        switch CompletionService.complete(occurrence: occurrence, context: modelContext, now: now) {
        case .completed:
            celebrate(for: occurrence)
        case .blockedByWindow:
            showMessage("This window has closed.")
        case .blockedByGap(let availableAt):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            showMessage("Available at \(formatter.string(from: availableAt))")
        }
    }

    private func completeFreeform(_ activity: Activity) {
        let occurrence = CompletionService.completeFreeform(activity: activity, context: modelContext, now: now)
        celebrate(for: occurrence)
    }

    private func logBonus(_ occurrence: ExerciseOccurrence) {
        guard let activity = occurrence.activity else { return }
        BonusCompletionService.logBonusCompletion(for: activity, context: modelContext, now: now)
        showMessage("Bonus logged for \(activity.name)!")
    }

    /// Confetti always plays on a real completion. The toast text upgrades to
    /// the streak flame/label specifically at the moment a streak crosses into
    /// a new StreakDisplay tier (day 3, 7, 14, 30...) rather than every single
    /// day within a tier, so the escalation itself feels like the celebration.
    private func celebrate(for occurrence: ExerciseOccurrence) {
        confettiTrigger += 1

        guard let activity = occurrence.activity else {
            showMessage(Encouragement.random(from: Encouragement.completion))
            return
        }
        let hasSchedule = activity.schedule != nil
        let streakOccurrences = activity.occurrences.map {
            StreakCalculator.StreakOccurrence(scheduledDate: $0.scheduledDate, status: $0.effectiveStatus(now: now))
        }
        let streak = StreakCalculator.currentStreak(occurrences: streakOccurrences, hasSchedule: hasSchedule, today: now, now: now)
        let tier = StreakDisplay.tier(for: streak)
        let previousTier = StreakDisplay.tier(for: streak - 1)

        if streak > 0, tier != previousTier {
            showMessage("\(StreakDisplay.flames(for: streak)) \(StreakDisplay.label(for: streak))!")
        } else {
            showMessage(Encouragement.random(from: Encouragement.completion))
        }
    }

    private func showMessage(_ text: String) {
        completionMessage = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            completionMessage = nil
        }
    }
}

private struct FreeformActivityRow: View {
    let activity: Activity
    let completedToday: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name).font(.body.weight(.medium))
                if let targetDescription = activity.targetDescription {
                    Text(targetDescription).font(.caption).foregroundStyle(.secondary)
                }
                if completedToday {
                    Text("\u{2713} Completed today").font(.caption).foregroundStyle(.green)
                }
            }
            Spacer()
            Button("Mark Complete", action: onComplete)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
