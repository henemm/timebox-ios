import XCTest

/// CTC-4: Clipboard → Task Flow
/// Tests that QuickCaptureView shows a paste button when clipboard has text content
final class ClipboardTaskFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-QuickCaptureTest"]
    }

    // MARK: - Clipboard Button Visibility

    /// GIVEN: QuickCaptureView is displayed AND clipboard contains text
    /// WHEN: Text field is empty
    /// THEN: A clipboard paste button should be visible
    /// Bricht wenn: QuickCaptureView hat keinen Button mit accessibilityIdentifier "qc_clipboardButton"
    func testClipboardButtonAppearsWhenClipboardHasText() throws {
        app.launchArguments.append("-MockClipboard")
        app.launchArguments.append("Buy groceries from email")
        app.launch()

        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "QuickCaptureView should appear")

        let clipboardButton = app.buttons["qc_clipboardButton"]
        XCTAssertTrue(clipboardButton.waitForExistence(timeout: 3),
                      "Clipboard paste button should be visible when clipboard has text")
    }

    /// GIVEN: QuickCaptureView is displayed AND clipboard is empty
    /// WHEN: Text field is empty
    /// THEN: No clipboard paste button should be visible
    /// Bricht wenn: Button wird angezeigt obwohl kein MockClipboard-Argument gesetzt ist
    func testClipboardButtonHiddenWhenClipboardEmpty() throws {
        // No -MockClipboard argument → simulates empty clipboard
        app.launch()

        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "QuickCaptureView should appear")

        let clipboardButton = app.buttons["qc_clipboardButton"]
        XCTAssertFalse(clipboardButton.waitForExistence(timeout: 2),
                       "Clipboard button should NOT appear when clipboard is empty")
    }

    // MARK: - Paste Action

    /// GIVEN: QuickCaptureView with clipboard button visible
    /// WHEN: User taps the clipboard button
    /// THEN: Text field should be filled with clipboard content
    /// Bricht wenn: Tap auf clipboardButton fuellt das Textfeld nicht mit dem Clipboard-Text
    func testTappingClipboardButtonFillsTextField() throws {
        let clipboardText = "Artikel aus Safari lesen"
        app.launchArguments.append("-MockClipboard")
        app.launchArguments.append(clipboardText)
        app.launch()

        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))

        let clipboardButton = app.buttons["qc_clipboardButton"]
        XCTAssertTrue(clipboardButton.waitForExistence(timeout: 3))
        clipboardButton.tap()

        // Text field should now contain the clipboard text
        let fieldValue = textField.value as? String ?? ""
        XCTAssertEqual(fieldValue, clipboardText,
                       "Text field should contain clipboard text after tapping paste button")
    }

    /// GIVEN: QuickCaptureView with clipboard text pasted into text field
    /// WHEN: User taps Save
    /// THEN: Task should be created successfully (success icon appears)
    /// Bricht wenn: Save-Flow nach Clipboard-Paste nicht funktioniert
    func testSaveTaskFromClipboardContent() throws {
        app.launchArguments.append("-MockClipboard")
        app.launchArguments.append("Meeting notes reviewen")
        app.launch()

        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))

        // Paste from clipboard
        let clipboardButton = app.buttons["qc_clipboardButton"]
        XCTAssertTrue(clipboardButton.waitForExistence(timeout: 3))
        clipboardButton.tap()

        // Wait for save button to become enabled after clipboard paste
        let saveButton = app.buttons["quickCaptureSaveButton"]
        let enabled = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabled, object: saveButton)
        wait(for: [expectation], timeout: 5)
        saveButton.tap()

        // Success feedback should appear
        let successIcon = app.images["quickCaptureSuccessIcon"]
        XCTAssertTrue(successIcon.waitForExistence(timeout: 10),
                      "Success icon should appear after saving clipboard task")
    }

    // MARK: - Button Disappears After Text Entry

    /// GIVEN: QuickCaptureView with clipboard button visible
    /// WHEN: User types text manually into the text field
    /// THEN: Clipboard button should disappear (not needed anymore)
    /// Bricht wenn: Button bleibt sichtbar nachdem User Text eingegeben hat
    func testClipboardButtonDisappearsAfterTyping() throws {
        app.launchArguments.append("-MockClipboard")
        app.launchArguments.append("Some clipboard content")
        app.launch()

        let textField = app.textFields["quickCaptureTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))

        let clipboardButton = app.buttons["qc_clipboardButton"]
        XCTAssertTrue(clipboardButton.waitForExistence(timeout: 3),
                      "Clipboard button should initially be visible")

        // User types text manually
        textField.tap()
        textField.typeText("My own task")

        // Clipboard button should no longer be visible
        XCTAssertFalse(clipboardButton.waitForExistence(timeout: 2),
                       "Clipboard button should disappear after user types text")
    }
}
