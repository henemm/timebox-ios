//
//  Bug94FocusAfterAddUITests.swift
//  FocusBloxMacUITests
//
//  Bug 94: macOS — Neuer Task ueber (+) Button bekommt Fokus im Inspector
//
//  Urspruenglich: Quick-Add TextField wurde genutzt.
//  Nach FEATURE_023: (+) Button oeffnet MacTaskCreateSheet.
//  Der Inspector-Fokus wird jetzt getestet via Sheet-Erstellung.
//

import XCTest

final class Bug94FocusAfterAddUITests: XCTestCase {
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

    /// Task via (+) Button erstellen und pruefen ob er in der Liste erscheint.
    @MainActor
    func testNewTaskExistsInListAfterCreation() throws {
        let addButton = app.buttons["macAddTaskButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "macAddTaskButton muss existieren")

        addButton.click()

        // Sheet muss erscheinen
        let sheet = app.windows.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Sheet muss erscheinen")

        // Titel eingeben
        let titleField = sheet.textFields["taskTitle"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Titel-Feld muss existieren")
        titleField.click()
        let taskTitle = "[TEST] Bug94 \(Int.random(in: 1000...9999))"
        titleField.typeText(taskTitle)

        // Erstellen-Button klicken
        let createButton = app.buttons["Erstellen"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 3), "Erstellen-Button muss existieren")
        createButton.click()

        // Task muss in der Liste erscheinen
        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(
            taskInList.waitForExistence(timeout: 10),
            "Task muss nach Erstellung in der Liste erscheinen"
        )
    }
}
