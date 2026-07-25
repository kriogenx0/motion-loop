import Foundation

struct PresetActivity: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let symbolName: String
}

enum PresetActivities {
    static let all: [PresetActivity] = [
        PresetActivity(name: "Push-ups", symbolName: "figure.strengthtraining.traditional"),
        PresetActivity(name: "Squats", symbolName: "figure.squats"),
        PresetActivity(name: "Plank", symbolName: "figure.core.training"),
        PresetActivity(name: "Running", symbolName: "figure.run"),
        PresetActivity(name: "Cycling", symbolName: "figure.outdoor.cycle"),
        PresetActivity(name: "Yoga", symbolName: "figure.yoga"),
        PresetActivity(name: "Stretching", symbolName: "figure.flexibility"),
        PresetActivity(name: "Jumping Jacks", symbolName: "figure.jumprope"),
        PresetActivity(name: "Pull-ups", symbolName: "figure.strengthtraining.functional"),
        PresetActivity(name: "Walking", symbolName: "figure.walk"),
    ]

    static let customSymbolName = "star.fill"
}
