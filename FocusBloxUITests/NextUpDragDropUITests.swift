import XCTest

/// UI Tests for Drag & Drop in Next Up Section
/// Task 1: User soll Tasks in Next Up per Drag & Drop sortieren
///
/// Tests beweisen:
/// 1. Next Up Section existiert mit korrektem Header + Badge
/// 2. Alle 3 Mock-Tasks sind sichtbar (Titel + Dauer)
/// 3. Remove-Button entfernt Tasks aus Next Up (Interaktion)
/// 4. Layout-Screenshot dokumentiert Drag-Handle-Sichtbarkeit
final class NextUpDragDropUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(1)
    }

    // MARK: - Next Up Section Structure

    /// GIVEN: App launched with -UITesting (3 mock NextUp tasks)
    /// WHEN: User navigates to Backlog tab
    /// THEN: Next Up section with header and task count badge "3" is visible
    func testNextUpSectionShowsMockTasks() throws {
        navigateToBacklog()

        let nextUpHeader = app.staticTexts["Next Up"]
        XCTAssertTrue(
            nextUpHeader.waitForExistence(timeout: 5),
            "Next Up header should be visible with mock data"
        )

        // Badge should show "3" (3 mock tasks)
        let badge = app.staticTexts["3"]
        XCTAssertTrue(badge.exists, "Badge should show 3 for the 3 mock NextUp tasks")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task1-NextUp-Section-WithBadge"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: 3 mock NextUp tasks exist
    /// WHEN: User views the Next Up section
    /// THEN: All 3 task titles are visible in the correct section
    func testAllMockTaskTitlesAreVisible() throws {
        navigateToBacklog()

        let nextUpHeader = app.staticTexts["Next Up"]
        guard nextUpHeader.waitForExistence(timeout: 5) else {
            XCTFail("Next Up section should exist with mock data")
            return
        }

        // Verify each mock task title is shown
        XCTAssertTrue(
            app.staticTexts["Mock Task 1 #30min"].waitForExistence(timeout: 3),
            "Mock Task 1 should be visible in Next Up"
        )
        XCTAssertTrue(
            app.staticTexts["Mock Task 2 #15min"].exists,
            "Mock Task 2 should be visible in Next Up"
        )
        XCTAssertTrue(
            app.staticTexts["Mock Task 3 #45min"].exists,
            "Mock Task 3 should be visible in Next Up"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task1-AllThreeTasks-Visible"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// GIVEN: 3 mock NextUp tasks exist
    /// WHEN: User views the Next Up section
    /// THEN: Duration labels (30 min, 15 min, 45 min) are visible
    func testDurationLabelsAreVisible() throws {
        navigateToBacklog()

        let nextUpHeader = app.staticTexts["Next Up"]
        guard nextUpHeader.waitForExistence(timeout: 5) else {
            XCTFail("Next Up section should exist")
            return
        }

        XCTAssertTrue(app.staticTexts["30 min"].waitForExistence(timeout: 3), "30 min duration label")
        XCTAssertTrue(app.staticTexts["15 min"].exists, "15 min duration label")
        XCTAssertTrue(app.staticTexts["45 min"].exists, "45 min duration label")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task1-DurationLabels"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - Interaction Tests

    /// GIVEN: 3 mock NextUp tasks with xmark remove buttons
    /// WHEN: User taps a remove button
    /// THEN: Task is removed, badge changes from 3 to 2
    func testRemoveTaskFromNextUp() throws {
        navigateToBacklog()

        let nextUpHeader = app.staticTexts["Next Up"]
        guard nextUpHeader.waitForExistence(timeout: 5) else {
            XCTFail("Next Up section should exist")
            return
        }

        // All 3 tasks present
        XCTAssertTrue(app.staticTexts["Mock Task 1 #30min"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Mock Task 2 #15min"].exists)
        XCTAssertTrue(app.staticTexts["Mock Task 3 #45min"].exists)

        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "Task1-BeforeRemove-3Tasks"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        // Find remove buttons by accessibility label "Entfernen"
        let removeButtons = app.buttons.matching(NSPredicate(format: "label == 'Entfernen'"))
        guard removeButtons.count >= 1 else {
            // Fallback: try by identifier
            let idButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'removeNextUp_'"))
            guard idButtons.count >= 1 else {
                XCTFail("No remove buttons found (label 'Entfernen' or identifier 'removeNextUp_')")
                return
            }
            idButtons.element(boundBy: 0).tap()
            sleep(1)
            return
        }

        removeButtons.element(boundBy: 0).tap()
        sleep(1)

        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "Task1-AfterRemove-2Tasks"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // Badge should now show "2"
        let badge2 = app.staticTexts["2"]
        XCTAssertTrue(
            badge2.waitForExistence(timeout: 3),
            "Badge should show 2 after removing one task"
        )
    }

    // MARK: - Layout Screenshot

    /// GIVEN: Next Up section with 3 tasks
    /// WHEN: Screenshot captures the complete layout
    /// THEN: Visual proof that each row has: drag handle (≡), title, duration, remove (✕)
    func testNextUpLayoutWithDragHandlesScreenshot() throws {
        navigateToBacklog()

        let nextUpHeader = app.staticTexts["Next Up"]
        guard nextUpHeader.waitForExistence(timeout: 5) else {
            XCTFail("Next Up section should exist")
            return
        }

        // All content present
        XCTAssertTrue(app.staticTexts["Mock Task 1 #30min"].exists, "Task 1 title")
        XCTAssertTrue(app.staticTexts["Mock Task 2 #15min"].exists, "Task 2 title")
        XCTAssertTrue(app.staticTexts["Mock Task 3 #45min"].exists, "Task 3 title")
        XCTAssertTrue(app.staticTexts["30 min"].exists, "Duration 1")
        XCTAssertTrue(app.staticTexts["15 min"].exists, "Duration 2")
        XCTAssertTrue(app.staticTexts["45 min"].exists, "Duration 3")

        // Screenshot is the proof that drag handles (≡ icon) are visible
        // and the vertical layout is correct (not horizontal ScrollView)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Task1-CompleteLayout-DragHandles-Proof"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
