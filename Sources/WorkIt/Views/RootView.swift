import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "checkmark.circle") }
                .tag(AppTab.today)

            ActivitiesListView()
                .tabItem { Label("Activities", systemImage: "figure.run") }
                .tag(AppTab.activities)

            WeeklySummaryView()
                .tabItem { Label("History", systemImage: "calendar") }
                .tag(AppTab.history)
        }
    }
}
