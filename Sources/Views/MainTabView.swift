import SwiftUI

enum AppTab: Hashable {
    case backlog, blox, focus, review
}

struct MainTabView: View {
    @Binding var selectedTab: AppTab

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
        }
        .accessibilityIdentifier("mainTabView_unified")
    }
}
