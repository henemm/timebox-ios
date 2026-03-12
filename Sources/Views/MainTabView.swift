import SwiftUI

enum AppTab: Hashable {
    case backlog, blox, focus, review
}

struct MainTabView: View {
    @Binding var selectedTab: AppTab
    @AppStorage("coachModeEnabled") private var coachModeEnabled: Bool = false

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
                    Label(coachModeEnabled ? "Mein Tag" : "Review",
                          systemImage: coachModeEnabled ? "sun.and.horizon" : "chart.bar")
                }
                .tag(AppTab.review)
        }
        .accessibilityIdentifier("mainTabView_unified")
    }
}
