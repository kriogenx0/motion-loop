import SwiftUI
import SwiftData
import UserNotifications

@main
struct WorkItApp: App {
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
