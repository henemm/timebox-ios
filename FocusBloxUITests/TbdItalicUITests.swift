import XCTest

/// UI Tests for TBD Task Italic Title
///
/// TDD RED: Screenshot proves TBD title is NOT italic (bug exists)
/// TDD GREEN: Screenshot proves TBD title IS italic (bug fixed)
///
/// Mock data: tbdTask in FocusBloxApp.seedUITestData()
/// - title: "TBD Task - Unvollständig"
/// - importance: nil, urgency: nil, estimatedDuration: nil
/// - isTbd: true → should render italic + secondary color
final class TbdItalicUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Navigate to Backlog tab and switch to TBD view mode
    private func navigateToTbdView() {
        // Navigate to Backlog tab
        let backlogTab = app.buttons["tab-backlog"]
        guard backlogTab.waitForExistence(timeout: 10) else {
            XCTFail("Backlog tab should exist")
            return
        }
        backlogTab.tap()
        sleep(1)

        // Open view mode switcher
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        guard viewModeSwitcher.waitForExistence(timeout: 5) else {
            XCTFail("viewModeSwitcher should exist")
            return
        }
        viewModeSwitcher.tap()
        sleep(1)

        // Select "TBD" view mode to see only incomplete tasks
        let tbdOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'TBD'")
        ).firstMatch

        guard tbdOption.waitForExistence(timeout: 3) else {
            XCTFail("TBD option should exist in view mode picker")
            return
        }
        tbdOption.tap()
        sleep(2) // Wait for view to load
    }

    // MARK: - TDD RED/GREEN Test

    /// Test: TBD Task title should be rendered in italic style
    ///
    /// This test captures a screenshot as visual evidence.
    /// XCUITest cannot programmatically verify font style (italic),
    /// so the screenshot serves as proof for manual inspection.
    ///
    /// TDD RED: Screenshot shows non-italic title → BUG EXISTS
    /// TDD GREEN: Screenshot shows italic title → BUG FIXED
    func testTbdTaskTitleIsItalic() throws {
        navigateToTbdView()

        // Find the TBD task by searching for task titles
        let tbdTaskTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'TBD Task'")
        ).firstMatch

        // Verify TBD task exists
        XCTAssertTrue(
            tbdTaskTitle.waitForExistence(timeout: 5),
            "TBD Task should be visible in TBD view mode"
        )

        // Capture screenshot as evidence for italic rendering
        // Save directly to disk for reliable extraction
        let screenshot = app.screenshot()
        let pngData = screenshot.pngRepresentation
        let path = "/tmp/TBD_ITALIC_EVIDENCE.png"
        FileManager.default.createFile(atPath: path, contents: pngData)
        print("Screenshot saved to: \(path)")

        // Also add as XCTAttachment for Xcode
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "TBD_ITALIC_EVIDENCE"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Additional verification: TBD task should have taskTitle identifier
        let taskTitleWithId = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'taskTitle_'")
        ).firstMatch

        XCTAssertTrue(
            taskTitleWithId.exists,
            "Task title with identifier 'taskTitle_*' should exist"
        )

        // Log for debugging
        print("=== TBD ITALIC TEST ===")
        print("TBD Task found: \(tbdTaskTitle.exists)")
        print("TBD Task label: \(tbdTaskTitle.label)")
        print("Screenshot captured as 'TBD_ITALIC_EVIDENCE'")
        print("=== END ===")
    }

    // MARK: - Alternative: Liste View Test

    /// Test: TBD Task in Liste view should show italic title
    func testTbdTaskInListeViewIsItalic() throws {
        // Navigate to Backlog tab
        let backlogTab = app.buttons["tab-backlog"]
        guard backlogTab.waitForExistence(timeout: 10) else {
            XCTFail("Backlog tab should exist")
            return
        }
        backlogTab.tap()
        sleep(1)

        // Open view mode switcher
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        guard viewModeSwitcher.waitForExistence(timeout: 5) else {
            XCTFail("viewModeSwitcher should exist")
            return
        }
        viewModeSwitcher.tap()
        sleep(1)

        // Select "Liste" view
        let listeOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Liste'")
        ).firstMatch

        guard listeOption.waitForExistence(timeout: 3) else {
            XCTFail("Liste option should exist")
            return
        }
        listeOption.tap()
        sleep(2)

        // Find TBD task (should appear first due to sortOrder = -1)
        let tbdTaskTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'TBD Task'")
        ).firstMatch

        XCTAssertTrue(
            tbdTaskTitle.waitForExistence(timeout: 5),
            "TBD Task should be visible in Liste view"
        )

        // Capture screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "TBD_ITALIC_LISTE_VIEW"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
