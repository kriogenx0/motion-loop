import Foundation

/// Derived (never stored) from `Activity.schedule` -- see `Activity.effectiveMode`.
enum ActivityMode {
    /// No schedule at all: completable anytime, no notifications.
    case freeform
    /// Scheduled with a completion deadline; missing it becomes `.missed`.
    case window
    /// Scheduled with no deadline; completions are gated by a minimum gap
    /// since the last completion instead.
    case reminder
}
