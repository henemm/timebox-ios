import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            BacklogView()
                .tabItem {
                    Label("Backlog", systemImage: "list.bullet")
                }

            PlanningView()
                .tabItem {
                    Label("Planen", systemImage: "calendar")
                }
        }
    }
}
