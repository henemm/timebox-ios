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

    // MARK: - Complication Deep-Link Flow Tests

    /// Test: After dismissing auto-open sheet, tapping addTaskButton re-opens VoiceInputSheet.
    /// This verifies the same path the complication deep-link takes on warm launch:
    /// Sheet was dismissed → deep-link/button triggers showingInput = true → Sheet reappears.
    /// Bricht wenn: ContentView.swift — Button action `showingInput = true` entfernt oder addTaskButton Identifier fehlt.
    @MainActor
    func test_complicationFlow_reopenAfterCancel() throws {
        // Sheet auto-opens on launch
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "VoiceInputSheet should auto-open on launch")

        // Dismiss the sheet via cancel (firstMatch needed — watchOS wraps button in multiple elements)
        let cancelButton = app.buttons["cancelButton"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.tap()

        // Verify sheet is dismissed (addTaskButton becomes visible)
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                      "addTaskButton should be visible after dismissing sheet")

        // Re-open via button (simulates complication deep-link on warm launch)
        addButton.tap()

        // VoiceInputSheet should reappear
        let textFieldAgain = app.textFields["taskTitleField"]
        XCTAssertTrue(textFieldAgain.waitForExistence(timeout: 5),
                      "VoiceInputSheet should reopen — same as complication deep-link on warm launch")
    }

    /// Test: VoiceInputSheet has all expected elements for quick capture after complication tap.
    /// Verifies the complete UI that a user sees after tapping the watchface complication.
    /// Bricht wenn: VoiceInputSheet.swift — TextField/cancelButton Identifier oder "Was möchtest du tun?" Text entfernt.
    @MainActor
    func test_complicationFlow_voiceInputSheetComplete() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))

        // Title text should be visible
        XCTAssertTrue(app.staticTexts["Was möchtest du tun?"].exists,
                      "Prompt text should be visible")

        // Cancel button should exist
        XCTAssertTrue(app.buttons["cancelButton"].exists,
                      "Cancel button must exist for aborting bad dictation")

        // No save button (auto-save only)
        XCTAssertFalse(app.buttons["saveButton"].exists,
                       "Save button should not exist — auto-save handles it")
    }

}
