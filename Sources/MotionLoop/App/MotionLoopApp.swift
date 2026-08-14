import SwiftUI
import SwiftData
import UserNotifications

@main
struct MotionLoopApp: App {
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate: NotificationDelegate

    init() {
        let router = AppRouter()
        _router = State(initialValue: router)
        notificationDelegate = NotificationDelegate(router: router, modelContainer: Persistence.container)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationManager.registerCategories()

        // Runs before the first frame renders, so the UI never shows stale
        // pending statuses for windows that already closed while the app was shut.
        let context = ModelContext(Persistence.container)
        try? ScheduleEngine.reconcileAndGenerate(context: context)

        // Today is only useful once there's something to check in on -- a
        // brand-new install with no activities yet should land on Activities
        // instead of an empty Today screen.
        router.selectedTab = Self.hasAnythingToShowToday(context: context) ? .today : .activities
    }

    /// True if any non-archived activity would show up on Today -- either a
    /// freeform activity (always available in the "Anytime" section) or one
    /// with at least one enabled scheduled time.
    private static func hasAnythingToShowToday(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.isArchived == false })
        guard let activities = try? context.fetch(descriptor) else { return false }
        return activities.contains { activity in
            guard let schedule = activity.schedule else { return true }
            return schedule.times.contains { $0.isEnabled }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
        }
        .modelContainer(Persistence.container)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let context = Persistence.container.mainContext
            try? ScheduleEngine.reconcileAndGenerate(context: context)
        }
    }
}
