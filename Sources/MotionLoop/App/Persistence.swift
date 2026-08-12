import Foundation
import SwiftData

/// Single shared ModelContainer, used both by the SwiftUI environment and by
/// NotificationDelegate (which can run while the app is backgrounded, outside
/// any view's environment, so it needs a container reference of its own).
enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([Activity.self, ScheduleRule.self, ExerciseOccurrence.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
