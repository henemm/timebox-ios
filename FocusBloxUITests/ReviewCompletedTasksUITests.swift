import XCTest

/// UI Tests for Review: All completed tasks visible regardless of FocusBlock.
/// EXPECTED TO FAIL: "Ohne Sprint erledigt" section does not exist yet.
final class ReviewCompletedTasksUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    /// "Ohne Sprint erledigt" section should be visible when tasks are completed outside blocks
    /// EXPECTED TO FAIL: Section does not exist yet
    func testOutsideSprintSectionVisible() throws {
        // Navigate to Review tab
        let reviewTab = app.tabBars.buttons["Rückblick"]
        XCTAssertTrue(reviewTab.waitForExistence(timeout: 5), "Review tab should exist")
        reviewTab.tap()

        // Look for the new section header
        let sectionHeader = app.staticTexts["Ohne Sprint erledigt"]
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 5), "Outside sprint section should be visible")
    }
}
