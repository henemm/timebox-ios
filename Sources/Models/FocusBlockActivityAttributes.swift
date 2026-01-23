import ActivityKit
import Foundation

/// ActivityKit Attributes for Focus Block Live Activities
/// Used on Lock Screen and Dynamic Island
struct FocusBlockActivityAttributes: ActivityAttributes {

    // MARK: - Static Data (doesn't change during activity)

    /// Title of the Focus Block
    let blockTitle: String

    /// When the block started
    let startDate: Date

    /// When the block ends
    let endDate: Date

    /// Total number of tasks in the block
    let totalTaskCount: Int

    // MARK: - Dynamic Data (can change during activity)

    struct ContentState: Codable, Hashable {
        /// Currently active task title (nil if no task assigned)
        let currentTaskTitle: String?

        /// Number of completed tasks
        let completedCount: Int
    }
}
