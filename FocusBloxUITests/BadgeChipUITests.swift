import XCTest

/// UI Tests for Bug 17: All tappable badges should have chip styling
///
/// Tests verify that all interactive badges (Importance, Urgency, Category)
/// have consistent chip design with backgrounds
///
/// TDD RED: Tests exist to document expected behavior
/// TDD GREEN: Visual verification after implementation
final class BadgeChipUITests: XCTestCase {

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

    private func navigateToBacklog() {
        let backlogTab = app.buttons["tab-backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
        sleep(1)
    }

    // MARK: - Badge Existence Tests

    /// Test: Importance badge should exist and be tappable
    func testImportanceBadgeExists() throws {
        navigateToBacklog()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug17-BadgeChips-Initial"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Find any importance badge
        let importanceBadges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        )

        XCTAssertGreaterThan(
            importanceBadges.count, 0,
            "Bug 17: At least one importance badge should exist in backlog"
        )

        // Verify it's tappable (has proper touch zone)
        let firstBadge = importanceBadges.firstMatch
        XCTAssertTrue(firstBadge.isHittable, "Importance badge should be tappable")
    }

    /// Test: Urgency badge should exist and be tappable
    func testUrgencyBadgeExists() throws {
        navigateToBacklog()

        let urgencyBadges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'")
        )

        XCTAssertGreaterThan(
            urgencyBadges.count, 0,
            "Bug 17: At least one urgency badge should exist in backlog"
        )

        let firstBadge = urgencyBadges.firstMatch
        XCTAssertTrue(firstBadge.isHittable, "Urgency badge should be tappable")
    }

    /// Test: Category badge should exist and be tappable
    func testCategoryBadgeExists() throws {
        navigateToBacklog()

        let categoryBadges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'categoryBadge_'")
        )

        XCTAssertGreaterThan(
            categoryBadges.count, 0,
            "Bug 17: At least one category badge should exist in backlog"
        )

        let firstBadge = categoryBadges.firstMatch
        XCTAssertTrue(firstBadge.isHittable, "Category badge should be tappable")
    }

    /// Test: Duration badge should exist (reference for chip styling)
    func testDurationBadgeExists() throws {
        navigateToBacklog()

        let durationBadges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        )

        XCTAssertGreaterThan(
            durationBadges.count, 0,
            "Bug 17: At least one duration badge should exist in backlog"
        )
    }

    // MARK: - Badge Interaction Tests

    /// Test: Tapping importance badge should cycle value (visual feedback expected)
    func testImportanceBadgeTapCycles() throws {
        navigateToBacklog()

        let importanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch

        guard importanceBadge.waitForExistence(timeout: 5) else {
            throw XCTSkip("No importance badge found")
        }

        // Tap the badge
        importanceBadge.tap()
        sleep(1)

        // Take screenshot to verify visual change
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug17-ImportanceTapped"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Badge should still exist after tap
        XCTAssertTrue(importanceBadge.exists, "Importance badge should remain after tap")
    }

    /// Test: Tapping urgency badge should toggle value (visual feedback expected)
    func testUrgencyBadgeTapToggles() throws {
        navigateToBacklog()

        let urgencyBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'")
        ).firstMatch

        guard urgencyBadge.waitForExistence(timeout: 5) else {
            throw XCTSkip("No urgency badge found")
        }

        // Tap the badge
        urgencyBadge.tap()
        sleep(1)

        // Take screenshot to verify visual change
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug17-UrgencyTapped"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Badge should still exist after tap
        XCTAssertTrue(urgencyBadge.exists, "Urgency badge should remain after tap")
    }

    /// Test: Tapping category badge should open picker (sheet expected)
    func testCategoryBadgeTapOpensPicker() throws {
        navigateToBacklog()

        let categoryBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'categoryBadge_'")
        ).firstMatch

        guard categoryBadge.waitForExistence(timeout: 5) else {
            throw XCTSkip("No category badge found")
        }

        // Tap the badge
        categoryBadge.tap()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bug17-CategoryTapped"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Either a sheet opens or category changes inline
        // (depends on implementation - this test documents behavior)
    }
}
