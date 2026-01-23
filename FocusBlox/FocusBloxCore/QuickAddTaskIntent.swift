import AppIntents
import os

private let logger = Logger(subsystem: "com.henning.timebox", category: "Intent")

// MVP: Simpelster Intent - nur Logging
public struct QuickAddTaskIntent: AppIntent {
    public static var title: LocalizedStringResource = "Quick Task"

    public init() {}

    public func perform() async throws -> some IntentResult {
        // FAULT level durchbricht alle Filter
        logger.fault("🔥🔥🔥 INTENT PERFORM CALLED 🔥🔥🔥")
        return .result()
    }
}
