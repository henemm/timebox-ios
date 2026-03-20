import XCTest

/// Inspection-Only: Navigiert zur Erledigt-View und macht Screenshot + Hierarchy Dump
final class ErledigtViewInspectionTest: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    /// Navigiert zur Erledigt-View, macht Screenshot, dokumentiert alle Aktionen
    func testInspectErledigtView() throws {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5))
        backlogTab.tap()

        // Open ViewMode switcher
        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(viewModeSwitcher.waitForExistence(timeout: 3))
        viewModeSwitcher.tap()

        // Select "Erledigt" from the dropdown menu
        let completedOption = app.menuItems["Erledigt"]
        if completedOption.waitForExistence(timeout: 3) {
            completedOption.tap()
        } else {
            // Fallback: find button inside menu/popover context
            let menuButton = app.buttons.matching(NSPredicate(format: "label == 'Erledigt'")).element(boundBy: 0)
            XCTAssertTrue(menuButton.waitForExistence(timeout: 3))
            menuButton.tap()
        }

        // Wait for completed task to appear
        let completedTask = app.staticTexts["[MOCK] Erledigte Backlog-Aufgabe"]
        XCTAssertTrue(completedTask.waitForExistence(timeout: 5), "Mock completed task should be visible")

        // Screenshot: Erledigt-View Gesamtansicht — save to /tmp for inspection
        let screenshot1 = app.screenshot()
        let att1 = XCTAttachment(screenshot: screenshot1)
        att1.name = "Erledigt-View-Gesamt"
        att1.lifetime = .keepAlways
        add(att1)

        // Also save to /tmp for direct file access
        let pngData = screenshot1.pngRepresentation
        let filePath = "/tmp/erledigt_view_screenshot.png"
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("Screenshot saved to: \(filePath)")

        // Document: Undo button present?
        let undoButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'undoCompleteButton_'"))
        print("=== ERLEDIGT VIEW INSPECTION ===")
        print("Undo buttons found: \(undoButtons.count)")
        for i in 0..<undoButtons.count {
            let btn = undoButtons.element(boundBy: i)
            print("  Undo[\(i)]: id=\(btn.identifier), label=\(btn.label), hittable=\(btn.isHittable)")
        }

        // Document: Delete button present?
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deleteCompletedButton_'"))
        print("Delete buttons found: \(deleteButtons.count)")
        for i in 0..<deleteButtons.count {
            let btn = deleteButtons.element(boundBy: i)
            print("  Delete[\(i)]: id=\(btn.identifier), label=\(btn.label), hittable=\(btn.isHittable)")
        }

        // Document: CompletedTaskRow present?
        let completedRows = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'completedTaskRow_'"))
        print("Completed rows found: \(completedRows.count)")

        print("=== END INSPECTION ===")
    }
}
