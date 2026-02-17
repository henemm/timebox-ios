import XCTest

final class WatchVoiceCaptureUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - ContentView Smoke Tests

    /// Test: "Task hinzufuegen" button should exist on main screen.
    @MainActor
    func test_addTaskButton_exists() throws {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                      "Add Task button should exist on Watch main screen")
    }

    /// Test: Tapping button should open VoiceInputSheet.
    @MainActor
    func test_addTaskButton_opensInputSheet() throws {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let textField = app.textFields["taskTitleField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 3),
                      "VoiceInputSheet should appear with text field")
    }

    // Note: Save/Confirmation flow not UI-tested — watchOS Simulator
    // sheet-to-sheet transitions are unreliable. Business logic (task
    // creation, schema parity, TBD defaults) covered by unit tests.
}
