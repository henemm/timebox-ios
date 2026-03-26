import XCTest

/// UI Tests for Soft Evening Reset (RW_4.1)
/// Tests verify that the reset runs silently at app start and clears Next-Up state.
/// MUST FAIL because -SimulateEveningReset launch argument handling doesn't exist yet.
final class EveningResetUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Reset Behavior

    /// Verhalten: App-Start mit Reset-Bedingungen leert die Next-Up Section im Morning-Modus
    /// Bricht wenn: EveningResetService.performResetIfNeeded() nicht in onAppear aufgerufen wird
    ///              oder -SimulateEveningReset Seed-Logic fehlt
    func test_appStartResetsNextUp() throws {
        // Launch with: force morning mode + simulate reset conditions
        // -SimulateEveningReset: seeds Next-Up task + sets lastResetDate to past
        // -morningEndHour 24: forces morning mode regardless of time
        app.launchArguments = ["-UITesting", "-SimulateEveningReset", "-morningEndHour", "24"]
        app.launch()

        // Navigate to DayView
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tag-Tab muss existieren")
        tagTab.tap()

        // After reset: Morning mode should show empty state (no Next-Up tasks)
        // The "Guten Morgen" title confirms morning mode
        let morningTitle = app.staticTexts["Guten Morgen"]
        XCTAssertTrue(morningTitle.waitForExistence(timeout: 5), "Morning-Modus sollte aktiv sein")

        // Next Up section header should NOT exist because all Next-Up tasks were reset
        let nextUpHeader = app.staticTexts["Next Up"]
        XCTAssertFalse(nextUpHeader.exists, "Next Up Section sollte nach Reset nicht sichtbar sein")
    }

    /// Verhalten: Reset zeigt kein UI-Element (kein Alert, kein Sheet, kein Modal)
    /// Bricht wenn: Reset-Logik versehentlich einen UI-Dialog triggert
    func test_resetDoesNotShowUI() throws {
        app.launchArguments = ["-UITesting", "-SimulateEveningReset", "-morningEndHour", "24"]
        app.launch()

        // Wait for app to settle
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "App muss starten")

        // No alerts should appear
        XCTAssertFalse(app.alerts.firstMatch.exists, "Kein Alert nach Reset")

        // No sheets should appear (check for common sheet indicators)
        let sheetDismiss = app.buttons["Dismiss"]
        XCTAssertFalse(sheetDismiss.exists, "Kein Sheet nach Reset")
    }
}
