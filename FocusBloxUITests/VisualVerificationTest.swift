import XCTest

/// Temporary test for visual verification of BacklogRow Glass Card design
final class VisualVerificationTest: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Navigate to List view and capture screenshot for visual verification
    func testBacklogListViewScreenshot() throws {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))
        backlogTab.tap()
        sleep(1)

        // Switch to List view
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(viewModeSwitcher.waitForExistence(timeout: 5), "View mode switcher should exist")
        viewModeSwitcher.tap()
        sleep(1)

        // Screenshot: Menu open
        let menuScreenshot = XCTAttachment(screenshot: app.screenshot())
        menuScreenshot.name = "1_ViewModeMenu_Open"
        menuScreenshot.lifetime = .keepAlways
        add(menuScreenshot)

        // Select "Liste"
        let listeOption = app.buttons["Liste"]
        if listeOption.waitForExistence(timeout: 3) {
            listeOption.tap()
            sleep(2)
        } else {
            // Try static text
            let listeText = app.staticTexts["Liste"]
            if listeText.waitForExistence(timeout: 2) {
                listeText.tap()
                sleep(2)
            }
        }

        // Screenshot: List view with BacklogRow Glass Cards
        let listScreenshot = XCTAttachment(screenshot: app.screenshot())
        listScreenshot.name = "2_BacklogRow_ListView_GlassCard"
        listScreenshot.lifetime = .keepAlways
        add(listScreenshot)

        // Verify elements exist
        let importanceButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceButton_'")
        ).firstMatch
        XCTAssertTrue(importanceButton.waitForExistence(timeout: 5), "Importance button should exist")

        let actionsMenu = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'actionsMenu_'")
        ).firstMatch
        XCTAssertTrue(actionsMenu.exists, "Actions menu should exist")

        let categoryBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'categoryBadge_'")
        ).firstMatch
        XCTAssertTrue(categoryBadge.exists, "Category badge should exist")

        // Final screenshot
        let finalScreenshot = XCTAttachment(screenshot: app.screenshot())
        finalScreenshot.name = "3_BacklogRow_Final_Verification"
        finalScreenshot.lifetime = .keepAlways
        add(finalScreenshot)

        // Save screenshot to file system for verification
        let screenshot = app.screenshot()
        let pngData = screenshot.pngRepresentation
        let docsPath = "/Users/hem/Documents/opt/my-daily-sprints/docs/artifacts/backlog-row-glass-card"
        let filePath = "\(docsPath)/visual-verification-list-view.png"
        try? pngData.write(to: URL(fileURLWithPath: filePath))
    }
}
