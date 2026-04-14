import XCTest

final class BacklogHygieneUITests: XCTestCase {

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

    // MARK: - Banner

    /// GIVEN: Stale tasks exist in backlog (older than threshold)
    /// WHEN: BacklogView is displayed
    /// THEN: Hygiene banner with task count is visible
    func test_hygieneBanner_appearsWhenStaleTasksExist() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Hygiene banner should appear when stale tasks exist")
    }

    /// GIVEN: Hygiene banner is visible
    /// WHEN: User taps on the banner
    /// THEN: BacklogHygieneView sheet opens
    func test_hygieneBanner_opensSheet() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        let title = app.staticTexts["hygieneTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Hygiene view title should appear")
    }

    // MARK: - Card View

    /// GIVEN: BacklogHygieneView is open with stale tasks
    /// WHEN: First card is displayed
    /// THEN: Task title and age info are visible
    func test_hygieneView_showsTaskCard() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        let taskTitle = app.staticTexts["hygieneTaskTitle"]
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 3), "Task title should be visible on card")

        let taskAge = app.staticTexts["hygieneTaskAge"]
        XCTAssertTrue(taskAge.waitForExistence(timeout: 3), "Task age should be visible on card")
    }

    // MARK: - Actions

    /// GIVEN: A task card is displayed in hygiene view
    /// WHEN: User taps "Parken"
    /// THEN: Task is parked and card advances (title text changes or summary shows)
    func test_hygieneView_parkAction() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        let taskTitle = app.staticTexts["hygieneTaskTitle"]
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 3))
        let initialTitle = taskTitle.label

        let parkButton = app.buttons["hygieneParkButton"]
        XCTAssertTrue(parkButton.waitForExistence(timeout: 3), "Park button should exist")
        parkButton.tap()

        // After action: either summary appears or task title changes
        let summaryAppeared = app.staticTexts["hygieneSummary"].waitForExistence(timeout: 5)
        if !summaryAppeared {
            // Must be on next card — title should have changed
            XCTAssertTrue(taskTitle.waitForExistence(timeout: 3))
            XCTAssertNotEqual(taskTitle.label, initialTitle, "Task title should change after park")
        }
    }

    /// GIVEN: A task card is displayed in hygiene view
    /// WHEN: User taps "Löschen"
    /// THEN: Task is deleted and card advances
    func test_hygieneView_deleteAction() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        let taskTitle = app.staticTexts["hygieneTaskTitle"]
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 3))
        let initialTitle = taskTitle.label

        let deleteButton = app.buttons["hygieneDeleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should exist")
        deleteButton.tap()

        let summaryAppeared = app.staticTexts["hygieneSummary"].waitForExistence(timeout: 5)
        if !summaryAppeared {
            XCTAssertTrue(taskTitle.waitForExistence(timeout: 3))
            XCTAssertNotEqual(taskTitle.label, initialTitle, "Task title should change after delete")
        }
    }

    /// GIVEN: A task card is displayed in hygiene view
    /// WHEN: User taps "Behalten"
    /// THEN: Task is skipped and card advances
    func test_hygieneView_keepAction() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        let taskTitle = app.staticTexts["hygieneTaskTitle"]
        XCTAssertTrue(taskTitle.waitForExistence(timeout: 3))
        let initialTitle = taskTitle.label

        let keepButton = app.buttons["hygieneKeepButton"]
        XCTAssertTrue(keepButton.waitForExistence(timeout: 3), "Keep button should exist")
        keepButton.tap()

        let summaryAppeared = app.staticTexts["hygieneSummary"].waitForExistence(timeout: 5)
        if !summaryAppeared {
            XCTAssertTrue(taskTitle.waitForExistence(timeout: 3))
            XCTAssertNotEqual(taskTitle.label, initialTitle, "Task title should change after keep")
        }
    }

    // MARK: - Bug #219: Keep Action persistiert hygieneReviewedAt

    /// GIVEN: User processed all stale tasks with "Behalten"
    /// WHEN: User closes dialog and reopens Backlog
    /// THEN: Hygiene banner should NOT reappear (tasks have been reviewed)
    /// TDD RED: Banner reappears because keepTask() doesn't set hygieneReviewedAt
    func test_hygieneView_keepAction_taskNotSuggested_afterReview() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        // Process all tasks by tapping "Behalten" until summary appears
        for _ in 0..<10 {
            let summary = app.staticTexts["hygieneSummary"]
            if summary.waitForExistence(timeout: 1) { break }

            let keepButton = app.buttons["hygieneKeepButton"]
            if keepButton.waitForExistence(timeout: 3) {
                keepButton.tap()
            } else {
                break
            }
        }

        let summary = app.staticTexts["hygieneSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Summary should appear")

        // Close the hygiene dialog
        let doneButton = app.buttons["Fertig"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()

        // Banner should NOT reappear — all tasks were reviewed
        let bannerAfter = app.buttons["hygieneCleanupBanner"]
        let bannerReappeared = bannerAfter.waitForExistence(timeout: 3)
        XCTAssertFalse(bannerReappeared, "Hygiene banner should NOT reappear after all tasks were reviewed with 'Behalten'")
    }

    // MARK: - Summary

    /// GIVEN: User has processed all stale tasks
    /// WHEN: Last action is taken
    /// THEN: Summary view shows counts for each action
    func test_hygieneView_summaryAfterLastTask() throws {
        let banner = app.buttons["hygieneCleanupBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()

        // Process all tasks by tapping "Behalten" until summary appears
        // Each "Behalten" shows a hint for 1.2s before advancing
        for _ in 0..<10 {
            let summary = app.staticTexts["hygieneSummary"]
            if summary.waitForExistence(timeout: 1) { break }

            let keepButton = app.buttons["hygieneKeepButton"]
            if keepButton.waitForExistence(timeout: 3) {
                keepButton.tap()
            } else {
                break
            }
        }

        let summary = app.staticTexts["hygieneSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Summary should appear after all tasks processed")
    }
}
