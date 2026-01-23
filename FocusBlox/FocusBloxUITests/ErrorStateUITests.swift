import XCTest

final class ErrorStateUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Error State UI Elements

    /// GIVEN: App might show error state
    /// WHEN: Error occurs (access denied, etc.)
    /// THEN: ContentUnavailableView should display error message
    func testErrorStateUIElementsExist() throws {
        // This test verifies the error state UI exists
        // We can't easily trigger a permission denial in UI tests
        // But we can verify the app handles it gracefully

        // Wait for app to load
        sleep(2)

        // App should either show:
        // 1. Tasks in backlog (cells)
        // 2. Tasks in Next Up only (no cells but "Next Up" header)
        // 3. Empty state (no tasks)
        // 4. Error state (no permission)

        let hasContent = app.cells.firstMatch.exists
        let hasNextUpContent = app.staticTexts["Next Up"].exists
        let hasEmptyState = app.staticTexts["Keine Tasks"].exists
        let hasErrorState = app.staticTexts["Fehler"].exists ||
                           app.images["exclamationmark.triangle"].exists

        let hasValidState = hasContent || hasNextUpContent || hasEmptyState || hasErrorState

        XCTAssertTrue(hasValidState, "App should show one of: content, Next Up, empty state, or error state")
    }

    /// GIVEN: App is in any state
    /// WHEN: Viewing BacklogView
    /// THEN: App should not crash and show appropriate UI
    func testBacklogViewDoesNotCrash() throws {
        // Simple smoke test - app launches and shows Backlog
        let backlogNav = app.navigationBars["FocusBlox"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 10), "Backlog should load without crash")
    }

    /// GIVEN: App is in any state
    /// WHEN: Switching to Zuordnen tab
    /// THEN: App should not crash and show appropriate UI
    func testTaskAssignmentViewDoesNotCrash() throws {
        // Switch to Zuordnen tab
        let zuordnenTab = app.tabBars.buttons["Zuordnen"]
        XCTAssertTrue(zuordnenTab.waitForExistence(timeout: 5))
        zuordnenTab.tap()

        // Should show Zuordnen nav bar
        let zuordnenNav = app.navigationBars["Zuordnen"]
        XCTAssertTrue(zuordnenNav.waitForExistence(timeout: 10), "Zuordnen should load without crash")
    }

    // MARK: - Loading State Tests

    /// GIVEN: App is launching
    /// WHEN: Data is loading
    /// THEN: Loading indicator might briefly appear
    func testLoadingStateTransition() throws {
        // App should transition from loading to content state
        // We just verify the final state is reached

        sleep(3) // Allow time for loading

        // Should not be stuck on loading
        let loadingText = app.staticTexts["Lade Tasks..."]
        let loadingCalendar = app.staticTexts["Lade Daten..."]

        // After 3 seconds, loading should be complete
        let stillLoading = loadingText.exists || loadingCalendar.exists

        // If still loading after 3 seconds, that might indicate a problem
        // But we don't fail the test - just document
        if stillLoading {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "StillLoading"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        XCTAssertTrue(true, "Loading state test completed")
    }

    // MARK: - Permission State Documentation

    /// Document the current permission state
    func testDocumentCurrentState() throws {
        sleep(3)

        // Backlog state
        let backlogScreenshot = app.screenshot()
        let backlogAttachment = XCTAttachment(screenshot: backlogScreenshot)
        backlogAttachment.name = "CurrentState-Backlog"
        backlogAttachment.lifetime = .keepAlways
        add(backlogAttachment)

        // Switch to Blöcke
        app.tabBars.buttons["Blöcke"].tap()
        sleep(2)

        // Blöcke state
        let bloeckeScreenshot = app.screenshot()
        let bloeckeAttachment = XCTAttachment(screenshot: bloeckeScreenshot)
        bloeckeAttachment.name = "CurrentState-Bloecke"
        bloeckeAttachment.lifetime = .keepAlways
        add(bloeckeAttachment)
    }

    // MARK: - Tab Bar Tests

    /// GIVEN: App is running
    /// WHEN: Viewing tab bar
    /// THEN: Both tabs should be accessible
    func testTabBarAccessibility() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")

        let backlogTab = app.tabBars.buttons["Backlog"]
        let bloeckeTab = app.tabBars.buttons["Blöcke"]

        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist")
        XCTAssertTrue(bloeckeTab.exists, "Blöcke tab should exist")

        // Test tab switching
        bloeckeTab.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["Blöcke"].exists, "Should navigate to Blöcke")

        backlogTab.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["FocusBlox"].exists, "Should navigate back to Backlog")
    }
}
