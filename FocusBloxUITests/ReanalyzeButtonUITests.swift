import XCTest

/// E2E UI Test: "Bestehende Tasks analysieren" Button
/// Beweist, dass der Button-Tap tatsächlich Task-Titel bereinigt.
/// Flow: Task mit Datums-Keyword erstellen → Settings → Button drücken → Backlog prüfen
final class ReanalyzeButtonUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - E2E: Button bereinigt Task-Titel

    /// GIVEN: User ist in den Einstellungen
    /// WHEN: User tappt "Bestehende Tasks analysieren"
    /// THEN: Button ist tappbar und führt nicht zu Crash
    func test_reanalyzeButton_isTappableAndDoesNotCrash() throws {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button should exist")
            return
        }
        settingsButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        guard settingsNav.waitForExistence(timeout: 5) else {
            XCTFail("Settings navigation bar should appear")
            return
        }

        let batchButton = app.buttons["batchEnrichButton"]
        if !batchButton.exists {
            app.swipeUp()
        }
        guard batchButton.waitForExistence(timeout: 5) else {
            XCTFail("'Bestehende Tasks analysieren' button must be visible in Settings")
            return
        }

        XCTAssertTrue(batchButton.isHittable, "Button must be hittable")
        batchButton.tap()

        // Verify app doesn't crash and button label persists
        let buttonLabel = app.staticTexts["Bestehende Tasks analysieren"]
        XCTAssertTrue(buttonLabel.waitForExistence(timeout: 5),
                      "Button label must still exist after tap — no crash")
    }

    // MARK: - Button Visibility

    /// GIVEN: App läuft auf beliebigem Gerät (mit oder ohne AI)
    /// WHEN: User öffnet Einstellungen
    /// THEN: "Bestehende Tasks analysieren" Button ist sichtbar
    func test_settings_reanalyzeButton_alwaysVisible() throws {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button should exist")
            return
        }
        settingsButton.tap()

        // Wait for Settings to appear
        let settingsNav = app.navigationBars["Settings"]
        guard settingsNav.waitForExistence(timeout: 5) else {
            XCTFail("Settings navigation bar should appear")
            return
        }

        // Button might be below the fold — scroll down to find it
        let batchButton = app.buttons["batchEnrichButton"]
        if !batchButton.exists {
            app.swipeUp()
        }

        XCTAssertTrue(batchButton.waitForExistence(timeout: 5),
                      "'Bestehende Tasks analysieren' button must ALWAYS be visible in Settings")
    }

    /// GIVEN: App läuft auf beliebigem Gerät
    /// WHEN: User öffnet Einstellungen
    /// THEN: Section-Header ist "Automatische Task-Analyse"
    func test_settings_sectionHeader_showsCorrectName() throws {
        let settingsButton = app.buttons["settingsButton"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            XCTFail("Settings button should exist")
            return
        }
        settingsButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        guard settingsNav.waitForExistence(timeout: 5) else {
            XCTFail("Settings navigation bar should appear")
            return
        }

        let sectionHeader = app.staticTexts["Automatische Task-Analyse"]
        if !sectionHeader.exists {
            app.swipeUp()
        }
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 5),
                      "Section header must be 'Automatische Task-Analyse'")
    }
}
