import Foundation
import SwiftData

/// Single shared ModelContainer, used both by the SwiftUI environment and by
/// NotificationDelegate (which can run while the app is backgrounded, outside
/// any view's environment, so it needs a container reference of its own).
enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([
            Activity.self, Schedule.self, ScheduleTime.self, ExerciseOccurrence.self, BonusCompletion.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // This schema has no migration path from the pre-Schedule-entity store
            // shape (deliberate, clean-break change): if a stale store from
            // before this change is still on disk, opening it throws rather than
            // silently corrupting data. Deleting it and retrying once turns that
            // into "starts fresh" instead of a permanent crash loop.
            NSLog("ModelContainer failed to load, resetting local store: \(error)")
            let path = configuration.url.path
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(atPath: path + suffix)
            }
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer even after resetting the store: \(error)")
            }
        }
    }()
}
