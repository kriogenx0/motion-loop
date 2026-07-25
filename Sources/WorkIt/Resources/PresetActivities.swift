import Foundation

struct PresetActivity: Identifiable, Hashable, Decodable {
    var id: String { name }
    let name: String
    let symbolName: String
    let featured: Bool
    let defaultDurationMinutes: Int?
    let defaultSets: Int?
    let defaultReps: Int?
}

/// The user can always type any activity name they like -- this list only
/// powers autocomplete suggestions as they type. Kept as a bundled static JSON
/// file (not hardcoded Swift) so the list can grow without touching code.
enum PresetActivities {
    static let all: [PresetActivity] = loadPresets()
    static let featured: [PresetActivity] = all.filter(\.featured)
    static let customSymbolName = "star.fill"

    private static func loadPresets() -> [PresetActivity] {
        guard
            let url = Bundle.main.url(forResource: "PresetActivities", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let presets = try? JSONDecoder().decode([PresetActivity].self, from: data)
        else {
            return []
        }
        return presets
    }
}
