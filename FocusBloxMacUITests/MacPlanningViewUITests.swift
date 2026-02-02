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

    private func navigateToPlanning() {
        // macOS uses sidebar navigation - look for "Planen" tab
        let planenTab = app.buttons["Planen"]
        if planenTab.waitForExistence(timeout: 3) {
            planenTab.click()
            sleep(1)
            return
        }

        // Alternative: try sidebar item
        let sidebarItem = app.outlineRows["Planen"].firstMatch
        if sidebarItem.waitForExistence(timeout: 3) {
            sidebarItem.click()
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

    // MARK: - Test 3: Tap on block opens tasks sheet

    /// Test: Clicking on a Focus Block should open the tasks sheet (not edit sheet)
    /// TDD RED: Tests FAIL because tap handler doesn't exist on macOS
    func testTapBlockOpensTasksSheet() throws {
        navigateToPlanning()

        // Find a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        XCTAssertTrue(
            focusBlock.waitForExistence(timeout: 5),
            "TDD RED: Cannot click block - identifier 'focusBlock_' not found"
        )

        focusBlock.click()
        sleep(1)

        // Take screenshot after click
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-AfterBlockClick"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Verify TASKS sheet opened (not edit sheet)
        // Tasks sheet has identifier "focusBlockTasksSheet" or title "Tasks im Block"
        let tasksSheet = app.sheets.matching(
            NSPredicate(format: "identifier == 'focusBlockTasksSheet'")
        ).firstMatch
        let tasksSheetTitle = app.staticTexts["Tasks im Block"]

        let tasksSheetOpened = tasksSheet.waitForExistence(timeout: 3) || tasksSheetTitle.exists

        // Also verify it's NOT the edit sheet
        let editSheetTitle = app.staticTexts["Block bearbeiten"]
        let isEditSheet = editSheetTitle.exists

        XCTAssertTrue(tasksSheetOpened, "TDD RED: Clicking block MUST open tasks sheet")
        XCTAssertFalse(isEditSheet, "TDD RED: Clicking block should NOT open edit sheet directly")
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

    // MARK: - Test 5: Tasks sheet can be dismissed

    /// Test: Tasks sheet should have a "Fertig" button to close it
    func testTasksSheetHasDoneButton() throws {
        navigateToPlanning()

        // Find and click a FocusBlock
        let focusBlock = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'focusBlock_'")
        ).firstMatch

        guard focusBlock.waitForExistence(timeout: 5) else {
            XCTFail("TDD RED: Focus Block not found")
            return
        }

        focusBlock.click()
        sleep(1)

        // Take screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "MacPlanning-TasksSheetDoneButton"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Look for "Fertig" button
        let doneButton = app.buttons["Fertig"]
        let doneButtonEN = app.buttons["Done"]

        let hasDoneButton = doneButton.waitForExistence(timeout: 3) || doneButtonEN.exists

        XCTAssertTrue(hasDoneButton, "TDD RED: Tasks sheet MUST have 'Fertig' button")
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
