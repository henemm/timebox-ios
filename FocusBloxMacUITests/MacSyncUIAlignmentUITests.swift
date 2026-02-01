//
//  MacSyncUIAlignmentUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for MAC-024: macOS Sync + UI Alignment
//

import XCTest

final class MacSyncUIAlignmentUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window to appear
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Sidebar Navigation Tests

    /// Test: Sidebar shows main sections (Backlog, Planen, Review)
    @MainActor
    func testSidebarSectionsExist() throws {
        let sidebarBacklog = app.staticTexts["sidebarSection_backlog"]
        let sidebarPlanning = app.staticTexts["sidebarSection_planning"]
        let sidebarReview = app.staticTexts["sidebarSection_review"]

        XCTAssertTrue(sidebarBacklog.waitForExistence(timeout: 5), "Backlog section should exist")
        XCTAssertTrue(sidebarPlanning.waitForExistence(timeout: 3), "Planning section should exist")
        XCTAssertTrue(sidebarReview.waitForExistence(timeout: 3), "Review section should exist")
    }

    /// Test: Sidebar shows filter section when Backlog is selected
    @MainActor
    func testSidebarFiltersExistInBacklog() throws {
        // Ensure we're on Backlog (default)
        let filterAll = app.staticTexts["sidebarFilter_all"]
        let filterNextUp = app.staticTexts["sidebarFilter_nextUp"]
        let filterTbd = app.staticTexts["sidebarFilter_tbd"]

        XCTAssertTrue(filterAll.waitForExistence(timeout: 5), "All filter should exist")
        XCTAssertTrue(filterNextUp.waitForExistence(timeout: 3), "Next Up filter should exist")
        XCTAssertTrue(filterTbd.waitForExistence(timeout: 3), "TBD filter should exist")
    }

    /// Test: Sidebar shows all 5 categories
    @MainActor
    func testSidebarCategoriesExist() throws {
        let categories = ["income", "maintenance", "recharge", "learning", "giving_back"]

        for category in categories {
            let categoryElement = app.staticTexts["sidebarCategory_\(category)"]
            XCTAssertTrue(categoryElement.waitForExistence(timeout: 3),
                          "Category '\(category)' should exist in sidebar")
        }
    }

    // MARK: - MacBacklogRow Badge Tests

    /// Test: Create a task and verify badges exist
    @MainActor
    func testTaskBadgesExist() throws {
        // Create a new task
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField should exist")

        textField.click()
        let taskTitle = "Badge Test Task \(Int.random(in: 1000...9999))"
        textField.typeText(taskTitle)
        textField.typeKey(.return, modifierFlags: [])

        // Wait for task to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Find task in list and check for badges
        // Note: We need to find the task row first, then check for badges within it
        let taskText = app.staticTexts[taskTitle]
        XCTAssertTrue(taskText.waitForExistence(timeout: 3), "Task should appear in list")

        // Check for badge elements (they should have accessibility identifiers)
        // The identifiers include the task ID, so we search for elements containing the pattern
        let importanceBadges = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'"))
        let urgencyBadges = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'"))
        let categoryBadges = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'categoryBadge_'"))
        let durationBadges = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'"))

        XCTAssertGreaterThan(importanceBadges.count, 0, "At least one importance badge should exist")
        XCTAssertGreaterThan(urgencyBadges.count, 0, "At least one urgency badge should exist")
        XCTAssertGreaterThan(categoryBadges.count, 0, "At least one category badge should exist")
        XCTAssertGreaterThan(durationBadges.count, 0, "At least one duration badge should exist")
    }

    // MARK: - TaskInspector Chip Tests

    /// Test: Select a task and verify inspector chips exist
    @MainActor
    func testInspectorChipsExist() throws {
        // Create a task first
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField should exist")

        textField.click()
        let taskTitle = "Inspector Test Task \(Int.random(in: 1000...9999))"
        textField.typeText(taskTitle)
        textField.typeKey(.return, modifierFlags: [])

        Thread.sleep(forTimeInterval: 0.5)

        // Click on the task to select it (should show inspector)
        let taskText = app.staticTexts[taskTitle]
        XCTAssertTrue(taskText.waitForExistence(timeout: 3), "Task should appear")
        taskText.click()

        Thread.sleep(forTimeInterval: 0.5)

        // Check for importance chips in inspector
        let importanceChip1 = app.buttons["importanceChip_1"]
        let importanceChip2 = app.buttons["importanceChip_2"]
        let importanceChip3 = app.buttons["importanceChip_3"]

        XCTAssertTrue(importanceChip1.waitForExistence(timeout: 3), "Importance chip 1 (Niedrig) should exist")
        XCTAssertTrue(importanceChip2.waitForExistence(timeout: 2), "Importance chip 2 (Mittel) should exist")
        XCTAssertTrue(importanceChip3.waitForExistence(timeout: 2), "Importance chip 3 (Hoch) should exist")

        // Check for urgency chips
        let urgencyChipNil = app.buttons["urgencyChip_nil"]
        let urgencyChipNotUrgent = app.buttons["urgencyChip_not_urgent"]
        let urgencyChipUrgent = app.buttons["urgencyChip_urgent"]

        XCTAssertTrue(urgencyChipNil.waitForExistence(timeout: 2), "Urgency chip (unset) should exist")
        XCTAssertTrue(urgencyChipNotUrgent.waitForExistence(timeout: 2), "Urgency chip (not urgent) should exist")
        XCTAssertTrue(urgencyChipUrgent.waitForExistence(timeout: 2), "Urgency chip (urgent) should exist")

        // Check for duration chips
        let durationChip15 = app.buttons["durationChip_15"]
        let durationChip30 = app.buttons["durationChip_30"]
        let durationChip60 = app.buttons["durationChip_60"]

        XCTAssertTrue(durationChip15.waitForExistence(timeout: 2), "Duration chip 15m should exist")
        XCTAssertTrue(durationChip30.waitForExistence(timeout: 2), "Duration chip 30m should exist")
        XCTAssertTrue(durationChip60.waitForExistence(timeout: 2), "Duration chip 60m should exist")
    }

    /// Test: Category grid in inspector has 5 items
    @MainActor
    func testInspectorCategoryGridExists() throws {
        // Create and select a task
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField should exist")

        textField.click()
        let taskTitle = "Category Grid Test \(Int.random(in: 1000...9999))"
        textField.typeText(taskTitle)
        textField.typeKey(.return, modifierFlags: [])

        Thread.sleep(forTimeInterval: 0.5)

        let taskText = app.staticTexts[taskTitle]
        XCTAssertTrue(taskText.waitForExistence(timeout: 3), "Task should appear")
        taskText.click()

        Thread.sleep(forTimeInterval: 0.5)

        // Check for category chips in inspector (only the 5 defined categories)
        let categories = ["income", "maintenance", "recharge", "learning", "giving_back"]

        for category in categories {
            let categoryChip = app.buttons["categoryChip_\(category)"]
            XCTAssertTrue(categoryChip.waitForExistence(timeout: 2),
                          "Category chip '\(category)' should exist in inspector")
        }
    }
}
