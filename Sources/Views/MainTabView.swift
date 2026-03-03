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
                    Label("Blöcke", systemImage: "calendar")
                }

            FocusLiveView()
                .tabItem {
                    Label("Fokus", systemImage: "target")
                }

            DailyReviewView()
                .tabItem {
                    Label("Rückblick", systemImage: "chart.bar")
                }
        }
        .accessibilityIdentifier("mainTabView_unified")
    }
}
