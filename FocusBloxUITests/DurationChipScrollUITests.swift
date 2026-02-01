//
//  DurationChipScrollUITests.swift
//  FocusBloxUITests
//
//  UI Tests for Duration Chip Scroll Bug Fix
//

import XCTest

@MainActor
final class DurationChipScrollUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()

        // Navigate to Backlog tab
        let backlogTab = app.buttons["backlogTab"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Duration Chip Tests

    /// Test: Tapping duration chip should not scroll the list
    func testDurationChipTapDoesNotScrollList() throws {
        // First, ensure we have at least one task visible
        let firstDurationBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch

        XCTAssertTrue(firstDurationBadge.waitForExistence(timeout: 5),
                      "Duration badge should exist")

        // Get the initial frame of the task (to detect scroll)
        let initialFrame = firstDurationBadge.frame

        // Tap the duration badge
        firstDurationBadge.tap()

        // Wait briefly for any scroll animation
        Thread.sleep(forTimeInterval: 0.5)

        // The badge should still be at approximately the same position
        // (small tolerance for animations)
        let afterTapFrame = firstDurationBadge.frame

        // Y position should not have changed significantly
        // If list scrolled to top, the frame would have moved up significantly
        let yDelta = abs(afterTapFrame.minY - initialFrame.minY)
        XCTAssertLessThan(yDelta, 50,
                          "Duration badge should not have scrolled. Delta: \(yDelta)")

        // Duration picker should appear - look for the picker content
        // The picker uses presentationDetents, so look for "Dauer waehlen" text
        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 3),
                      "Duration picker should appear with 'Dauer waehlen' title")
    }

    /// Test: Duration chip should open picker
    func testDurationChipOpensPicker() throws {
        let firstDurationBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).firstMatch

        XCTAssertTrue(firstDurationBadge.waitForExistence(timeout: 5),
                      "Duration badge should exist")

        // Tap the duration badge
        firstDurationBadge.tap()

        // Duration picker should appear - look for picker content
        let pickerTitle = app.staticTexts["Dauer waehlen"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 3),
                      "Duration picker should appear after tapping duration badge")
    }

    /// Test: Other chips should also not cause scroll issues
    func testImportanceChipDoesNotScrollList() throws {
        let firstImportanceBadge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).firstMatch

        XCTAssertTrue(firstImportanceBadge.waitForExistence(timeout: 5),
                      "Importance badge should exist")

        let initialFrame = firstImportanceBadge.frame

        // Tap the importance badge (cycles importance)
        firstImportanceBadge.tap()

        Thread.sleep(forTimeInterval: 0.3)

        let afterTapFrame = firstImportanceBadge.frame
        let yDelta = abs(afterTapFrame.minY - initialFrame.minY)

        XCTAssertLessThan(yDelta, 50,
                          "Importance badge should not have scrolled. Delta: \(yDelta)")
    }
}
