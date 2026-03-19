//
//  MacUnifiedSearchUITests.swift
//  FocusBloxMacUITests
//
//  FEATURE_023: macOS Suche vereinheitlichen
//
//  Verifies:
//  1. Quick-Add inline TextField is REMOVED from backlog
//  2. (+) toolbar button exists and opens TaskFormSheet
//  3. Search (.searchable) still works
//

import XCTest

final class MacUnifiedSearchUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "App-Window muss erscheinen")

        // Wait for toolbar to be ready (more reliable than waiting for list)
        let toolbar = app.toolbars.firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 10), "Toolbar muss erscheinen")

        Thread.sleep(forTimeInterval: 2)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Quick-Add Bar entfernt

    /// Das alte Inline-TextField "Neuer Task..." darf NICHT mehr existieren.
    @MainActor
    func testQuickAddTextFieldDoesNotExist() throws {
        let quickAddField = app.textFields["newTaskTextField"]
        XCTAssertFalse(
            quickAddField.waitForExistence(timeout: 3),
            "FEATURE_023: Inline Quick-Add TextField darf nicht mehr existieren"
        )
    }

    // MARK: - (+) Toolbar-Button

    /// Ein (+) Button muss in der Toolbar existieren.
    @MainActor
    func testAddTaskToolbarButtonExists() throws {
        let addButton = app.buttons["macAddTaskButton"].firstMatch
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 5),
            "FEATURE_023: (+) Toolbar-Button muss existieren"
        )
    }

    /// Klick auf (+) oeffnet MacTaskCreateSheet.
    @MainActor
    func testAddTaskButtonOpensFormSheet() throws {
        let addButton = app.buttons["macAddTaskButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "macAddTaskButton muss existieren")

        addButton.click()

        // MacTaskCreateSheet hat accessibilityIdentifier "taskFormScrollView"
        let formSheet = app.windows.sheets.firstMatch
        XCTAssertTrue(
            formSheet.waitForExistence(timeout: 5),
            "FEATURE_023: MacTaskCreateSheet muss sich nach Klick auf (+) oeffnen"
        )
    }

    // MARK: - Inline-Suchfeld direkt über der Task-Liste

    /// FEATURE_023_v2: Inline-TextField mit accessibilityIdentifier "backlogSearchField"
    /// muss direkt über der Task-Liste existieren (nicht .searchable() in der Toolbar).
    /// Bricht wenn: ContentView.backlogView — .accessibilityIdentifier("backlogSearchField") fehlt
    @MainActor
    func testSearchFieldExists() throws {
        // FEATURE_023_v2: Inline-TextField (NICHT mehr .searchable() in der Toolbar)
        let searchField = app.textFields["backlogSearchField"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "FEATURE_023_v2: Inline-Suchfeld 'backlogSearchField' muss über der Task-Liste existieren"
        )
    }
}
