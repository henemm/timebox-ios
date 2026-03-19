//
//  FocusBloxMacUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for macOS App — Task Creation via (+) Button + Sheet
//

import XCTest

final class FocusBloxMacUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "App-Window muss erscheinen")

        let toolbar = app.toolbars.firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 10), "Toolbar muss erscheinen")

        Thread.sleep(forTimeInterval: 2)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Task Creation Tests

    /// Test: (+) Button oeffnet Sheet mit Titel-TextField
    @MainActor
    func testNewTaskSheetAcceptsInput() throws {
        let addButton = app.buttons["macAddTaskButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "macAddTaskButton muss existieren")
        addButton.click()

        let sheet = app.windows.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Sheet muss erscheinen")

        let titleField = sheet.textFields["taskTitle"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Titel-Feld muss existieren")

        titleField.click()
        let testText = "Test Task \(Int.random(in: 1000...9999))"
        titleField.typeText(testText)

        let value = titleField.value as? String ?? ""
        XCTAssertEqual(value, testText, "TextField sollte '\(testText)' enthalten")
    }

    /// Test: Task kann via Erstellen-Button erstellt werden
    @MainActor
    func testCreateTaskViaSheet() throws {
        let addButton = app.buttons["macAddTaskButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "macAddTaskButton muss existieren")
        addButton.click()

        let sheet = app.windows.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Sheet muss erscheinen")

        let titleField = sheet.textFields["taskTitle"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Titel-Feld muss existieren")

        titleField.click()
        let taskTitle = "UI Test Task \(Int.random(in: 1000...9999))"
        titleField.typeText(taskTitle)

        // macOS: Button via Label finden (accessibilityIdentifier nicht immer zuverlaessig in Sheets)
        let createButton = app.buttons["Erstellen"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 3), "Erstellen-Button muss existieren")
        createButton.click()

        // Sheet muss geschlossen sein
        XCTAssertFalse(sheet.waitForExistence(timeout: 3), "Sheet sollte nach Erstellen geschlossen sein")

        // Task sollte in der Liste erscheinen
        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(taskInList.waitForExistence(timeout: 10), "Task sollte in Liste erscheinen")
    }
}
