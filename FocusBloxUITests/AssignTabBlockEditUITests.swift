import XCTest

/// UI Tests for Bug: Assign Tab Focus Block Edit
///
/// Tests verify that tapping a Focus Block Card in the Assign tab opens the edit sheet
final class AssignTabBlockEditUITests: XCTestCase {

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

    private func navigateToAssign() {
        let assignTab = app.buttons["tab-assign"]
        XCTAssertTrue(assignTab.waitForExistence(timeout: 5), "Assign tab should exist")
        assignTab.tap()
        sleep(2)
    }

    // MARK: - Tests

    /// Test: FocusBlockCard should have accessibility identifier
    /// TDD RED: Tests FAIL because identifier doesn't exist yet
    func testFocusBlockCardHasIdentifier() throws {
        navigateToAssign()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AssignTab-Initial"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for focus block card with identifier pattern
        let focusBlockCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlockCard.waitForExistence(timeout: 5),
            "TDD RED: FocusBlockCard MUST have identifier starting with 'focusBlockCard_'"
        )
    }

    /// Test: Tapping FocusBlockCard header should open edit sheet
    func testTapBlockCardOpensEditSheet() throws {
        navigateToAssign()

        // Take initial screenshot
        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "AssignTab-BeforeTap"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        // Find block card with identifier
        let focusBlockCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlockCard.waitForExistence(timeout: 5),
            "TDD RED: Cannot tap block card - identifier 'focusBlockCard_' not found"
        )

        focusBlockCard.tap()
        sleep(1)

        // Take screenshot after tap
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "AssignTab-AfterTap"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // Verify edit sheet opened
        let editSheetTitle = app.staticTexts["Block bearbeiten"]
        let saveButton = app.buttons["Speichern"]
        let deleteButton = app.buttons["Block löschen"]

        let sheetOpened = editSheetTitle.waitForExistence(timeout: 3)
            || saveButton.exists
            || deleteButton.exists

        XCTAssertTrue(sheetOpened, "Edit sheet should open when tapping FocusBlockCard")
    }

    /// Test: Edit sheet should have save button
    func testEditSheetHasSaveButton() throws {
        navigateToAssign()

        let focusBlockCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlockCard.waitForExistence(timeout: 5),
            "TDD RED: Cannot test save button - block card identifier not found"
        )

        focusBlockCard.tap()
        sleep(1)

        let saveButton = app.buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Edit sheet should have 'Speichern' button")
    }

    /// Test: Edit sheet should have delete button
    func testEditSheetHasDeleteButton() throws {
        navigateToAssign()

        let focusBlockCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockCard_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlockCard.waitForExistence(timeout: 5),
            "TDD RED: Cannot test delete button - block card identifier not found"
        )

        focusBlockCard.tap()
        sleep(1)

        let deleteButton = app.buttons["Block löschen"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Edit sheet should have 'Block löschen' button")
    }
}
