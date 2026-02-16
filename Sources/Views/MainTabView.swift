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

            TaskAssignmentView()
                .tabItem {
                    Label("Zuordnen", systemImage: "arrow.up.arrow.down")
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
