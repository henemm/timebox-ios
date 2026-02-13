import Foundation

/// Shared timer calculations for task progress tracking.
/// Used by both iOS (FocusLiveView) and macOS (MacFocusView).
enum TimerCalculator {

    /// Calculate progress (0.0 to 1.0+) for a task based on elapsed time.
    static func taskProgress(startTime: Date?, currentTime: Date, durationMinutes: Int) -> Double {
        guard let startTime else { return 0 }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double(durationMinutes * 60)
        return elapsed / estimated
    }

    /// Calculate remaining minutes for a task.
    static func remainingTaskMinutes(startTime: Date?, currentTime: Date, durationMinutes: Int) -> Int {
        guard let startTime else { return durationMinutes }
        let elapsed = currentTime.timeIntervalSince(startTime)
        let estimated = Double(durationMinutes * 60)
        let remaining = estimated - elapsed
        return max(0, Int(remaining / 60))
    }
}
