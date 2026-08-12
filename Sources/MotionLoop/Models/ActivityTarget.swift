import Foundation

enum ActivityTargetType: String, Codable, CaseIterable {
    case none
    case duration
    case setsReps
}

/// Pure formatting for how an activity's target (if any) reads in the UI --
/// kept separate from the model so it's trivially unit-testable.
enum ActivityTargetFormatter {
    static func describe(type: ActivityTargetType, durationSeconds: Int?, sets: Int?, reps: Int?) -> String? {
        switch type {
        case .none:
            return nil
        case .duration:
            guard let durationSeconds, durationSeconds > 0 else { return nil }
            return formatDuration(durationSeconds)
        case .setsReps:
            guard let sets, let reps, sets > 0, reps > 0 else { return nil }
            return "\(sets) \u{00d7} \(reps)"
        }
    }

    /// Renders whole minutes plainly and only shows seconds when they're
    /// non-zero, so a 15-second-precision duration doesn't force "X min 0 sec"
    /// on every round-minute target.
    static func formatDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes == 0 {
            return "\(seconds) sec"
        }
        if seconds == 0 {
            return minutes == 1 ? "1 min" : "\(minutes) min"
        }
        return "\(minutes) min \(seconds) sec"
    }
}
