import Foundation

/// Broad exercise type, used to filter the exercise picker. Custom exercises
/// the user types in (not matched to a preset) fall into `.other`.
enum ExerciseCategory: String, CaseIterable, Codable, Identifiable {
    case cardio
    case weightTraining
    case stretching
    case core
    case mindBody
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cardio: "Cardio"
        case .weightTraining: "Weight Training"
        case .stretching: "Stretching"
        case .core: "Core"
        case .mindBody: "Mind & Body"
        case .other: "Other"
        }
    }
}
