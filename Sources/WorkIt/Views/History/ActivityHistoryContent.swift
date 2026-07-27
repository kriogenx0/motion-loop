import SwiftUI
import SwiftData

/// Section content for "Activity" mode -- every activity ever entered
/// (including archived ones, since they're never hard-deleted), with its
/// all-time completed/missed totals. Tapping a row navigates (via
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

    private var completed: Int { activity.occurrences.filter { $0.status == .completed }.count }
    private var missed: Int { activity.occurrences.filter { $0.status == .missed }.count }
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
