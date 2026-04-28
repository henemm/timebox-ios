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

    /// Bug 279 — Beweis: Wenn Recurring-Group 2+ offene Children hat, muss
    /// der Stacking-Badge mit `accessibilityIdentifier == 'stackingBadge_<id>'` rendern.
    /// **Anti-Silent-Pass:** KEIN OR-Fallback auf labels — nur strikte Identifier-Pruefung.
    /// Bricht wenn: MacBacklogRow rendert kein stackingBadge_<id>.
    func test_stackingBadge_existsForRecurringGroup() throws {
        let badge = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch

        XCTAssertTrue(
            badge.waitForExistence(timeout: 5),
            "Bug 279 — Stacking-Badge mit identifier 'stackingBadge_<id>' fehlt. " +
            "Mock-Daten haben gestackte Recurring-Tasks; macOS-MacBacklogRow rendert kein StackingBadge."
        )
    }

    /// Bug 279 — Beweis: Mock-Daten Series 2 hat 3 offene Children → Badge "x3" muss da sein.
    /// (Mock-Daten in FocusBloxApp.swift sind shared zwischen iOS und macOS.)
    /// Bricht wenn: applyStacking() setzt count nicht oder MacBacklogRow rendert label nicht.
    func test_stackingBadge_showsLabelX3_forThreeInstances() throws {
        let badgeX3 = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'x3' AND identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch

        XCTAssertTrue(
            badgeX3.waitForExistence(timeout: 5),
            "Bug 279 — Series 2 'Wochenreview' hat 3 offene Children, Badge 'x3' muss sichtbar sein."
        )
    }

    /// Bug 279 — Beweis: Mock-Daten Series 1 hat 2 offene Children → Badge "x2" muss da sein
    /// (Spec: ab 2 Instanzen sichtbar, nicht erst ab 3).
    /// Bricht wenn: Stacking-Schwelle ist >= 3 statt >= 2 ODER Logik gruppiert nicht.
    func test_stackingBadge_showsLabelX2_forTwoInstances() throws {
        let badgeX2 = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'x2' AND identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch

        XCTAssertTrue(
            badgeX2.waitForExistence(timeout: 5),
            "Bug 279 — Series 1 'Taeglich lesen' hat 2 offene Children, Badge 'x2' muss sichtbar sein " +
            "(Spec: ab 2 Instanzen, nicht erst ab 3)."
        )
    }

    /// Bug 279 — Beweis: 3 Instanzen derselben Serie erscheinen als EINE Row, nicht 3.
    /// Bricht wenn: macOS-Backlog gruppiert nicht nach recurrenceGroupID.
    func test_stackedSeries_rendersAsSingleRow() throws {
        let wochenreviewRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == '[MOCK] Wochenreview'")
        )

        // Warte kurz, damit die Liste geladen ist
        let firstAnchor = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS '[MOCK]'")
        ).firstMatch
        _ = firstAnchor.waitForExistence(timeout: 5)

        XCTAssertEqual(
            wochenreviewRows.count, 1,
            "Bug 279 — Wochenreview muss als EINE gestackte Row erscheinen, nicht als \(wochenreviewRows.count) separate Rows."
        )
    }
}
