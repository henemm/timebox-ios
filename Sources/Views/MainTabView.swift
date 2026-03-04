import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            BacklogView()
                .tabItem {
                    Label("Backlog", systemImage: "list.bullet")
                }

            BlockPlanningView()
                .tabItem {
                    Label("Blox", systemImage: "calendar")
                }

            FocusLiveView()
                .tabItem {
                    Label("Focus", systemImage: "target")
                }

            DailyReviewView()
                .tabItem {
                    Label("Review", systemImage: "chart.bar")
                }
        }
        .accessibilityIdentifier("mainTabView_unified")
    }
}
