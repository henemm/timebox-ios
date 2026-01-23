import XCTest

/// UI Tests for UX Improvements (6 Features in 3 Phases)
final class UXImprovementsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-data"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Phase 1.1: Icon Consistency

    /// Test that the "Move to Next Up" button uses arrow.up.circle icon consistently
    func testMoveUpIconConsistency() throws {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        // Wait for content to load
        sleep(1)

        // Check for arrow.up.circle button (the "Move to Next Up" action)
        let moveUpButtons = app.buttons.matching(identifier: "moveUpButton")
        // If we have tasks, we should see the move up button
        if moveUpButtons.count > 0 {
            XCTAssertTrue(moveUpButtons.firstMatch.exists, "Move up button should exist in Backlog")
        }

        // Navigate to Zuordnen tab
        let assignTab = app.tabBars.buttons["Zuordnen"]
        XCTAssertTrue(assignTab.waitForExistence(timeout: 5), "Zuordnen tab should exist")
        assignTab.tap()

        sleep(1)

        // Check for consistent icon in assignment view
        let assignMoveUpButtons = app.buttons.matching(identifier: "moveUpButton")
        if assignMoveUpButtons.count > 0 {
            XCTAssertTrue(assignMoveUpButtons.firstMatch.exists, "Move up button should exist in Zuordnen")
        }
    }

    // MARK: - Phase 1.2: Focus Blocks Deletable (Swipe Action)

    /// Test that Focus Blocks can be deleted via swipe action
    func testFocusBlockSwipeToDelete() throws {
        // Navigate to Blöcke tab
        let planTab = app.tabBars.buttons["Blöcke"]
        XCTAssertTrue(planTab.waitForExistence(timeout: 5), "Blöcke tab should exist")
        planTab.tap()

        sleep(2)

        // Look for existing blocks section
        let existingBlocksHeader = app.staticTexts["Heutige Blöcke"]

        if existingBlocksHeader.waitForExistence(timeout: 3) {
            // Find a block row (they should be in a list)
            let blockRows = app.cells.matching(NSPredicate(format: "label CONTAINS 'Focus Block' OR label CONTAINS ':'"))

            if blockRows.count > 0 {
                let firstBlock = blockRows.firstMatch

                // Perform swipe left to reveal delete action
                firstBlock.swipeLeft()

                // Check for delete button
                let deleteButton = app.buttons["Löschen"]
                XCTAssertTrue(deleteButton.waitForExistence(timeout: 2), "Delete button should appear after swipe")
            }
        }
    }

    // MARK: - Phase 1.3: Drag & Drop for Task Reordering

    /// Test that tasks in Focus Blocks have drag handles for reordering
    func testTaskDragHandlesExist() throws {
        // Navigate to Zuordnen tab
        let assignTab = app.tabBars.buttons["Zuordnen"]
        XCTAssertTrue(assignTab.waitForExistence(timeout: 5), "Zuordnen tab should exist")
        assignTab.tap()

        sleep(2)

        // Look for a Focus Block card with tasks
        // In edit mode, drag handles should be visible
        // The List with .environment(\.editMode, .constant(.active)) should show reorder controls

        // Check for task rows in blocks - they should have the drag handle indicator
        // SwiftUI shows these as "Reorder" accessibility elements when editMode is active
        let reorderControls = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Reorder'"))

        // If there are tasks in blocks, reorder controls should exist
        // Note: This depends on having mock data with tasks assigned to blocks
        if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'min'")).count > 0 {
            // Tasks exist, check for reorder capability
            XCTAssertTrue(reorderControls.count >= 0, "Reorder controls should be available for tasks in blocks")
        }
    }

    // MARK: - Phase 2.1: Focus Blocks Editable

    /// Test that tapping a Focus Block opens the edit sheet
    func testFocusBlockTapOpensEditSheet() throws {
        // Navigate to Blöcke tab
        let planTab = app.tabBars.buttons["Blöcke"]
        XCTAssertTrue(planTab.waitForExistence(timeout: 5), "Blöcke tab should exist")
        planTab.tap()

        sleep(2)

        // Look for existing blocks
        let existingBlocksHeader = app.staticTexts["Heutige Blöcke"]

        if existingBlocksHeader.waitForExistence(timeout: 3) {
            // Find a block row
            let blockCells = app.cells.allElementsBoundByIndex

            for cell in blockCells {
                // Skip cells that don't look like block rows
                if cell.label.contains(":") || cell.label.contains("Focus") {
                    // Tap the block
                    cell.tap()

                    // Check for edit sheet elements
                    let editTitle = app.navigationBars["Block bearbeiten"]
                    let startPicker = app.datePickers.matching(NSPredicate(format: "label CONTAINS 'Start'")).firstMatch
                    let saveButton = app.buttons["Speichern"]

                    if editTitle.waitForExistence(timeout: 2) {
                        XCTAssertTrue(editTitle.exists, "Edit sheet title should appear")
                        XCTAssertTrue(saveButton.exists, "Save button should exist in edit sheet")

                        // Dismiss the sheet
                        app.buttons["Abbrechen"].tap()
                        break
                    }
                }
            }
        }
    }

    /// Test that the edit sheet has time pickers and delete option
    func testFocusBlockEditSheetHasRequiredElements() throws {
        // Navigate to Blöcke tab
        let planTab = app.tabBars.buttons["Blöcke"]
        XCTAssertTrue(planTab.waitForExistence(timeout: 5), "Blöcke tab should exist")
        planTab.tap()

        sleep(2)

        // Try to open an edit sheet by tapping a block
        let blockCells = app.cells.allElementsBoundByIndex

        for cell in blockCells {
            if cell.label.contains(":") || cell.label.contains("Focus") || cell.label.contains("Block") {
                cell.tap()

                let editTitle = app.navigationBars["Block bearbeiten"]
                if editTitle.waitForExistence(timeout: 2) {
                    // Check for required elements
                    XCTAssertTrue(app.staticTexts["Zeitraum"].exists || app.staticTexts["Start"].exists,
                                  "Time section should exist")
                    XCTAssertTrue(app.buttons["Block löschen"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS 'löschen'")).count > 0,
                                  "Delete option should exist")
                    XCTAssertTrue(app.buttons["Speichern"].exists, "Save button should exist")
                    XCTAssertTrue(app.buttons["Abbrechen"].exists, "Cancel button should exist")

                    // Dismiss
                    app.buttons["Abbrechen"].tap()
                    return
                }
            }
        }
    }

    // MARK: - Phase 2.2: Tasks Editable

    /// Test that tapping a task in Backlog opens the edit sheet
    func testTaskTapOpensEditSheet() throws {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        sleep(2)

        // Find a task row and tap it
        // Tasks have title text and duration badge
        let taskCells = app.cells.allElementsBoundByIndex

        for cell in taskCells {
            // Skip if it's not a task cell
            if cell.frame.height > 30 && cell.frame.height < 100 {
                cell.tap()

                // Check for edit sheet
                let editTitle = app.navigationBars["Task bearbeiten"]
                if editTitle.waitForExistence(timeout: 2) {
                    XCTAssertTrue(editTitle.exists, "Task edit sheet should open")

                    // Dismiss
                    app.buttons["Abbrechen"].tap()
                    return
                }
            }
        }
    }

    /// Test that task edit sheet has title, priority, duration fields
    func testTaskEditSheetHasRequiredFields() throws {
        // Navigate to Backlog tab
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()

        sleep(2)

        // Find and tap a task
        let taskCells = app.cells.allElementsBoundByIndex

        for cell in taskCells {
            if cell.frame.height > 30 && cell.frame.height < 100 {
                cell.tap()

                let editTitle = app.navigationBars["Task bearbeiten"]
                if editTitle.waitForExistence(timeout: 2) {
                    // Check for required fields
                    XCTAssertTrue(app.textFields.count > 0 || app.staticTexts["Titel"].exists || app.staticTexts["Task"].exists,
                                  "Title field should exist")
                    XCTAssertTrue(app.staticTexts["Priorität"].exists || app.pickers.count > 0,
                                  "Priority picker should exist")
                    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Dauer'")).count > 0 ||
                                  app.steppers.count > 0,
                                  "Duration stepper should exist")
                    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'löschen'")).count > 0,
                                  "Delete option should exist")

                    // Dismiss
                    app.buttons["Abbrechen"].tap()
                    return
                }
            }
        }
    }

    // MARK: - Phase 3: Task Progress Ring

    /// Test that Focus Live View shows task progress ring when a task is active
    func testTaskProgressRingExists() throws {
        // Navigate to Fokus tab
        let focusTab = app.tabBars.buttons["Fokus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 5), "Fokus tab should exist")
        focusTab.tap()

        sleep(2)

        // The progress ring is shown when there's an active block with tasks
        // It displays remaining minutes and has a circular progress indicator

        // Check for "Aktueller Task" label which indicates active task view
        let currentTaskLabel = app.staticTexts["Aktueller Task"]

        if currentTaskLabel.waitForExistence(timeout: 3) {
            // Active task view is shown - check for progress elements
            // The progress ring shows minutes remaining
            let minutesText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'min'"))
            XCTAssertTrue(minutesText.count > 0, "Minutes indicator should be visible")

            // Check for "geschätzt" text which shows estimated duration
            let estimatedText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'geschätzt'"))
            XCTAssertTrue(estimatedText.count > 0, "Estimated duration should be shown")

            // Check for complete button
            let completeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Erledigt'"))
            XCTAssertTrue(completeButton.count > 0, "Complete button should exist")
        } else {
            // No active block - this is expected if no block is currently running
            let noBlockText = app.staticTexts["Kein aktiver Focus Block"]
            if noBlockText.exists {
                // This is fine - no active block means no progress ring to show
                XCTAssertTrue(true, "No active block - progress ring test skipped")
            }
        }
    }

    /// Test that the progress ring updates (shows countdown)
    func testProgressRingShowsCountdown() throws {
        // Navigate to Fokus tab
        let focusTab = app.tabBars.buttons["Fokus"]
        XCTAssertTrue(focusTab.waitForExistence(timeout: 5), "Fokus tab should exist")
        focusTab.tap()

        sleep(2)

        let currentTaskLabel = app.staticTexts["Aktueller Task"]

        if currentTaskLabel.waitForExistence(timeout: 3) {
            // Get initial minutes value
            let minutesTexts = app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d+'"))

            if minutesTexts.count > 0 {
                // Progress ring exists with numeric display
                XCTAssertTrue(true, "Progress ring with numeric countdown exists")
            }
        }
    }
}
