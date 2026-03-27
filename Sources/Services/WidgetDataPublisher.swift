import Foundation
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Publishes aggregated task data to App Group UserDefaults for widget consumption.
/// Called from main app context (SyncEngine, FocusBloxApp lifecycle).
enum WidgetDataPublisher {
    static let appGroupID = "group.com.henning.focusblox"

    /// Keys written to App Group UserDefaults
    static let nextUpCountKey = "widget_nextUpCount"
    static let completedTodayCountKey = "widget_completedTodayCount"
    static let totalTodayCountKey = "widget_totalTodayCount"
    static let oldestWaitingDaysKey = "widget_oldestWaitingDays"
    static let lastUpdatedKey = "widget_lastUpdated"

    /// Aggregates task data and writes to App Group UserDefaults.
    @MainActor
    static func publish(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let allTasks = (try? context.fetch(FetchDescriptor<LocalTask>())) ?? []

        let nextUp = allTasks.filter { !$0.isCompleted && $0.isNextUp }
        let completedToday = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= today
        }
        let oldestDays = nextUp.compactMap { task -> Int? in
            Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day
        }.max() ?? 0

        defaults.set(nextUp.count, forKey: nextUpCountKey)
        defaults.set(completedToday.count, forKey: completedTodayCountKey)
        defaults.set(nextUp.count + completedToday.count, forKey: totalTodayCountKey)
        defaults.set(oldestDays, forKey: oldestWaitingDaysKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastUpdatedKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "com.focusblox.daystatus")
        #endif
    }
}
