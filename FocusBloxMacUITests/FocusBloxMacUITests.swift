//
//  FocusBloxMacUITests.swift
//  FocusBloxMacUITests
//
//  UI Tests for macOS App
//

import XCTest

final class FocusBloxMacUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for window to appear
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Task Creation Tests

    /// Test: TextField für neue Tasks existiert und akzeptiert Eingabe
    @MainActor
    func testNewTaskTextFieldAcceptsInput() throws {
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField sollte existieren")

        textField.click()

        let testText = "Test Task \(Int.random(in: 1000...9999))"
        textField.typeText(testText)

        let value = textField.value as? String ?? ""
        XCTAssertEqual(value, testText, "TextField sollte '\(testText)' enthalten")
    }

    /// Test: Task kann via Enter erstellt werden
    @MainActor
    func testCreateTaskViaEnter() throws {
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField sollte existieren")

        textField.click()

        let taskTitle = "UI Test Task \(Int.random(in: 1000...9999))"
        textField.typeText(taskTitle)
        textField.typeKey(.return, modifierFlags: [])

        // Nach Enter sollte das TextField leer sein
        Thread.sleep(forTimeInterval: 0.5)
        let valueAfter = textField.value as? String ?? ""
        XCTAssertTrue(valueAfter.isEmpty, "TextField sollte nach Enter leer sein")

        // Task sollte in der Liste erscheinen
        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(taskInList.waitForExistence(timeout: 3), "Task sollte in Liste erscheinen")
    }
}
