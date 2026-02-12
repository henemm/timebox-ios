import XCTest
@testable import FocusBlox

/// Tests for Bug 36: CC Quick Task Button
@MainActor
final class CCQuickTaskTests: XCTestCase {

    func testQuickAddLaunchIntentExists() throws {
        // Verify the intent type compiles and can be instantiated
        let intent = QuickAddLaunchIntent()
        XCTAssertNotNil(intent)
    }

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
