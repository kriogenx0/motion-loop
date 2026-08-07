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
    @State private var selectedCategory: ExerciseCategory?

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentSuggestions: [ActivitySuggestion] {
        ActivitySuggestions.recent(pastActivities: pastActivities, excludingActivityID: excludingActivityID)
    }

    private var allSuggestions: [ActivitySuggestion] {
        ActivitySuggestions.all(pastActivities: pastActivities, excludingActivityID: excludingActivityID)
    }

    private var filteredSuggestions: [ActivitySuggestion] {
        var results = allSuggestions
        if let selectedCategory {
            results = results.filter { $0.category == selectedCategory }
        }
        guard !trimmedSearchText.isEmpty else { return results }
        return results.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearchText) }
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
                            category: .other,
                            defaultDurationSeconds: nil,
                            defaultSets: nil,
                            defaultReps: nil
                        ))
                    } label: {
                        Label("Use \"\(trimmedSearchText)\"", systemImage: "plus.circle")
                    }
                }
            }

            if trimmedSearchText.isEmpty {
                categoryFilterSection

                if selectedCategory == nil && !recentSuggestions.isEmpty {
                    Section("Recent") {
                        ForEach(recentSuggestions) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                }
            }

            Section(trimmedSearchText.isEmpty ? "All Exercises" : "Results") {
                if filteredSuggestions.isEmpty {
                    Text("No matches -- keep typing to add it as a custom exercise.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredSuggestions) { suggestion in
                    suggestionRow(suggestion)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Choose Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(nil, label: "All")
                    ForEach(ExerciseCategory.allCases) { category in
                        categoryChip(category, label: category.displayName)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func categoryChip(_ category: ExerciseCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .padding(.leading, category == nil ? 16 : 0)
        .padding(.trailing, category == ExerciseCategory.allCases.last ? 16 : 0)
    }

    private func suggestionRow(_ suggestion: ActivitySuggestion) -> some View {
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

    private func select(_ suggestion: ActivitySuggestion) {
        onSelect(suggestion)
        dismiss()
    }
}
