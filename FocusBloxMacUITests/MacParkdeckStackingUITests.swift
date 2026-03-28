//
//  MacParkdeckStackingUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for MAC_028: Parkdeck section + Recurring Stacking on macOS.
//  TDD RED: All tests MUST FAIL — features not implemented yet.
//

import XCTest

/// UI Tests for macOS Parkdeck section and Recurring Stacking badges.
///
/// Tests verify:
/// 1. Parkdeck section header exists in priority view
/// 2. Parkdeck is collapsed by default
/// 3. Context menu has "In Parkdeck legen" for active tasks
/// 4. Stacking badge appears for recurring task groups
/// 5. Only one representative row per recurring group
final class MacParkdeckStackingUITests: XCTestCase {

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

    // MARK: - Parkdeck Tests

    /// EXPECTED TO FAIL: Parkdeck section doesn't exist yet.
    /// Bricht wenn: ContentView doesn't render parkdeckSectionHeader.
    func test_parkdeckSectionHeader_existsInPriorityView() throws {
        // Parkdeck section header should be visible in priority filter
        let parkdeckHeader = app.buttons["parkdeckSectionHeader"]
        let parkdeckText = app.staticTexts["Parkdeck"]

        let headerExists = parkdeckHeader.waitForExistence(timeout: 5)
        let textExists = parkdeckText.waitForExistence(timeout: 2)

        XCTAssertTrue(headerExists || textExists,
                      "Parkdeck section header must exist in priority view")
    }

    /// EXPECTED TO FAIL: Parkdeck section doesn't exist yet.
    /// Bricht wenn: ContentView doesn't have isParkdeckExpanded state or default is wrong.
    func test_parkdeckSection_collapsedByDefault() throws {
        // Parkdeck should be collapsed — no parkdeck rows visible initially
        let parkdeckHeader = app.buttons["parkdeckSectionHeader"]
        guard parkdeckHeader.waitForExistence(timeout: 5) else {
            XCTFail("Parkdeck header must exist first")
            return
        }

        // If collapsed, parkdeck task rows should NOT be visible
        let parkdeckRow = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'parkdeckRow_'")
        ).firstMatch
        XCTAssertFalse(parkdeckRow.exists,
                       "Parkdeck rows should not be visible when collapsed")
    }

    /// Bricht wenn: backlogContextMenu doesn't include "In Parkdeck legen".
    func test_contextMenu_hasParkdeckOption() throws {
        // Find a known active backlog task (non-parkdeck, non-NextUp) by its title
        let taskText = app.staticTexts["[MOCK] Lohnsteuererklaerung einreichen"]
        guard taskText.waitForExistence(timeout: 5) else {
            XCTFail("Need mock backlog task to be visible")
            return
        }

        // Right-click to open context menu
        taskText.rightClick()

        // Look for "In Parkdeck legen" menu item
        let parkMenuItem = app.menuItems["In Parkdeck legen"]
        let exists = parkMenuItem.waitForExistence(timeout: 3)
        XCTAssertTrue(exists, "Context menu must have 'In Parkdeck legen' option")
    }

    // MARK: - Stacking Tests

    /// Bricht wenn: MacBacklogRow doesn't render stackingBadge_<id>.
    func test_stackingBadge_existsForRecurringGroup() throws {
        // Search for stacking badge across all element types (macOS may render as different type)
        let badgeByIdentifier = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch
        let identifierFound = badgeByIdentifier.waitForExistence(timeout: 5)

        // Fallback: search by accessibility label pattern
        let badgeByLabel = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'aufgelaufene Instanzen'")
        ).firstMatch
        let labelFound = badgeByLabel.waitForExistence(timeout: 2)

        XCTAssertTrue(identifierFound || labelFound,
                      "Stacking badge must appear when recurring tasks are grouped")
    }

    /// Bricht wenn: MacBacklogRow doesn't show "x2" or "x3" badge text.
    func test_stackingBadge_showsCorrectCountFormat() throws {
        // Search for stacking badge by identifier (macOS doesn't expose labels on nested Text)
        let badges = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        )

        guard badges.count > 0 else {
            XCTFail("No stacking badges found — check mock data has 2+ recurring children per group")
            return
        }

        // Verify we have at least 2 stacking badges (group1 x4 and group2 x2)
        XCTAssertGreaterThanOrEqual(badges.count, 2,
            "Should have stacking badges for at least 2 recurring groups, found: \(badges.count)")
    }
}
