import XCTest

final class PlanningViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    func testTabNavigationExists() throws {
        // Verify tabs exist
        let backlogTab = app.tabBars.buttons["Backlog"]
        let bloeckeTab = app.tabBars.buttons["Blöcke"]

        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist")
        XCTAssertTrue(bloeckeTab.exists, "Blöcke tab should exist")
    }

    func testCanSwitchToBloeckeTab() throws {
        // Tap on Blöcke tab
        let bloeckeTab = app.tabBars.buttons["Blöcke"]
        bloeckeTab.tap()

        // Wait for navigation
        let bloeckeTitle = app.navigationBars["Blöcke"]
        let exists = bloeckeTitle.waitForExistence(timeout: 5)

        XCTAssertTrue(exists, "Blöcke navigation bar should appear after tapping tab")
    }

    func testTimelineShowsHours() throws {
        // Switch to Blöcke tab
        app.tabBars.buttons["Blöcke"].tap()

        // Wait for content to load
        sleep(2)

        // Check for hour labels (e.g., "08:00", "09:00")
        let hour08 = app.staticTexts["08:00"]
        let hour12 = app.staticTexts["12:00"]

        XCTAssertTrue(hour08.exists || hour12.exists, "Timeline should show hour labels")
    }

    func testBloeckeTabScreenshot() throws {
        // Switch to Blöcke tab
        app.tabBars.buttons["Blöcke"].tap()
        sleep(2)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Blöcke Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
