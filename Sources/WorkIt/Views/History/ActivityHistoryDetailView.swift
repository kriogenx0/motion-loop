import SwiftUI

/// Full occurrence history for one activity, most recent first.
struct ActivityHistoryDetailView: View {
    let activity: Activity

    private var occurrences: [ExerciseOccurrence] {
        activity.occurrences.sorted { $0.scheduledDate > $1.scheduledDate }
    }
    private var completed: Int { occurrences.filter { $0.status == .completed }.count }
    private var missed: Int { occurrences.filter { $0.status == .missed }.count }

    var body: some View {
        List {
            if occurrences.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "calendar",
                    description: Text("This activity hasn't had any scheduled occurrences yet.")
                )
            } else {
                Section {
                    HStack(spacing: 16) {
                        Label("\(completed) completed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Label("\(missed) missed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                }

                Section("History") {
                    ForEach(occurrences) { occurrence in
                        ActivityOccurrenceRow(occurrence: occurrence)
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                Text(timeText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            statusIcon
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch occurrence.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .missed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .pending:
            Image(systemName: "clock.fill").foregroundStyle(.orange)
        }
    }
}
