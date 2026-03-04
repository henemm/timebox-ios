import XCTest

/// UI Tests for Smart Task Interpretation — verifies that Quick Capture
/// tasks with idiomatic phrases get their titles cleaned by TaskTitleEngine.
final class SmartTaskInterpretationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-QuickCaptureTest"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Verhalten: Task mit "Erinnere mich..." Floskel wird via Quick Capture erstellt,
    /// TaskTitleEngine bereinigt den Titel zu reiner Aktion ohne Floskel.
    /// Bricht wenn: TaskTitleEngine Prompt die Floskel-Erkennung nicht implementiert hat.
    /// EXPECTED TO FAIL (RED): Current prompt does not strip "Erinnere mich" phrases.
    func testQuickCaptureStripsReminderPhrase() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        // Enter a task with idiomatic reminder phrase
        textField.tap()
        textField.typeText("Erinnere mich heute daran Herrn Mueller anzurufen")

        // Save task
        let saveButton = app.buttons["quickCaptureSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2), "Save button should exist")
        saveButton.tap()

        // Wait for success and auto-dismiss
        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 3),
                      "Success icon should appear after save")

        // Wait for auto-dismiss back to main view
        // After QuickCapture dismisses, we should see the backlog
        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 5),
                      "Should return to main view after save")

        // The task should appear with CLEANED title (no "Erinnere mich" phrase)
        // TaskTitleEngine runs async — wait a moment for processing
        sleep(3)

        // Check that the cleaned title is visible (without the reminder phrase)
        // The AI should have stripped "Erinnere mich heute daran" and kept "Herrn Mueller anrufen"
        let cleanedTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Mueller'")).firstMatch
        XCTAssertTrue(cleanedTitle.waitForExistence(timeout: 5),
                      "Task with 'Mueller' should exist in backlog")

        // The reminder phrase should NOT be in the title anymore
        let reminderPhrase = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Erinnere mich'")).firstMatch
        XCTAssertFalse(reminderPhrase.exists,
                       "Title should NOT contain 'Erinnere mich' — phrase should be stripped by TaskTitleEngine")
    }

    /// Verhalten: Task mit "Ich muss noch..." Floskel wird bereinigt.
    /// Bricht wenn: TaskTitleEngine Prompt "Ich muss noch" nicht als Floskel erkennt.
    /// EXPECTED TO FAIL (RED): Current prompt does not strip "Ich muss noch" phrases.
    func testQuickCaptureStripsIchMussNochPhrase() throws {
        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "Quick capture text field should exist")

        textField.tap()
        textField.typeText("Ich muss morgen noch Steuern machen")

        let saveButton = app.buttons["quickCaptureSaveButton"]
        saveButton.tap()

        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 3),
                      "Success icon should appear")

        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 5),
                      "Should return to main view")

        sleep(3)

        // Cleaned title should contain "Steuern machen" without "Ich muss noch"
        let cleanedTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Steuern'")).firstMatch
        XCTAssertTrue(cleanedTitle.waitForExistence(timeout: 5),
                      "Task with 'Steuern' should exist")

        let floskel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ich muss'")).firstMatch
        XCTAssertFalse(floskel.exists,
                       "Title should NOT contain 'Ich muss' — phrase should be stripped")
    }
}
