import Foundation
import Observation

/// Shared state for Quick Capture Interactive Snippet.
/// Registered as AppDependency so all sub-intents can read/write the same state.
@MainActor @Observable
final class QuickCaptureState: Sendable {
    var importance: Int? = nil       // nil → 1 → 2 → 3 → nil
    var urgency: String? = nil       // nil → "not_urgent" → "urgent" → nil
    var taskType: String = "maintenance"
    var estimatedDuration: Int? = nil // nil → 15 → 25 → 45 → 60 → nil

    func reset() {
        importance = nil
        urgency = nil
        taskType = "maintenance"
        estimatedDuration = nil
    }
}
