import XCTest

/// UI Tests for RW_3.3: Follow-up Logic (Abort Flow)
/// Tests the abort button in FocusLiveView and follow-up creation in SprintReviewSheet.
final class AbortFollowUpUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func navigateToFocusTab() {
        let focusTab = app.tabBars.buttons["Focus"]
        if focusTab.waitForExistence(timeout: 5) {
            focusTab.tap()
        }
    }

    // MARK: - Abort Button

    /// EXPECTED TO FAIL: abortBlockButton doesn't exist yet.
    /// Verhalten: Waehrend aktivem Focus Block ist ein "Abbrechen"-Button sichtbar.
    /// Bricht wenn: FocusLiveView — abortBlockButton entfernt oder umbenannt.
    func test_abortBlock_buttonExists() throws {
        navigateToFocusTab()

        // Wait for active Focus Block (mock: active block present)
        let abortButton = app.buttons["abortBlockButton"]
        XCTAssertTrue(
            abortButton.waitForExistence(timeout: 5),
            "Abort button should be visible during active Focus Block"
        )
    }

    // MARK: - Follow-up UI in Sprint Review

    /// EXPECTED TO FAIL: Follow-up UI doesn't exist yet.
    /// Verhalten: Nach Abbruch zeigt Sprint Review Freitext-Feld und Follow-up-Button pro unerledigtem Task.
    /// Bricht wenn: SprintReviewSheet — isAborted-Logik oder Follow-up-UI entfernt.
    func test_abortBlock_showsFollowUpUI() throws {
        navigateToFocusTab()

        // Tap abort button (mock: active Focus Block present)
        let abortButton = app.buttons["abortBlockButton"]
        guard abortButton.waitForExistence(timeout: 5) else {
            XCTFail("Abort button should exist during active Focus Block")
            return
        }
        abortButton.tap()

        // Sprint Review should open with follow-up UI
        let reviewNav = app.navigationBars["Sprint Review"]
        guard reviewNav.waitForExistence(timeout: 5) else {
            XCTFail("Sprint Review should open after abort")
            return
        }

        // Progress note text field should be visible
        let progressNote = app.textFields.matching(
            NSPredicate(format: "identifier BEGINSWITH 'progressNote_'")
        ).firstMatch
        XCTAssertTrue(
            progressNote.waitForExistence(timeout: 3),
            "Progress note text field should be visible for incomplete tasks"
        )

        // Follow-up button should be visible
        let followUpButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'createFollowUpButton_'")
        ).firstMatch
        XCTAssertTrue(
            followUpButton.waitForExistence(timeout: 3),
            "Follow-up creation button should be visible for incomplete tasks"
        )
    }

    // MARK: - Follow-up Confirmation

    /// EXPECTED TO FAIL: Follow-up creation doesn't exist yet.
    /// Verhalten: Nach Tap auf "Follow-up erstellen" erscheint Bestaetigungs-Label.
    /// Bricht wenn: SprintReviewSheet — followUpCreated-Set oder Confirmation-Label entfernt.
    func test_abortBlock_createFollowUp_showsConfirmation() throws {
        navigateToFocusTab()

        // Abort block (mock: active Focus Block present)
        let abortButton = app.buttons["abortBlockButton"]
        guard abortButton.waitForExistence(timeout: 5) else {
            XCTFail("Abort button should exist")
            return
        }
        abortButton.tap()

        // Wait for Sprint Review
        let reviewNav = app.navigationBars["Sprint Review"]
        guard reviewNav.waitForExistence(timeout: 5) else {
            XCTFail("Sprint Review should open after abort")
            return
        }

        // Tap follow-up button
        let followUpButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'createFollowUpButton_'")
        ).firstMatch
        guard followUpButton.waitForExistence(timeout: 3) else {
            XCTFail("Follow-up button should exist")
            return
        }
        followUpButton.tap()

        // Confirmation label should appear
        let confirmation = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'followUpConfirmation_'")
        ).firstMatch
        XCTAssertTrue(
            confirmation.waitForExistence(timeout: 3),
            "Follow-up confirmation label should appear after creating follow-up"
        )
    }
}
