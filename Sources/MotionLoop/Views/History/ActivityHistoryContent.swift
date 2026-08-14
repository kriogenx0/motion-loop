import SwiftUI
import SwiftData

/// Section content for "Activity" mode -- every activity that still exists
/// (archived ones included -- archiving just stops scheduling, it never
/// deletes), with its all-time completed/missed totals. An activity the user
/// actually deleted from AddEditActivityView no longer has a row here, though
/// its resolved (completed/missed) occurrences still appear in Day/Week/Month
/// history via their own snapshot fields. Tapping a row navigates (via
/// `navigationDestination(for: Activity.self)`, wired up by HistoryView) into
/// ActivityHistoryDetailView for that activity's full occurrence history.
struct ActivityHistoryContent: View {
    @Query(sort: [SortDescriptor(\Activity.createdAt, order: .reverse)])
    private var activities: [Activity]

    var body: some View {
        Section("Activities") {
            if activities.isEmpty {
                Text("No activities yet.").foregroundStyle(.secondary)
            }
            ForEach(activities) { activity in
                NavigationLink(value: activity) {
                    ActivityHistoryRow(activity: activity)
                }
            }
        }
    }
}

private struct ActivityHistoryRow: View {
    let activity: Activity

    private var completed: Int { activity.occurrences.filter { $0.effectiveStatus() == .completed }.count }
    private var missed: Int { activity.occurrences.filter { $0.effectiveStatus() == .missed }.count }
    private var total: Int { completed + missed }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activity.name).font(.body.weight(.medium))
                    if activity.isArchived {
                        Text("Archived")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                Text(total > 0 ? "\(completed)/\(total) completed" : "No history yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
