import Foundation
import SwiftData

/// Whether an occurrence can be completed right now, and why not if it can't.
/// Exposed so both CompletionService.complete (the actual write-path) and
/// SessionView (read-only per-row UI state) derive the same answer instead of
/// duplicating the window/gap logic.
enum CompletionAvailability: Equatable {
    case completed
    case available
    case windowClosed
    case gapBlocked(availableAt: Date)
}

enum CompletionOutcome: Equatable {
    case completed
    case blockedByWindow
    case blockedByGap(availableAt: Date)
}

/// Single write-path for marking anything complete -- Today taps, SessionView
/// taps, and the notification "Mark Complete" action all funnel through here,
/// so the window/gap defense-in-depth checks live in exactly one place instead
/// of being duplicated (and potentially drifting) across call sites.
enum CompletionService {
    /// Window-type: never trust a possibly-stale `.pending` status -- a
    /// SessionView opened before the last reconciler tick could otherwise let
    /// a closed window be completed. Reminder-type: gated by minimum-gap-
    /// since-last-completion instead of a deadline.
    static func availability(
        for occurrence: ExerciseOccurrence,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CompletionAvailability {
        switch occurrence.status {
        case .completed:
            return .completed
        case .missed:
            return .windowClosed
        case .pending:
            break
        }

        if let windowEnd = occurrence.windowEnd {
            return now < windowEnd ? .available : .windowClosed
        }

        if let activity = occurrence.activity,
           activity.effectiveMode == .reminder,
           let gapMinutes = activity.schedule?.minimumGapMinutes {
            let lastCompletionAt = activity.occurrences
                .filter { $0.id != occurrence.id && $0.status == .completed }
                .compactMap(\.respondedAt)
                .max()
            if let nextAllowed = GapEnforcer.nextAllowedCompletionDate(
                lastNonBonusCompletionAt: lastCompletionAt, minimumGapMinutes: gapMinutes, now: now, calendar: calendar
            ), now < nextAllowed {
                return .gapBlocked(availableAt: nextAllowed)
            }
        }

        return .available
    }

    @discardableResult
    static func complete(
        occurrence: ExerciseOccurrence,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CompletionOutcome {
        switch availability(for: occurrence, now: now, calendar: calendar) {
        case .completed:
            return .completed
        case .windowClosed:
            return .blockedByWindow
        case .gapBlocked(let availableAt):
            return .blockedByGap(availableAt: availableAt)
        case .available:
            occurrence.status = .completed
            occurrence.respondedAt = now
            try? context.save()
            return .completed
        }
    }

    /// Freeform activities have no schedule at all -- completing one creates
    /// and immediately resolves its own occurrence on the spot, rather than
    /// resolving a pre-generated one. Reuses ExerciseOccurrence (instead of a
    /// separate entity) so StreakCalculator/History/WeeklyStats handle
    /// freeform activities for free.
    @discardableResult
    static func completeFreeform(
        activity: Activity,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ExerciseOccurrence {
        let occurrence = ExerciseOccurrence(
            scheduledDate: now,
            windowEnd: nil,
            status: .completed,
            respondedAt: now,
            sourceScheduleTimeID: nil,
            sessionID: nil,
            ruleWeekday: calendar.component(.weekday, from: now),
            ruleHour: calendar.component(.hour, from: now),
            ruleMinute: calendar.component(.minute, from: now),
            activityName: activity.name,
            activitySymbolName: activity.symbolName,
            activityTargetDescription: activity.targetDescription
        )
        occurrence.activity = activity
        context.insert(occurrence)
        try? context.save()
        return occurrence
    }
}
