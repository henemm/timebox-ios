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

    /// Pending-Completions (3s-Phase nach Checkbox-Tap). Wird aus dem Counter
    /// ausgeschlossen (AC-13/AC-14), damit Punkt + Tab-Badge SOFORT verschwinden.
    @Environment(DeferredCompletionController.self) private var deferredCompletion

    /// Live-Tick fuer 60s-Refresh des Overdue-Counters (#288/#294/#296).
    /// Ohne diesen State wuerde der Counter nicht neu berechnet, wenn ein Task
    /// von "noch nicht faellig" zu "ueberfaellig" wechselt.
    @State private var timerTick = Date()
    private let badgeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// Anzahl ueberfaelliger Backlog-Tasks (#288/#294/#296) — Quelle der Wahrheit
    /// fuer Tab-Badge und App-Icon-Badge.
    /// Tasks in der DeferredCompletion-Pending-Phase werden ausgeschlossen
    /// (AC-13/AC-14): Counter -1 sofort bei Checkbox-Tap, +1 zurueck bei Undo.
    private var overdueTaskCount: Int {
        _ = timerTick  // Force recompute on timer fire (60s)
        let items = backlogTasks.map { PlanItem(localTask: $0) }
        return BacklogBadgeService.countOverdueTasks(
            items,
            excludingPendingIDs: deferredCompletion.pendingIDs
        )
    }

    var body: some View {
        ZStack {
            Group {
                if useCoachLayout {
                    coachTabView
                } else {
                    classicTabView
                }
            }
            // iOS 26: .badge() auf .tabItem ist nicht via UI-Test API zugaenglich.
            // Zusaetzlicher unsichtbarer StaticText spiegelt den Counter fuer XCUITest.
            Text("\(overdueTaskCount)")
                .frame(width: 0, height: 0)
                .opacity(0.001)
                .allowsHitTesting(false)
                .accessibilityIdentifier("iosOverdueCountBadge")
                .accessibilityHidden(false)
        }
        .onReceive(badgeTimer) { tick in
            timerTick = tick
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
                .badge(overdueTaskCount)

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
                .badge(overdueTaskCount)

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
