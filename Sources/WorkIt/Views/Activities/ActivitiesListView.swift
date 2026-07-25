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
                        Button("Remove", role: .destructive) {
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
        let enabledRules = activity.scheduleRules.filter(\.isEnabled)
        guard !enabledRules.isEmpty else { return "No schedule set" }
        let groups = ScheduleDisplay.groups(from: enabledRules.map { ($0.weekday, $0.hour, $0.minute) })
        return groups.map(\.displayText).joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name).font(.body.weight(.medium))
                Text(scheduleSummary).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
