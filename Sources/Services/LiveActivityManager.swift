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
    func startActivity(for block: FocusBlock, currentTask: String?) async throws {
        // End any existing activity first
        endActivity()

        guard isSupported else { return }

        let attributes = FocusBlockActivityAttributes(
            blockTitle: block.title,
            startDate: block.startDate,
            endDate: block.endDate,
            totalTaskCount: block.taskIDs.count
        )

        let initialState = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: currentTask,
            completedCount: block.completedTaskIDs.count
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: block.endDate),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            // Activity couldn't be started (e.g., too many activities)
            throw error
        }
    }

    /// Update the current activity with new task info
    func updateActivity(currentTask: String?, completedCount: Int) {
        guard let activity = currentActivity else { return }

        let newState = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: currentTask,
            completedCount: completedCount
        )

        Task {
            await activity.update(
                ActivityContent(state: newState, staleDate: nil)
            )
        }
    }

    /// End the current activity
    func endActivity() {
        guard let activity = currentActivity else { return }

        let finalState = FocusBlockActivityAttributes.ContentState(
            currentTaskTitle: nil,
            completedCount: 0
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        currentActivity = nil
    }
}
