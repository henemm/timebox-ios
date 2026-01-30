import XCTest

/// UI Tests for Feature: Edit Focus Blocks
///
/// Tests verify that tapping a Focus Block opens the edit sheet
final class EditFocusBlockUITests: XCTestCase {

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

    // MARK: - Helper

    private func navigateToBlox() {
        let bloxTab = app.buttons["tab-blox"]
        XCTAssertTrue(bloxTab.waitForExistence(timeout: 5), "Blox tab should exist")
        bloxTab.tap()
        sleep(2)
    }

    // MARK: - Tests

    /// Test: ExistingBlockRow should have accessibility identifier
    /// TDD RED: Tests FAIL because identifier doesn't exist yet
    func testExistingBlockHasIdentifier() throws {
        navigateToBlox()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "EditBlock-BloxTab-Initial"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // First verify the Today's Blox section exists (mock data should have blocks)
        let todaysBloxHeader = app.staticTexts["Today's Blox"]
        XCTAssertTrue(todaysBloxHeader.waitForExistence(timeout: 5), "Today's Blox section should exist with mock data")

        // Look for existing block with identifier pattern (must FAIL without implementation)
        let existingBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'existingBlock_'")
        ).firstMatch

        XCTAssertTrue(
            existingBlock.waitForExistence(timeout: 5),
            "TDD RED: Focus Block row MUST have identifier starting with 'existingBlock_'"
        )
    }

    /// Test: Tapping Focus Block should open edit sheet
    func testTapBlockOpensEditSheet() throws {
        navigateToBlox()

        // Take initial screenshot
        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "EditBlock-BeforeTap"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        // Find block with identifier (must FAIL without implementation)
        let existingBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'existingBlock_'")
        ).firstMatch

        XCTAssertTrue(
            existingBlock.waitForExistence(timeout: 5),
            "TDD RED: Cannot tap block - identifier 'existingBlock_' not found"
        )

        existingBlock.tap()
        sleep(1)

        // Take screenshot after tap
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "EditBlock-AfterTap"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        verifyEditSheet()
    }

    private func verifyEditSheet() {
        // Check if edit sheet opened - look for DatePicker or "Block bearbeiten" title
        let editSheetTitle = app.staticTexts["Block bearbeiten"]
        let startPicker = app.datePickers.firstMatch
        let saveButton = app.buttons["Speichern"]
        let deleteButton = app.buttons["Löschen"]

        let sheetOpened = editSheetTitle.waitForExistence(timeout: 3)
            || startPicker.exists
            || saveButton.exists
            || deleteButton.exists

        XCTAssertTrue(sheetOpened, "Edit sheet should open when tapping Focus Block")
    }

    /// Test: Edit sheet should have save button
    func testEditSheetHasSaveButton() throws {
        navigateToBlox()

        // Find and tap block (must FAIL without implementation)
        let anyBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'existingBlock_'")
        ).firstMatch

        XCTAssertTrue(
            anyBlock.waitForExistence(timeout: 5),
            "TDD RED: Cannot test save button - block identifier not found"
        )

        anyBlock.tap()
        sleep(1)

        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Edit sheet should have 'Speichern' button")
    }

    /// Test: Edit sheet should have delete button
    func testEditSheetHasDeleteButton() throws {
        navigateToBlox()

        // Find and tap block (must FAIL without implementation)
        let anyBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'existingBlock_'")
        ).firstMatch

        XCTAssertTrue(
            anyBlock.waitForExistence(timeout: 5),
            "TDD RED: Cannot test delete button - block identifier not found"
        )

        anyBlock.tap()
        sleep(1)

        // The delete button has label "Block löschen"
        let deleteButton = app.buttons["Block löschen"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Edit sheet should have 'Block löschen' button")
    }
}
