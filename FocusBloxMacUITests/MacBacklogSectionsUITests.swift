//
//  MacBacklogSectionsUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for Bug 65: macOS backlog priority sections.
//  Tests verify that macOS shows priority tier sections like iOS.
//

import XCTest

/// UI Tests for macOS backlog priority sections.
///
/// Tests verify:
/// 1. Priority filter shows tier section headers (Sofort erledigen, Bald einplanen, etc.)
/// 2. Overdue section visible when overdue tasks exist
/// 3. Non-priority filters still show flat list (no tier sections)
final class MacBacklogSectionsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test 1: Priority filter shows at least one tier section header

    func test_priorityFilter_showsTierSectionHeaders() throws {
        // Priority filter should be default or select it
        // Look for any tier section header text
        let tierLabels = [
            "Sofort erledigen",
            "Bald einplanen",
            "Bei Gelegenheit",
            "Irgendwann"
        ]

        // At least one tier label should be visible (depends on mock data scores)
        let foundAnyTier = tierLabels.contains { label in
            app.staticTexts[label].waitForExistence(timeout: 3)
        }

        XCTAssertTrue(foundAnyTier, "Priority filter should show at least one tier section header")
    }

    // MARK: - Test 2: Next Up section still visible

    func test_priorityFilter_stillShowsNextUpSection() throws {
        // "Next Up" header should still be visible
        let nextUpLabel = app.staticTexts["Next Up"]
        XCTAssertTrue(
            nextUpLabel.waitForExistence(timeout: 3),
            "Next Up section should still be visible in priority filter"
        )
    }

    // MARK: - Test 3: Tier headers NOT visible in recent filter

    func test_recentFilter_doesNotShowTierHeaders() throws {
        // Switch to recent filter via sidebar
        // macOS sidebar uses "Zuletzt" label for recent filter
        let recentButton = app.buttons["Zuletzt"].firstMatch
        if recentButton.waitForExistence(timeout: 3) {
            recentButton.click()

            // Tier labels should NOT be present in recent view
            let doNowLabel = app.staticTexts["Sofort erledigen"]
            XCTAssertFalse(
                doNowLabel.waitForExistence(timeout: 2),
                "Tier headers should NOT appear in recent filter"
            )
        }
    }
}
