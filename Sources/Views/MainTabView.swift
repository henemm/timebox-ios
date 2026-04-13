import SwiftUI
import SwiftData

enum AppTab: Hashable {
    // Classic 5-tab layout
    case backlog, blox, day, focus, review
    // Coach 4-tab layout
    case plan, coach
}

struct MainTabView: View {
    @Binding var selectedTab: AppTab
    var dayViewForcedPhase: DayPhase?
    var useCoachLayout: Bool = false

    @Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isParked && !$0.isTemplate })
    private var backlogTasks: [LocalTask]

    private var staleTaskCount: Int {
        let items = backlogTasks.map { PlanItem(localTask: $0) }
        return BacklogHealthService.findStaleTasks(in: items).count
    }

    var body: some View {
        if useCoachLayout {
            coachTabView
        } else {
            classicTabView
        }
    }

    // MARK: - Classic 5-Tab Layout

    private var classicTabView: some View {
        TabView(selection: $selectedTab) {
            BacklogView()
                .tabItem {
                    Label("Backlog", systemImage: "list.bullet")
                }
                .tag(AppTab.backlog)
                .badge(staleTaskCount)

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

    // MARK: - Coach 4-Tab Layout

    private var coachTabView: some View {
        TabView(selection: $selectedTab) {
            BacklogView()
                .tabItem {
                    Label("Backlog", systemImage: "list.bullet")
                }
                .tag(AppTab.backlog)
                .badge(staleTaskCount)

            BlockPlanningView()
                .tabItem {
                    Label("Planen", systemImage: "calendar")
                }
                .tag(AppTab.plan)

            FocusLiveView()
                .tabItem {
                    Label("Focus", systemImage: "target")
                }
                .tag(AppTab.focus)

            CoachView()
                .tabItem {
                    Label("Coach", systemImage: "sparkles")
                }
                .tag(AppTab.coach)
        }
        .accessibilityIdentifier("mainTabView_unified")
    }
}
