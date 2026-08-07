import SwiftUI
import SwiftData

/// Dedicated full-screen exercise picker: a search bar over the entire
/// suggestion list (not just a featured subset -- this is the place to browse
/// or search, unlike a quick inline row). The user can still enter any
/// activity they like: typing something that doesn't match an existing
/// suggestion surfaces a "Use "<text>"" row to confirm it as a custom entry.
struct ExercisePickerView: View {
    var excludingActivityID: UUID?
    var onSelect: (ActivitySuggestion) -> Void

    @Query(sort: [SortDescriptor(\Activity.createdAt, order: .reverse)])
    private var pastActivities: [Activity]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allSuggestions: [ActivitySuggestion] {
        ActivitySuggestions.all(pastActivities: pastActivities, excludingActivityID: excludingActivityID)
    }

    private var filteredSuggestions: [ActivitySuggestion] {
        guard !trimmedSearchText.isEmpty else { return allSuggestions }
        return allSuggestions.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearchText) }
    }

    private var searchTextMatchesExistingSuggestion: Bool {
        allSuggestions.contains { $0.name.localizedCaseInsensitiveCompare(trimmedSearchText) == .orderedSame }
    }

    var body: some View {
        List {
            if !trimmedSearchText.isEmpty && !searchTextMatchesExistingSuggestion {
                Section {
                    Button {
                        select(ActivitySuggestion(
                            name: trimmedSearchText,
                            symbolName: PresetActivities.customSymbolName,
                            defaultDurationMinutes: nil,
                            defaultSets: nil,
                            defaultReps: nil
                        ))
                    } label: {
                        Label("Use \"\(trimmedSearchText)\"", systemImage: "plus.circle")
                    }
                }
            }

            Section {
                if filteredSuggestions.isEmpty {
                    Text("No matches -- keep typing to add it as a custom exercise.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredSuggestions) { suggestion in
                    Button {
                        select(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.symbolName)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            Text(suggestion.name)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Choose Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ suggestion: ActivitySuggestion) {
        onSelect(suggestion)
        dismiss()
    }
}
