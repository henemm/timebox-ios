import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case backlog, blox, day, focus, review
}

struct MainTabView: View {
    @Binding var selectedTab: AppTab
    var dayViewForcedPhase: DayPhase?

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

            DayView(forcedPhase: dayViewForcedPhase)
                .tabItem {
                    Label("Tag", systemImage: "calendar.badge.clock")
                }
                .tag(AppTab.day)

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
