import Foundation

/// A name+icon+default-target suggestion, whether it comes from the bundled
/// preset list or from an activity the user has typed in before.
struct ActivitySuggestion: Identifiable, Hashable {
    var id: String { name.lowercased() }
    let name: String
    let symbolName: String
    let defaultDurationMinutes: Int?
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
                defaultDurationMinutes: $0.defaultDurationMinutes,
                defaultSets: $0.defaultSets,
                defaultReps: $0.defaultReps
            )
        }

        let presetNames = Set(PresetActivities.all.map { $0.name.lowercased() })
        var seenCustomNames = Set<String>()
        let customSuggestions = pastActivities
            .filter { $0.id != excludingActivityID }
            .sorted { $0.createdAt > $1.createdAt }
            .filter { !presetNames.contains($0.name.lowercased()) }
            .compactMap { pastActivity -> ActivitySuggestion? in
                guard seenCustomNames.insert(pastActivity.name.lowercased()).inserted else { return nil }
                return ActivitySuggestion(
                    name: pastActivity.name,
                    symbolName: pastActivity.symbolName,
                    defaultDurationMinutes: pastActivity.targetType == .duration ? pastActivity.targetDurationMinutes : nil,
                    defaultSets: pastActivity.targetType == .setsReps ? pastActivity.targetSets : nil,
                    defaultReps: pastActivity.targetType == .setsReps ? pastActivity.targetReps : nil
                )
            }

        return (presetSuggestions + customSuggestions)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
