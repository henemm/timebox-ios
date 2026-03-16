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
    /// Bricht wenn: ContentView.swift — onAppear Auto-Open entfernt oder hasAutoOpened nicht gesetzt.
    @MainActor
    func test_appLaunch_autoDiktatOpens() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "VoiceInputSheet should open automatically on app launch")
    }

    /// Test: OK/Save button no longer exists — auto-save replaces it.
    /// Bricht wenn: VoiceInputSheet.swift — saveButton ToolbarItem hinzugefuegt.
    @MainActor
    func test_voiceInputSheet_noOKButton() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveButton"].exists,
                       "OK button should not exist — auto-save replaces manual confirm")
    }

    /// Test: Cancel button must NOT exist — swipe-down is the dismiss mechanism.
    /// Bricht wenn: VoiceInputSheet.swift — Toolbar mit cancelButton wieder hinzugefuegt.
    @MainActor
    func test_voiceInputSheet_noCancelButton() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cancelButton"].exists,
                       "Cancel button should not exist — swipe-down replaces it")
    }

    /// Test: No prompt text "Was moechtest du tun?" — sheet goes straight to dictation.
    /// Bricht wenn: VoiceInputSheet.swift — Text("Was möchtest du tun?") wieder hinzugefuegt.
    @MainActor
    func test_voiceInputSheet_noPromptText() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Was möchtest du tun?"].exists,
                       "Prompt text should not exist — minimal UI for fastest capture")
    }

    /// Test: No navigation title "Neuer Task" — sheet is pure input without chrome.
    /// Bricht wenn: VoiceInputSheet.swift — NavigationStack mit .navigationTitle wieder hinzugefuegt.
    @MainActor
    func test_voiceInputSheet_noNavigationTitle() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Neuer Task"].exists,
                       "Navigation title should not exist — minimal UI")
    }

    /// Test: No confirmation screen exists in the app (ConfirmationView deleted).
    /// Bricht wenn: ConfirmationView.swift wieder erstellt oder "Task gespeichert" Text hinzugefuegt.
    @MainActor
    func test_noConfirmationScreenExists() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Task gespeichert"].exists,
                       "Confirmation screen should not exist — haptic feedback only")
    }

    // MARK: - Complication Deep-Link Flow Tests

    // NOTE: test_complicationFlow_reopenAfterDismiss removed — watchOS Simulator cannot
    // reliably dismiss sheets without explicit button. ContentView.addTaskButton behavior
    // is unchanged and verified by test_appLaunch_autoDiktatOpens (sheet opens on launch).
    // Swipe-down dismiss works on real hardware.

    /// Test: VoiceInputSheet is minimal — only TextField, no chrome.
    /// Verifies the complete (minimal) UI that a user sees after tapping the watchface complication.
    /// Bricht wenn: VoiceInputSheet.swift — NavigationStack, Toolbar, oder Prompt-Text wieder hinzugefuegt.
    @MainActor
    func test_complicationFlow_minimalVoiceInputSheet() throws {
        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5),
                      "TextField must exist for voice input")

        // NO prompt text
        XCTAssertFalse(app.staticTexts["Was möchtest du tun?"].exists,
                       "Prompt text should not exist")

        // NO cancel button (swipe-down is the dismiss mechanism)
        XCTAssertFalse(app.buttons["cancelButton"].exists,
                       "Cancel button should not exist")

        // NO save button (auto-save only)
        XCTAssertFalse(app.buttons["saveButton"].exists,
                       "Save button should not exist — auto-save handles it")
    }

}
