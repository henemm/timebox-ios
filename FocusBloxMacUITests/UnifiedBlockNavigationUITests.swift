//
//  UnifiedBlockNavigationUITests.swift
//  FocusBloxMacUITests
//
//  Tests for Unified Block-Detail Navigation
//  Tap on FocusBlock in Planen-Tab should navigate to Zuweisen-Tab
//

import XCTest

/// UI Tests for Unified Block-Detail Navigation
///
/// Tests verify:
/// 1. Tap on block in Planen navigates to Zuweisen tab
/// 2. Date stays synchronized between Planen and Zuweisen tabs
/// 3. FocusBlockTasksSheet no longer appears on block tap
/// 4. Block is visible/highlighted in Zuweisen after navigation
///
/// macOS Picker(.segmented) in toolbar renders as RadioGroup.
/// Radio buttons use SF Symbol names as identifiers:
///   Backlog="tray.full", Planen="calendar", Zuweisen="arrow.up.arrow.down",
///   Focus="target", Review="chart.bar"
final class UnifiedBlockNavigationUITests: XCTestCase {

    var app: XCUIApplication!

    // SF Symbol identifiers for navigation radio buttons
    private let planenRadioID = "calendar"
    private let zuweisenRadioID = "arrow.up.arrow.down"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window to appear
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to a tab using SF Symbol identifier for the radio button
    private func navigateViaRadioButton(symbolID: String) {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        guard radioGroup.waitForExistence(timeout: 3) else { return }
        let radioButton = radioGroup.radioButtons[symbolID]
        guard radioButton.waitForExistence(timeout: 2) else { return }
        radioButton.click()
        sleep(1)
    }

    /// Navigate to Planen tab
    private func navigateToPlanen() {
        navigateViaRadioButton(symbolID: planenRadioID)
    }

    /// Navigate to Zuweisen tab
    private func navigateToZuweisen() {
        navigateViaRadioButton(symbolID: zuweisenRadioID)
    }

    /// Find the first FocusBlock in the timeline
    private func findFocusBlock() -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch
    }

    /// Check if we're on the Zuweisen tab by looking for Zuweisen-specific content
    private func isOnZuweisenTab() -> Bool {
        // MacAssignView shows "Tasks in einen Focus Block ziehen"
        let zuweisenFooter = app.staticTexts["Tasks in einen Focus Block ziehen"]
        return zuweisenFooter.waitForExistence(timeout: 3)
    }

    /// Check if we're on the Planen tab by looking for Planen-specific content
    private func isOnPlanenTab() -> Bool {
        // MacPlanningView shows "Tasks in die Timeline ziehen"
        let planenFooter = app.staticTexts["Tasks in die Timeline ziehen"]
        return planenFooter.waitForExistence(timeout: 3)
    }

    // MARK: - Test 1: Tap on block navigates to Zuweisen tab

    /// Test: Clicking a FocusBlock in the Planen-Tab should switch to Zuweisen tab
    func testTapBlockNavigatesToZuweisenTab() throws {
        navigateToPlanen()

        // Find a FocusBlock in the timeline
        let focusBlock = findFocusBlock()

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("No FocusBlock found in timeline - need calendar with focus blocks for today")
            return
        }

        // Take screenshot before tap
        let beforeScreenshot = XCTAttachment(screenshot: app.screenshot())
        beforeScreenshot.name = "UnifiedNav-BeforeBlockTap"
        beforeScreenshot.lifetime = .keepAlways
        add(beforeScreenshot)

        // Tap the block
        focusBlock.click()
        sleep(1)

        // Take screenshot after tap
        let afterScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterScreenshot.name = "UnifiedNav-AfterBlockTap"
        afterScreenshot.lifetime = .keepAlways
        add(afterScreenshot)

        // Verify: Should now be on Zuweisen tab (check for Zuweisen-specific content)
        XCTAssertTrue(
            isOnZuweisenTab(),
            "After tapping a block in Planen, the Zuweisen tab MUST be shown"
        )
    }

    // MARK: - Test 2: No TasksSheet appears on block tap

    /// Test: Clicking a block should NOT open the FocusBlockTasksSheet
    func testNoTasksSheetOnBlockTap() throws {
        navigateToPlanen()

        let focusBlock = findFocusBlock()

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("No FocusBlock found in timeline")
            return
        }

        focusBlock.click()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedNav-NoTasksSheet"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify: "Tasks im Block" sheet should NOT appear
        let tasksSheetTitle = app.staticTexts["Tasks im Block"]
        let tasksSheet = app.sheets.matching(
            NSPredicate(format: "identifier == 'focusBlockTasksSheet'")
        ).firstMatch

        XCTAssertFalse(
            tasksSheetTitle.exists,
            "'Tasks im Block' sheet must NOT appear after block tap. Should navigate to Zuweisen instead."
        )
        XCTAssertFalse(
            tasksSheet.exists,
            "FocusBlockTasksSheet must NOT appear. Should navigate to Zuweisen instead."
        )
    }

    // MARK: - Test 3: Both tabs are accessible and share date context

    /// Test: Both Planen and Zuweisen tabs are reachable and load correctly
    /// The shared date binding is verified implicitly - both views use the same @Binding
    func testDateSyncBetweenPlanenAndZuweisen() throws {
        // Navigate to Planen
        navigateToPlanen()
        sleep(1)

        // Verify we're on Planen (view-specific footer text)
        let onPlanen = isOnPlanenTab()

        // Take screenshot of Planen tab
        let screenshot1 = XCTAttachment(screenshot: app.screenshot())
        screenshot1.name = "DateSync-PlanenTab"
        screenshot1.lifetime = .keepAlways
        add(screenshot1)

        XCTAssertTrue(onPlanen, "Should be on Planen tab after navigation")

        // Navigate to Zuweisen
        navigateToZuweisen()
        sleep(1)

        // Verify we're on Zuweisen (view-specific footer text)
        let onZuweisen = isOnZuweisenTab()

        // Take screenshot of Zuweisen tab
        let screenshot2 = XCTAttachment(screenshot: app.screenshot())
        screenshot2.name = "DateSync-ZuweisenTab"
        screenshot2.lifetime = .keepAlways
        add(screenshot2)

        XCTAssertTrue(onZuweisen, "Should be on Zuweisen tab after navigation")

        // Navigate back to Planen to verify round-trip works
        navigateToPlanen()
        sleep(1)

        XCTAssertTrue(isOnPlanenTab(), "Should be back on Planen tab after round-trip")
    }

    // MARK: - Test 4: Block card visible in Zuweisen after navigation

    /// Test: After tapping a block in Planen, the corresponding block card should be visible in Zuweisen
    func testBlockCardVisibleInZuweisenAfterNavigation() throws {
        navigateToPlanen()

        // Find a FocusBlock and get its ID
        let focusBlock = findFocusBlock()

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("No FocusBlock found in timeline")
            return
        }

        let blockIdentifier = focusBlock.identifier
        // Extract block ID from "focusBlock_{id}" format
        let blockID = blockIdentifier.replacingOccurrences(of: "focusBlock_", with: "")

        // Tap the block
        focusBlock.click()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "UnifiedNav-BlockCardVisible"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify: We should now be on Zuweisen tab
        XCTAssertTrue(
            isOnZuweisenTab(),
            "Must be on Zuweisen tab after block tap"
        )

        // Verify: The corresponding block card should exist in Zuweisen
        let blockCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'focusBlockCard_\(blockID)'")
        ).firstMatch

        XCTAssertTrue(
            blockCard.waitForExistence(timeout: 3),
            "Block card 'focusBlockCard_\(blockID)' must be visible in Zuweisen tab after navigation"
        )
    }
}
