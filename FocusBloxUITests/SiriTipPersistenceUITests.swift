import XCTest

/// UI Tests for SiriTipView persistence and visibility.
/// Verifies SiriTipViews appear in ContentView and SettingsView,
/// and that dismissal state persists across app relaunches.
final class SiriTipPersistenceUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-data"]
    }

    /// Verhalten: Wenn ein SiriTipView dismissed wird, soll er nach App-Neustart NICHT wieder erscheinen
    /// Bricht wenn: @State statt @AppStorage verwendet wird (State geht bei Neustart verloren)
    func test_siriTipDismissal_persistsAcrossRelaunch() throws {
        // First launch
        app.launch()

        // SiriTipView uses Apple's native UI — look for the tip container
        // Apple's SiriTipView renders with a close button (X)
        let siriTip = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "steht an")
        ).firstMatch

        // If SiriTipView is visible, dismiss it
        guard siriTip.waitForExistence(timeout: 5) else {
            // SiriTipView may not render on simulator (no Siri) — skip test
            throw XCTSkip("SiriTipView not available in this environment")
        }

        // Find and tap the dismiss/close button on SiriTipView
        let closeButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Close")
        ).firstMatch
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        }

        // Wait for dismissal animation
        sleep(1)

        // Terminate and relaunch
        app.terminate()
        app.launch()

        // After relaunch, SiriTipView should NOT reappear (if persisted via @AppStorage)
        // With @State: tip reappears (FAIL — this is the TDD RED condition)
        // With @AppStorage: tip stays dismissed (PASS — after fix)
        let siriTipAfterRelaunch = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "steht an")
        ).firstMatch
        XCTAssertFalse(
            siriTipAfterRelaunch.waitForExistence(timeout: 3),
            "SiriTipView should NOT reappear after dismissal — state must be persisted with @AppStorage"
        )
    }
}
