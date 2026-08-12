import Foundation

/// A name+icon+default-target suggestion, whether it comes from the bundled
/// preset list or from an activity the user has typed in before.
struct ActivitySuggestion: Identifiable, Hashable {
    var id: String { name.lowercased() }
    let name: String
    let symbolName: String
    let category: ExerciseCategory
    let defaultDurationSeconds: Int?
    let defaultSets: Int?
    let defaultReps: Int?
}

enum ActivitySuggestions {
    /// Every preset, plus distinct custom names the user has typed before
    /// (including for archived activities, since none are hard-deleted) --
    /// excluding names that duplicate a preset and the activity currently
    /// being edited. Alphabetized so the picker's long list is scannable.
    static func all(pastActivities: [Activity], excludingActivityID: UUID?) -> [ActivitySuggestion] {
        let presetSuggestions = PresetActivities.all.map {
            ActivitySuggestion(
                name: $0.name,
                symbolName: $0.symbolName,
                category: $0.category,
                defaultDurationSeconds: $0.defaultDurationMinutes.map { $0 * 60 },
                defaultSets: $0.defaultSets,
                defaultReps: $0.defaultReps
            )
        }

        let presetNames = Set(PresetActivities.all.map { $0.name.lowercased() })
        let customSuggestions = recentCustomSuggestions(
            pastActivities: pastActivities, excludingActivityID: excludingActivityID, presetNames: presetNames
        )

        return (presetSuggestions + customSuggestions)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Most-recently-used custom exercise names -- distinct from presets, most
    /// recent first, capped so "Recent" stays a quick-pick shortcut rather than
    /// duplicating the full alphabetized list.
    static func recent(pastActivities: [Activity], excludingActivityID: UUID?, limit: Int = 8) -> [ActivitySuggestion] {
        let presetNames = Set(PresetActivities.all.map { $0.name.lowercased() })
        return Array(
            recentCustomSuggestions(pastActivities: pastActivities, excludingActivityID: excludingActivityID, presetNames: presetNames)
                .prefix(limit)
        )
    }

    private static func recentCustomSuggestions(
        pastActivities: [Activity], excludingActivityID: UUID?, presetNames: Set<String>
    ) -> [ActivitySuggestion] {
        var seenCustomNames = Set<String>()
        return pastActivities
            .filter { $0.id != excludingActivityID }
            .sorted { $0.createdAt > $1.createdAt }
            .filter { !presetNames.contains($0.name.lowercased()) }
            .compactMap { pastActivity -> ActivitySuggestion? in
                guard seenCustomNames.insert(pastActivity.name.lowercased()).inserted else { return nil }
                return ActivitySuggestion(
                    name: pastActivity.name,
                    symbolName: pastActivity.symbolName,
                    category: .other,
                    defaultDurationSeconds: pastActivity.targetType == .duration ? pastActivity.targetDurationSeconds : nil,
                    defaultSets: pastActivity.targetType == .setsReps ? pastActivity.targetSets : nil,
                    defaultReps: pastActivity.targetType == .setsReps ? pastActivity.targetReps : nil
                )
            }
    }
}
