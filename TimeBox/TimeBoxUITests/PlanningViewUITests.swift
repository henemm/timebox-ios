import XCTest

final class PlanningViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTabNavigationExists() throws {
        // Verify both tabs exist
        let backlogTab = app.tabBars.buttons["Backlog"]
        let planenTab = app.tabBars.buttons["Planen"]

        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist")
        XCTAssertTrue(planenTab.exists, "Planen tab should exist")
    }

    func testCanSwitchToPlanenTab() throws {
        // Tap on Planen tab
        let planenTab = app.tabBars.buttons["Planen"]
        planenTab.tap()

        // Wait for navigation
        let planenTitle = app.navigationBars["Planen"]
        let exists = planenTitle.waitForExistence(timeout: 5)

        XCTAssertTrue(exists, "Planen navigation bar should appear after tapping tab")
    }

    func testTimelineShowsHours() throws {
        // Switch to Planen tab
        app.tabBars.buttons["Planen"].tap()

        // Wait for content to load
        sleep(2)

        // Check for hour labels (e.g., "08:00", "09:00")
        let hour08 = app.staticTexts["08:00"]
        let hour12 = app.staticTexts["12:00"]

        XCTAssertTrue(hour08.exists || hour12.exists, "Timeline should show hour labels")
    }

    func testPlanenTabScreenshot() throws {
        // Switch to Planen tab
        app.tabBars.buttons["Planen"].tap()
        sleep(2)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Planen Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
