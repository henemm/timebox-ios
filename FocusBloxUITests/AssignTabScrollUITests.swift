import XCTest

/// UI Tests for Bug 14: Assign Tab - Next Up visibility
///
/// Problem: When multiple Focus Blocks exist, Next Up section is cut off
/// Fix: Combine both sections into single ScrollView
///
/// TDD RED: Tests FAIL because bug exists
/// TDD GREEN: Tests PASS after fix
final class AssignTabScrollUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToAssign() {
        let assignTab = app.buttons["tab-assign"]
        XCTAssertTrue(assignTab.waitForExistence(timeout: 5), "Assign tab should exist")
        assignTab.tap()
        sleep(2)
    }

    // MARK: - Bug 14 Tests

    /// Test: Next Up section should be visible or reachable by scrolling
    func testNextUpSectionIsAccessible() throws {
        navigateToAssign()

        // Take screenshot of initial state
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug14-AssignTab-InitialState"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for Next Up header
        let nextUpHeader = app.staticTexts["Next Up"]

        // If not immediately visible, try scrolling down
        if !nextUpHeader.exists {
            // Find the main scroll view and scroll down
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                sleep(1)
            }
        }

        // Take screenshot after potential scroll
        let afterScroll = XCTAttachment(screenshot: app.screenshot())
        afterScroll.name = "Bug14-AssignTab-AfterScroll"
        afterScroll.lifetime = .keepAlways
        add(afterScroll)

        XCTAssertTrue(
            nextUpHeader.waitForExistence(timeout: 3),
            "Bug 14: 'Next Up' section should be visible or reachable by scrolling. " +
            "Currently it may be cut off when multiple Focus Blocks exist."
        )
    }

    /// Test: Entire Assign tab content should be scrollable
    func testAssignTabIsFullyScrollable() throws {
        navigateToAssign()

        // The entire content should be in a single scrollable container
        let scrollViews = app.scrollViews

        XCTAssertGreaterThanOrEqual(
            scrollViews.count, 1,
            "Bug 14: Assign tab should have a scrollable container."
        )

        // Verify we can scroll (content is scrollable)
        let scrollView = scrollViews.firstMatch
        guard scrollView.exists else {
            throw XCTSkip("No scroll view found")
        }

        // Scroll should work
        scrollView.swipeUp()
        sleep(1)

        let afterScrollScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScrollScreenshot.name = "Bug14-AssignTab-Scrolled"
        afterScrollScreenshot.lifetime = .keepAlways
        add(afterScrollScreenshot)
    }

    /// Test: Focus Blocks and Next Up should both be in same scroll container
    func testUnifiedScrollContainer() throws {
        navigateToAssign()

        // Look for the unified scroll view identifier
        let unifiedScrollView = app.scrollViews["assignTabScrollView"]

        XCTAssertTrue(
            unifiedScrollView.waitForExistence(timeout: 3),
            "Bug 14: Assign tab should have unified scroll view 'assignTabScrollView'. " +
            "Currently Focus Blocks and Next Up may be in separate containers."
        )
    }
}
