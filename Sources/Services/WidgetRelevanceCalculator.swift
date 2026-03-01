import Foundation

/// Calculates widget relevance scores for Smart Stack placement (ITB-G3).
/// Higher scores make the widget appear more prominently.
enum WidgetRelevanceCalculator {

    /// Calculates the relevance score based on current app state.
    /// - Parameters:
    ///   - hasActiveFocusBlock: Whether a Focus Block is currently running
    ///   - urgentTaskCount: Number of tasks with urgency == "urgent"
    ///   - totalTaskCount: Total number of incomplete tasks
    /// - Returns: Score from 10.0 (idle) to 100.0 (active focus block)
    static func calculateScore(
        hasActiveFocusBlock: Bool,
        urgentTaskCount: Int,
        totalTaskCount: Int
    ) -> Double {
        if hasActiveFocusBlock {
            return 100.0
        } else if urgentTaskCount > 0 {
            return 80.0
        } else if totalTaskCount > 0 {
            return 40.0
        } else {
            return 10.0
        }
    }
}
