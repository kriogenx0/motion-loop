import SwiftUI
import SwiftData

/// Dedicated full-screen exercise picker: a search bar over the entire
/// suggestion list (not just a featured subset -- this is the place to browse
/// or search, unlike a quick inline row). Browsing/searching the existing list
/// is the primary path -- an exercise "should already exist" here -- with
/// "Add Custom Exercise" as the explicit fallback for one that doesn't,
/// rather than typing into search silently offering to create one.
struct ExercisePickerView: View {
    var excludingActivityID: UUID?
    var onSelect: (ActivitySuggestion) -> Void

    @Query(sort: [SortDescriptor(\Activity.createdAt, order: .reverse)])
    private var pastActivities: [Activity]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var isPresentingCustomExerciseForm = false

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

    var body: some View {
        List {
            Section {
                Button {
                    isPresentingCustomExerciseForm = true
                } label: {
                    Label("Add Custom Exercise", systemImage: "plus.circle")
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
                    Text("No matches -- use \"Add Custom Exercise\" above to create it.")
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
        .sheet(isPresented: $isPresentingCustomExerciseForm) {
            CustomExerciseFormView(initialName: trimmedSearchText) { name, symbolName in
                select(ActivitySuggestion(
                    name: name,
                    symbolName: symbolName,
                    category: .other,
                    defaultDurationSeconds: nil,
                    defaultSets: nil,
                    defaultReps: nil
                ))
            }
        }
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

/// The one place name + icon are typed/picked together for an exercise that
/// isn't in the list yet -- reached only via the explicit "Add Custom
/// Exercise" button, never implicitly from typing in search.
private struct CustomExerciseFormView: View {
    let initialName: String
    var onSave: (_ name: String, _ symbolName: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var symbolName = PresetActivities.customSymbolName
    @State private var isPresentingIconPicker = false

    init(initialName: String, onSave: @escaping (_ name: String, _ symbolName: String) -> Void) {
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Button {
                            isPresentingIconPicker = true
                        } label: {
                            Image(systemName: symbolName)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                        }
                        .buttonStyle(.plain)
                        TextField("Exercise name", text: $name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                    }
                }
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), symbolName)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .sheet(isPresented: $isPresentingIconPicker) {
                IconPickerView(selection: $symbolName)
            }
        }
    }
}
