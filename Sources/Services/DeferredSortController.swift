import SwiftUI

/// Shared controller for deferred sort logic (freeze/unfreeze/timer/score-lookup).
///
/// When a user taps a badge (importance, urgency, etc.), the task's score changes immediately.
/// Without freezing, this causes the task to jump to a new position instantly.
/// This controller captures a snapshot of scores BEFORE the change, holds them for 3 seconds,
/// then smoothly animates to the new position.
///
/// Used by both iOS (BacklogView) and macOS (ContentView) — eliminates code duplication.
@MainActor @Observable
final class DeferredSortController {

    /// Frozen priority scores — maps task ID to score at freeze time.
    /// While non-nil, effectiveScore() returns the frozen value instead of the live score.
    private(set) var frozenScores: [String: Int]?

    /// Task IDs that are currently in the "pending resort" state (visual border indicator).
    private(set) var pendingIDs: Set<String> = []

    /// The active timer that will unfreeze scores after 3 seconds.
    private var resortTimer: Task<Void, Never>?

    // MARK: - Freeze

    /// Capture current scores BEFORE a badge update.
    /// If already frozen (multiple taps in quick succession), keeps the original snapshot.
    ///
    /// - Parameter scores: Dictionary mapping task IDs to their current priority scores.
    func freeze(scores: [String: Int]) {
        guard frozenScores == nil else { return }
        frozenScores = scores
    }

    // MARK: - Score Lookup

    /// Returns frozen score if available, otherwise the live score.
    /// Use this in sort closures and tier assignments to prevent jumping.
    ///
    /// - Parameters:
    ///   - id: The task ID (String UUID).
    ///   - liveScore: The current calculated score (used as fallback when not frozen).
    /// - Returns: The effective score for sorting.
    func effectiveScore(id: String, liveScore: Int) -> Int {
        frozenScores?[id] ?? liveScore
    }

    // MARK: - Deferred Resort

    /// Start the 3-second deferred resort timer.
    /// Cancels any previous timer (timer reset on subsequent badge taps).
    ///
    /// - Parameters:
    ///   - id: The task ID that was just modified.
    ///   - onUnfreeze: Optional callback after unfreeze (e.g., iOS calls refreshLocalTasks()).
    func scheduleDeferredResort(id: String, onUnfreeze: (() async -> Void)? = nil) {
        pendingIDs.insert(id)
        resortTimer?.cancel()
        resortTimer = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            // Phase 1: fade out pending borders
            withAnimation(.easeOut(duration: 0.3)) {
                pendingIDs.removeAll()
            }
            // Phase 2: pause, then unfreeze sort order with smooth animation
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.4)) {
                frozenScores = nil
            }
            await onUnfreeze?()
        }
    }

    // MARK: - Query

    /// Check if a task ID is currently in the pending resort state.
    func isPending(_ id: String) -> Bool {
        pendingIDs.contains(id)
    }
}
