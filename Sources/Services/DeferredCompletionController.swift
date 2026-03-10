import SwiftUI

/// Shared controller for deferred task completion (visual delay before data commit).
///
/// When a user taps the completion checkbox, the task shows a filled checkmark immediately
/// but stays visible in the list for ~3 seconds. After the delay, onCommit is called
/// (which persists the completion via SyncEngine) and the task animates out.
///
/// Each task has its own independent timer — completing multiple tasks in quick
/// succession works correctly (no timer-reset issues like DeferredSortController).
///
/// Used by both iOS (BacklogView) and macOS (ContentView).
@MainActor @Observable
final class DeferredCompletionController {

    /// Task IDs currently in "pending completion" visual state (filled checkbox, but not yet saved).
    private(set) var pendingIDs: Set<String> = []

    /// Per-task timers and their onCommit callbacks.
    private var timers: [String: Task<Void, Never>] = [:]
    private var commitCallbacks: [String: () async -> Void] = [:]

    // MARK: - Schedule

    /// Schedule a deferred completion for a task.
    /// Shows the task as "completed" visually immediately, but delays the actual data commit by 3 seconds.
    ///
    /// - Parameters:
    ///   - id: The task ID (UUID string).
    ///   - onCommit: Callback to execute after the delay (e.g., SyncEngine.completeTask + loadTasks).
    func scheduleCompletion(id: String, onCommit: @escaping () async -> Void) {
        // Cancel existing timer for this ID (double-tap resets)
        timers[id]?.cancel()

        pendingIDs.insert(id)
        commitCallbacks[id] = onCommit

        timers[id] = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }

            // Commit the completion
            await onCommit()

            // Clean up
            withAnimation(.smooth(duration: 0.35)) {
                pendingIDs.remove(id)
            }
            timers.removeValue(forKey: id)
            commitCallbacks.removeValue(forKey: id)
        }
    }

    // MARK: - Cancel (Undo during pending phase)

    /// Cancel a pending completion — used when user undoes during the 3-second window.
    /// The task returns to its normal (uncompleted) visual state. No data change occurs.
    ///
    /// - Parameter id: The task ID to cancel.
    func cancelCompletion(id: String) {
        timers[id]?.cancel()
        timers.removeValue(forKey: id)
        commitCallbacks.removeValue(forKey: id)
        withAnimation(.smooth(duration: 0.35)) {
            pendingIDs.remove(id)
        }
    }

    // MARK: - Query

    /// Check if a task is currently in the pending completion state.
    func isPending(_ id: String) -> Bool {
        pendingIDs.contains(id)
    }

    // MARK: - Flush (App Background)

    /// Immediately commit all pending completions.
    /// Called when the app goes to background to avoid losing completion state.
    func flushAll() async {
        for (id, timer) in timers {
            timer.cancel()
            if let callback = commitCallbacks[id] {
                await callback()
            }
        }
        timers.removeAll()
        commitCallbacks.removeAll()
        pendingIDs.removeAll()
    }
}
