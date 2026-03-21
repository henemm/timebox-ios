import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case backlog, blox, focus, review, refiner
}

struct MainTabView: View {
    @Binding var selectedTab: AppTab

    @Query(
        filter: #Predicate<LocalTask> { $0.lifecycleStatus == "raw" && !$0.isCompleted }
    ) private var rawTasks: [LocalTask]

    var body: some View {
        TabView(selection: $selectedTab) {
            BacklogView()
                .tabItem {
                    Label("Backlog", systemImage: "list.bullet")
                }
                .tag(AppTab.backlog)

            BlockPlanningView()
                .tabItem {
                    Label("Blox", systemImage: "calendar")
                }
                .tag(AppTab.blox)

            FocusLiveView()
                .tabItem {
                    Label("Focus", systemImage: "target")
                }
                .tag(AppTab.focus)

            DailyReviewView()
                .tabItem {
                    Label("Review", systemImage: "chart.bar")
                }
                .tag(AppTab.review)

            RefinerView()
                .tabItem {
                    Label("Refiner", systemImage: "sparkles")
                }
                .tag(AppTab.refiner)
                .badge(rawTasks.count)
        }
        .accessibilityIdentifier("mainTabView_unified")
    }
}
