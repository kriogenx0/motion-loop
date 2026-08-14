import SwiftUI
import SwiftData

struct ActivitiesListView: View {
    @Query(filter: #Predicate<Activity> { $0.isArchived == false }, sort: \Activity.createdAt)
    private var activities: [Activity]
    @Environment(\.modelContext) private var modelContext

    @State private var isPresentingAdd = false
    @State private var editingActivity: Activity?

    var body: some View {
        NavigationStack {
            List {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "No Activities Yet",
                        systemImage: "figure.run",
                        description: Text("Tap + to add an exercise and set its schedule.")
                    )
                }
                ForEach(activities) { activity in
                    Button {
                        editingActivity = activity
                    } label: {
                        ActivityRow(activity: activity)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Archive", role: .destructive) {
                            archive(activity)
                        }
                    }
                }
            }
            .navigationTitle("Activities")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAdd) {
                AddEditActivityView(activity: nil)
            }
            .sheet(item: $editingActivity) { activity in
                AddEditActivityView(activity: activity)
            }
        }
    }

    private func archive(_ activity: Activity) {
        activity.isArchived = true
        try? modelContext.save()
        try? ScheduleEngine.syncNotifications(context: modelContext)
    }
}

private struct ActivityRow: View {
    let activity: Activity

    private var scheduleSummary: String {
        guard let schedule = activity.schedule else { return "Freeform \u{2014} complete anytime" }
        let enabledTimes = schedule.times.filter(\.isEnabled)
        guard !enabledTimes.isEmpty else { return "No schedule set" }
        let groups = ScheduleDisplay.groups(from: enabledTimes.map { ($0.weekday, $0.hour, $0.minute) })
        let timesText = groups.map(\.displayText).joined(separator: ", ")
        switch schedule.type {
        case .window:
            return timesText
        case .reminder:
            let gap = schedule.minimumGapMinutes.map { ", \u{2265}\(ScheduleDisplay.windowDurationLabel($0)) apart" } ?? ""
            return "\(timesText)\(gap)"
        }
    }

    private var streak: Int {
        let occurrences = activity.occurrences.map {
            StreakCalculator.StreakOccurrence(scheduledDate: $0.scheduledDate, status: $0.effectiveStatus())
        }
        return StreakCalculator.currentStreak(occurrences: occurrences, hasSchedule: activity.schedule != nil, today: .now, now: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activity.name).font(.body.weight(.medium))
                    if let targetDescription = activity.targetDescription {
                        Text(targetDescription)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                    if streak > 0 {
                        Text("\(StreakDisplay.flames(for: streak)) \(streak)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(scheduleSummary).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
