import Foundation

enum ActivityTargetType: String, Codable, CaseIterable {
    case none
    case duration
    case setsReps
}

/// Pure formatting for how an activity's target (if any) reads in the UI --
/// kept separate from the model so it's trivially unit-testable.
enum ActivityTargetFormatter {
    static func describe(type: ActivityTargetType, durationMinutes: Int?, sets: Int?, reps: Int?) -> String? {
        switch type {
        case .none:
            return nil
        case .duration:
            guard let durationMinutes, durationMinutes > 0 else { return nil }
            return durationMinutes == 1 ? "1 min" : "\(durationMinutes) min"
        case .setsReps:
            guard let sets, let reps, sets > 0, reps > 0 else { return nil }
            return "\(sets) \u{00d7} \(reps)"
        }
    }
}
