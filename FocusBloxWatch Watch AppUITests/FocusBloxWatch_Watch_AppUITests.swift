import XCTest

final class WatchVoiceCaptureUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        try super.tearDownWithError()
    }

    // MARK: - Quick Capture Flow Tests

    /// Test: VoiceInputSheet opens automatically on app launch (no button tap needed).
    @MainActor
    func test_appLaunch_autoDiktatOpens() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "VoiceInputSheet should open automatically on app launch")
    }

    /// Test: OK/Save button no longer exists — auto-save replaces it.
    @MainActor
    func test_voiceInputSheet_noOKButton() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveButton"].exists,
                       "OK button should not exist — auto-save replaces manual confirm")
    }

    /// Test: Cancel button still exists for aborting bad dictation.
    @MainActor
    func test_voiceInputSheet_cancelButtonExists() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cancelButton"].exists,
                      "Cancel button should still exist for aborting")
    }

    /// Test: No confirmation screen exists in the app (ConfirmationView deleted).
    @MainActor
    func test_noConfirmationScreenExists() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 10))
        // ConfirmationView was deleted — "Task gespeichert" text must not exist anywhere
        XCTAssertFalse(app.staticTexts["Task gespeichert"].exists,
                       "Confirmation screen should not exist — haptic feedback only")
    }
}
