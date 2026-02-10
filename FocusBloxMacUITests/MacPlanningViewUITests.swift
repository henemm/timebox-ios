//
//  MacPlanningViewUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for macOS Planning View - Focus Block interactions
//  TDD RED: Tests for tap-to-tasks and ellipsis-to-edit functionality
//

import XCTest

/// UI Tests for macOS Planning View
///
/// Tests verify:
/// 1. FocusBlock has ellipsis [...] button
/// 2. Tap on block opens tasks sheet
/// 3. Tap on [...] button opens edit sheet
///
/// TDD RED: All tests should FAIL until macOS implementation matches iOS
final class MacPlanningViewUITests: XCTestCase {

    var app: XCUIApplication!

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

    // MARK: - Helper

    /// Navigate to Planen tab via radio group (macOS Picker(.segmented) in toolbar)
    /// Radio buttons use SF Symbol names as identifiers, not section labels
    private func navigateToPlanning() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        if radioGroup.waitForExistence(timeout: 3) {
            // "calendar" is the SF Symbol identifier for Planen
            let planenRadio = radioGroup.radioButtons["calendar"]
            if planenRadio.waitForExistence(timeout: 2) {
                planenRadio.click()
                sleep(1)
                return
            }
        }

        // Fallback: try direct button
        let planenTab = app.buttons["Planen"]
        if planenTab.waitForExistence(timeout: 2) {
            planenTab.click()
            sleep(1)
        }
    }

    // MARK: - Test 1: FocusBlock exists in timeline

    /// Test: Focus blocks should appear in macOS timeline with proper identifiers
    /// TDD RED: Tests FAIL because blocks don't have accessibility identifiers yet
    func testFocusBlockExistsInTimeline() throws {
        navigateToPlanning()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-FocusBlockInTimeline"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for a FocusBlock with timeline-style identifier
        // Format: focusBlock_{blockID}
        let focusBlockInTimeline = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlockInTimeline.waitForExistence(timeout: 5),
            "TDD RED: Focus Block MUST appear in timeline with identifier 'focusBlock_{id}'"
        )
    }

    // MARK: - Test 2: FocusBlock has ellipsis button

    /// Test: Focus Block should have an ellipsis [...] button for editing
    /// TDD RED: Tests FAIL because ellipsis button doesn't exist yet on macOS
    func testFocusBlockHasEllipsisButton() throws {
        navigateToPlanning()

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-EllipsisButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for ellipsis/edit button with identifier pattern
        // Format: focusBlockEditButton_{blockID}
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "TDD RED: Focus Block MUST have edit button with identifier 'focusBlockEditButton_{id}'"
        )
    }

    // MARK: - Test 3: Tap on block navigates to Zuweisen tab

    /// Test: Clicking on a Focus Block should navigate to Zuweisen tab (unified navigation)
    /// Updated: Previously opened tasks sheet, now navigates to Zuweisen for unified editing
    func testTapBlockOpensTasksSheet() throws {
        navigateToPlanning()

        // Find a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlock.waitForExistence(timeout: 5),
            "Cannot click block - identifier 'focusBlock_' not found"
        )

        focusBlock.click()
        sleep(1)

        // Take screenshot after click
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-AfterBlockClick"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify: Should navigate to Zuweisen tab (not open a sheet)
        // MacAssignView shows "Tasks in einen Focus Block ziehen"
        let zuweisenFooter = app.staticTexts["Tasks in einen Focus Block ziehen"]
        XCTAssertTrue(
            zuweisenFooter.waitForExistence(timeout: 3),
            "Clicking block MUST navigate to Zuweisen tab"
        )

        // Verify: No tasks sheet should appear
        let tasksSheetTitle = app.staticTexts["Tasks im Block"]
        XCTAssertFalse(tasksSheetTitle.exists, "Tasks sheet should NOT appear - unified navigation replaces it")
    }

    // MARK: - Test 4: Tap ellipsis opens edit sheet

    /// Test: Clicking the [...] button should open the edit sheet
    /// TDD RED: Tests FAIL because ellipsis button doesn't exist yet on macOS
    func testTapEllipsisOpensEditSheet() throws {
        navigateToPlanning()

        // Find ellipsis button
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        XCTAssertTrue(
            editButton.waitForExistence(timeout: 5),
            "TDD RED: Cannot click ellipsis - button not found"
        )

        editButton.click()
        sleep(1)

        // Take screenshot after click
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-AfterEllipsisClick"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify EDIT sheet opened
        let editSheetTitle = app.staticTexts["Block bearbeiten"]
        let saveButton = app.buttons["Speichern"]

        let editSheetOpened = editSheetTitle.waitForExistence(timeout: 3) || saveButton.exists

        XCTAssertTrue(editSheetOpened, "TDD RED: Clicking ellipsis MUST open edit sheet")
    }

    // MARK: - Test 5: Block tap navigates away from Planen

    /// Test: After tapping a block, we should no longer be on the Planen tab
    /// Updated: Previously tested tasks sheet dismiss button, now tests navigation
    func testTasksSheetHasDoneButton() throws {
        navigateToPlanning()

        // Find and click a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("Focus Block not found")
            return
        }

        focusBlock.click()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-AfterBlockTapNavigation"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify: Planen-specific content should no longer be visible
        let planenFooter = app.staticTexts["Tasks in die Timeline ziehen"]
        XCTAssertFalse(
            planenFooter.exists,
            "After tapping block, should have navigated away from Planen tab"
        )
    }

    // MARK: - Test 6: Edit sheet has save button

    /// Test: Edit sheet should have save button
    func testEditSheetHasSaveButton() throws {
        navigateToPlanning()

        // Find ellipsis button
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlockEditButton_'")
        ).firstMatch

        guard editButton.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: Ellipsis button not found")
            return
        }

        editButton.click()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-EditSheetSaveButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for "Speichern" button
        let saveButton = app.buttons["Speichern"]
        let saveButtonEN = app.buttons["Save"]

        let hasSaveButton = saveButton.waitForExistence(timeout: 3) || saveButtonEN.exists

        XCTAssertTrue(hasSaveButton, "TDD RED: Edit sheet MUST have 'Speichern' button")
    }
}
