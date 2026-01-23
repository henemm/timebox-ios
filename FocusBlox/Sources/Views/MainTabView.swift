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
                    Label("Blöcke", systemImage: "rectangle.split.3x1")
                }

            TaskAssignmentView()
                .tabItem {
                    Label("Zuordnen", systemImage: "arrow.up.and.down.text.horizontal")
                }

            FocusLiveView()
                .tabItem {
                    Label("Fokus", systemImage: "target")
                }
        }
    }
}
