import SwiftUI
import SwiftData

private enum HistoryEntry: Identifiable {
    case occurrence(ExerciseOccurrence)
    case bonus(BonusCompletion)

    var id: UUID {
        switch self {
        case .occurrence(let occurrence): return occurrence.id
        case .bonus(let bonus): return bonus.id
        }
    }

    var date: Date {
        switch self {
        case .occurrence(let occurrence): return occurrence.scheduledDate
        case .bonus(let bonus): return bonus.completedAt
        }
    }
}

/// Full occurrence + bonus-completion history for one activity, most recent
/// first. A bonus completion is displayed here as part of the record, but --
/// deliberately -- never folds into the completed/missed counts or streak
/// above it, since bonus completions are inert with respect to both.
struct ActivityHistoryDetailView: View {
    let activity: Activity
    @Environment(\.modelContext) private var modelContext

    private var entries: [HistoryEntry] {
        let occurrenceEntries = activity.occurrences.map(HistoryEntry.occurrence)
        let bonusEntries = activity.bonusCompletions.map(HistoryEntry.bonus)
        return (occurrenceEntries + bonusEntries).sorted { $0.date > $1.date }
    }
    private var completed: Int { activity.occurrences.filter { $0.effectiveStatus() == .completed }.count }
    private var missed: Int { activity.occurrences.filter { $0.effectiveStatus() == .missed }.count }

    private var streak: Int {
        let occurrences = activity.occurrences.map {
            StreakCalculator.StreakOccurrence(scheduledDate: $0.scheduledDate, status: $0.effectiveStatus())
        }
        return StreakCalculator.currentStreak(occurrences: occurrences, hasSchedule: activity.schedule != nil, today: .now, now: .now)
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "calendar",
                    description: Text("This activity hasn't had any scheduled occurrences yet.")
                )
            } else {
                Section {
                    if streak > 0 {
                        HStack(spacing: 8) {
                            Text(StreakDisplay.flames(for: streak))
                            Text(StreakDisplay.label(for: streak)).font(.headline)
                        }
                    }
                    HStack(spacing: 16) {
                        Label("\(completed) completed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("\(missed) missed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                    .labelStyle(.titleAndIcon)

                    Button {
                        BonusCompletionService.logBonusCompletion(for: activity, context: modelContext)
                    } label: {
                        Label("Log Bonus Completion", systemImage: "plus.circle.fill")
                    }
                }

                Section("History") {
                    ForEach(entries) { entry in
                        switch entry {
                        case .occurrence(let occurrence):
                            ActivityOccurrenceRow(occurrence: occurrence)
                        case .bonus(let bonus):
                            BonusCompletionRow(bonus: bonus)
                        }
                    }
                }
            }
        }
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ActivityOccurrenceRow: View {
    let occurrence: ExerciseOccurrence

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: occurrence.scheduledDate)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: occurrence.scheduledDate)
    }

    private var completedTimeText: String? {
        guard occurrence.status == .completed, let respondedAt = occurrence.respondedAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Completed \(formatter.string(from: respondedAt))"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                Text("Scheduled \(timeText)").font(.caption).foregroundStyle(.secondary)
                if let completedTimeText {
                    Text(completedTimeText).font(.caption).foregroundStyle(.green)
                }
            }
            Spacer()
            statusIcon
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch occurrence.effectiveStatus() {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .missed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .pending:
            Image(systemName: "clock.fill").foregroundStyle(.orange)
        }
    }
}

private struct BonusCompletionRow: View {
    let bonus: BonusCompletion

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: bonus.completedAt)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: bonus.completedAt)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dateText)
                    Text("Bonus")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15), in: Capsule())
                }
                Text("Completed \(timeText)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill").foregroundStyle(.purple)
        }
    }
}
