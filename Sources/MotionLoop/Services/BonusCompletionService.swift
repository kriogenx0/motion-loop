import Foundation
import SwiftData

/// Logs an extra completion beyond an activity's normal schedule. Deliberately
/// inert with respect to CompletionService's gap check and every stats/streak
/// call site -- see BonusCompletion's own doc comment for why it's a separate
/// entity rather than a flag.
enum BonusCompletionService {
    @discardableResult
    static func logBonusCompletion(
        for activity: Activity,
        context: ModelContext,
        now: Date = .now
    ) -> BonusCompletion {
        let bonus = BonusCompletion(completedAt: now, activityName: activity.name, activitySymbolName: activity.symbolName)
        bonus.activity = activity
        context.insert(bonus)
        try? context.save()
        return bonus
    }
}
