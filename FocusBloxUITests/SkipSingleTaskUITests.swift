import XCTest

/// Simplified test for Bug 15: Skip single task should end block
/// This creates a block with just 1 task using -SingleTaskBlock launch arg
final class SkipSingleTaskUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-SingleTaskBlock"]
        app.launch()
    }

    /// Test: Skip the only task in a block → block should end
    func testSkipOnlyTaskEndsBlock() throws {
        // Navigate to Focus tab
        let focusTab = app.buttons["tab-focus"]
        guard focusTab.waitForExistence(timeout: 5) else {
            throw XCTSkip("Focus tab not found")
        }
        focusTab.tap()
        sleep(2)

        // Find skip button
        let skipButton = app.buttons["Überspringen"]
        guard skipButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No active block with skip button")
        }

        // Screenshot before skip
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "SingleTask-BeforeSkip"
        before.lifetime = .keepAlways
        add(before)

        // Skip the only task
        skipButton.tap()
        sleep(2)

        // Screenshot after skip
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "SingleTask-AfterSkip"
        after.lifetime = .keepAlways
        add(after)

        // Assert: "Alle Tasks erledigt!" should appear
        let allDone = app.staticTexts["Alle Tasks erledigt!"]
        XCTAssertTrue(
            allDone.waitForExistence(timeout: 5),
            "After skipping the only task, 'Alle Tasks erledigt!' should appear"
        )
    }
}
