import Foundation

/// Determines what the menu bar status item should display.
/// Extracted as pure logic for testability — used by MenuBarController.
enum MenuBarIconState: Equatable {
    case idle           // Default cube.fill icon (no active block)
    case active(String) // Timer countdown text (mm:ss format)
    case allDone        // Checkmark — all tasks completed in active block

    /// Compute the icon state from current focus block state.
    /// - Parameters:
    ///   - block: The active FocusBlock (nil if no block active)
    ///   - now: Current timestamp (injected for testability)
    static func from(block: FocusBlock?, now: Date) -> MenuBarIconState {
        guard let block = block else { return .idle }

        // Check if block is currently active (now is between start and end)
        guard now >= block.startDate && now < block.endDate else { return .idle }

        // All tasks completed?
        if !block.taskIDs.isEmpty &&
            block.completedTaskIDs.count >= block.taskIDs.count {
            return .allDone
        }

        // Active with remaining time
        let remaining = block.endDate.timeIntervalSince(now)
        let seconds = max(0, Int(remaining))
        return .active(formatTimer(seconds))
    }

    /// Format seconds as mm:ss (e.g. 863 -> "14:23")
    static func formatTimer(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let secs = clamped % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}
