import XCTest

/// Temporary test to capture BEFORE screenshots for Phase 2 implementation
final class BeforeScreenshotTest: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Capture BEFORE screenshot of BlockPlanningView (Blöcke Tab)
    func testCaptureBeforeBlockPlanningView() throws {
        // Wait for app to launch (may show error state due to EventKit permissions)
        sleep(5)

        // Try to navigate to Blöcke tab if it exists
        let bloeckeTab = app.tabBars.buttons["Blöcke"]
        if bloeckeTab.waitForExistence(timeout: 3) {
            bloeckeTab.tap()
            sleep(2)
        }

        // Capture screenshot regardless of state (error state is valid for BEFORE)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "BEFORE-BlockPlanningView-Phase2"
        attachment.lifetime = .keepAlways
        add(attachment)

        print("📸 BEFORE screenshot captured: BlockPlanningView (current state with EventKit issues)")
    }

    /// Capture BEFORE screenshot of first tab (Backlog)
    func testCaptureBeforeBacklogView() throws {
        // Wait for app to launch
        sleep(5)

        // Try to navigate to first tab if tabs exist
        let tabs = app.tabBars.buttons
        if tabs.count > 0 {
            tabs.element(boundBy: 0).tap()
            sleep(2)
        }

        // Capture screenshot of whatever is visible
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "BEFORE-BacklogView-Phase2"
        attachment.lifetime = .keepAlways
        add(attachment)

        print("📸 BEFORE screenshot captured: BacklogView (current state)")
    }
}
