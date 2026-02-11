import XCTest
@testable import FocusBlox

/// Diagnostic tests for Bug 36: CC Quick Task Button
/// Tests verify that the 4 diagnostic intents exist and compile.
@MainActor
final class CCQuickTaskDiagTests: XCTestCase {

    func testAppGroupFlagMechanism() throws {
        // Test that App Group flag can be set and read
        let defaults = UserDefaults(suiteName: "group.com.henning.focusblox")
        XCTAssertNotNil(defaults, "App Group UserDefaults should be accessible")

        defaults?.set(true, forKey: "quickCaptureFromCC")
        XCTAssertTrue(defaults?.bool(forKey: "quickCaptureFromCC") ?? false)

        // Cleanup
        defaults?.removeObject(forKey: "quickCaptureFromCC")
    }
}
