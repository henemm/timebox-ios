import ActivityKit
import FocusBloxCore
import Foundation

/// Manages Live Activity lifecycle for Focus Blocks
/// Handles start, update, and end of Lock Screen / Dynamic Island activities
@MainActor
@Observable
final class LiveActivityManager: Sendable {

    /// Currently running activity (if any)
    private(set) var currentActivity: Activity<FocusBlockActivityAttributes>?

    /// Whether Live Activities are supported on this device
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Start a new Live Activity for a Focus Block
    func startActivity(for block: FocusBlock, currentTask: String?, knownTaskIDs: Set<String> = []) async throws {
        // End any existing activity first
        endActivity()

        // Bug 55E: Await-end ALL orphaned activities to prevent duplicates
        for orphan in Activity<FocusBlockActivityAttributes>.activities {
            await orphan.end(nil, dismissalPolicy: .immediate)
        }

        print("🚀 [LiveActivity] START: areActivitiesEnabled=\(ActivityAuthorizationInfo().areActivitiesEnabled), block=\(block.title)")

        guard isSupported else {
            print("🚫 [LiveActivity] NOT SUPPORTED - areActivitiesEnabled is false")
            return
        }

        let attributes = FocusBlockActivityAttributes(
            blockTitle: block.title,
            startDate: block.startDate,
            endDate: block.endDate,
            totalTaskCount: knownTaskIDs.isEmpty ? block.taskIDs.count : block.resolvedTaskCount(knownTaskIDs: knownTaskIDs)
        )

        let initialState = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: currentTask,
            completedCount: block.completedTaskIDs.count,
            taskEndDate: nil
        )

        // Retry loop for transient errors (similar to Meditationstimer)
        var lastError: Error?
        for attempt in 1...2 {
            do {
                print("🚀 [LiveActivity] START attempt \(attempt): block='\(block.title)', task='\(currentTask ?? "nil")'")
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: block.endDate),
                    pushType: nil
                )
                currentActivity = activity
                print("✅ [LiveActivity] START SUCCESS")
                return
            } catch {
                lastError = error
                print("❌ [LiveActivity] START attempt \(attempt) FAILED: \(error)")
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 120_000_000) // 0.12s
                }
            }
        }

        if let error = lastError {
            print("💥 [LiveActivity] START ULTIMATE FAILURE: \(error)")
            throw error
        }
    }

    /// Update the current activity with new task info
    func updateActivity(currentTask: String?, completedCount: Int, taskEndDate: Date? = nil) {
        guard let activity = currentActivity else {
            print("⚠️ [LiveActivity] UPDATE called but NO ACTIVE ACTIVITY (ignored)")
            return
        }

        let newState = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: currentTask,
            completedCount: completedCount,
            taskEndDate: taskEndDate
        )

        print("🔄 [LiveActivity] UPDATE: task='\(currentTask ?? "nil")', completed=\(completedCount)")
        Task {
            // Use staleDate for better background updates
            let staleDate = Date().addingTimeInterval(15)
            await activity.update(
                ActivityContent(state: newState, staleDate: staleDate)
            )
        }
    }

    /// End the current activity
    func endActivity() {
        guard let activity = currentActivity else {
            print("⚠️ [LiveActivity] END called but NO ACTIVE ACTIVITY (ignored)")
            return
        }

        print("🛑 [LiveActivity] END called")

        Task {
            // End with nil content using immediate dismissal
            await activity.end(nil, dismissalPolicy: .immediate)

            // Also end any orphaned activities
            for orphan in Activity<FocusBlockActivityAttributes>.activities {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
            print("✅ [LiveActivity] END COMPLETE")
        }

        currentActivity = nil
    }
}
