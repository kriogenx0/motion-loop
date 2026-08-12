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
        router.selectedTab = Self.hasAnyScheduledActivity(context: context) ? .today : .activities
    }

    private static func hasAnyScheduledActivity(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.isArchived == false })
        guard let activities = try? context.fetch(descriptor) else { return false }
        return activities.contains { $0.scheduleRules.contains { $0.isEnabled } }
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
