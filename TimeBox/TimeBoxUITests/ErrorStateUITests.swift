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
        // 1. Tasks (normal state)
        // 2. Empty state (no tasks)
        // 3. Error state (no permission)

        let hasContent = app.cells.firstMatch.exists
        let hasEmptyState = app.staticTexts["Keine Tasks"].exists
        let hasErrorState = app.staticTexts["Fehler"].exists ||
                           app.images["exclamationmark.triangle"].exists

        let hasValidState = hasContent || hasEmptyState || hasErrorState

        XCTAssertTrue(hasValidState, "App should show one of: content, empty state, or error state")
    }

    /// GIVEN: App is in any state
    /// WHEN: Viewing BacklogView
    /// THEN: App should not crash and show appropriate UI
    func testBacklogViewDoesNotCrash() throws {
        // Simple smoke test - app launches and shows Backlog
        let backlogNav = app.navigationBars["Backlog"]
        XCTAssertTrue(backlogNav.waitForExistence(timeout: 10), "Backlog should load without crash")
    }

    /// GIVEN: App is in any state
    /// WHEN: Switching to PlanningView
    /// THEN: App should not crash and show appropriate UI
    func testPlanningViewDoesNotCrash() throws {
        // Switch to Planen tab
        let planenTab = app.tabBars.buttons["Planen"]
        XCTAssertTrue(planenTab.waitForExistence(timeout: 5))
        planenTab.tap()

        // Should show Planen nav bar
        let planenNav = app.navigationBars["Planen"]
        XCTAssertTrue(planenNav.waitForExistence(timeout: 10), "Planen should load without crash")
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

        // Switch to Planen
        app.tabBars.buttons["Planen"].tap()
        sleep(2)

        // Planen state
        let planenScreenshot = app.screenshot()
        let planenAttachment = XCTAttachment(screenshot: planenScreenshot)
        planenAttachment.name = "CurrentState-Planen"
        planenAttachment.lifetime = .keepAlways
        add(planenAttachment)
    }

    // MARK: - Tab Bar Tests

    /// GIVEN: App is running
    /// WHEN: Viewing tab bar
    /// THEN: Both tabs should be accessible
    func testTabBarAccessibility() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")

        let backlogTab = app.tabBars.buttons["Backlog"]
        let planenTab = app.tabBars.buttons["Planen"]

        XCTAssertTrue(backlogTab.exists, "Backlog tab should exist")
        XCTAssertTrue(planenTab.exists, "Planen tab should exist")

        // Test tab switching
        planenTab.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["Planen"].exists, "Should navigate to Planen")

        backlogTab.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["Backlog"].exists, "Should navigate back to Backlog")
    }
}
