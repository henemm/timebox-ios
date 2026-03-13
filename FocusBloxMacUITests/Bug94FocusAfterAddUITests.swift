//
//  Bug94FocusAfterAddUITests.swift
//  FocusBloxMacUITests
//
//  Bug 94: macOS — Neuer Task ueber Eingabeschlitz bekommt keinen Fokus
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
        _ = window.waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Helper

    /// Creates a task via the quick-add text field and Return key.
    /// Returns the title used for the created task.
    @MainActor
    private func createTaskViaQuickAdd() -> String {
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "TextField muss existieren")

        textField.click()
        let taskTitle = "Bug94 Test \(Int.random(in: 1000...9999))"
        textField.typeText(taskTitle)

        // Use Return key — more reliable than button click in macOS UI tests
        textField.typeKey(.return, modifierFlags: [])

        // Wait for task to appear in list
        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(taskInList.waitForExistence(timeout: 8), "Task muss in Liste erscheinen")

        return taskTitle
    }

    // MARK: - Bug 94 Tests

    /// Bug 94: Nach Task-Erstellung muss der Inspector den neuen Task anzeigen
    /// — beweist dass der User den Task sofort sehen und bearbeiten kann.
    @MainActor
    func testNewTaskShowsInInspectorAfterCreation() throws {
        let taskTitle = createTaskViaQuickAdd()

        // Bug 94 Kern-Assertion: Inspector muss den neuen Task anzeigen.
        // TaskInspector zeigt den Titel in einem TextField an.
        // Wenn weder Selection noch Override funktioniert, zeigt Inspector "Kein Task ausgewaehlt".
        let inspectorTitle = app.textFields.matching(
            NSPredicate(format: "value == %@", taskTitle)
        ).firstMatch
        XCTAssertTrue(
            inspectorTitle.waitForExistence(timeout: 5),
            "Bug 94: Inspector muss den neuen Task anzeigen (Task sofort sichtbar)"
        )
    }

    /// Bug 94: "Kein Task ausgewaehlt" darf NICHT mehr sichtbar sein
    /// nachdem ein Task erstellt wurde — beweist dass der Empty State weg ist.
    @MainActor
    func testEmptyStateDisappearsAfterTaskCreation() throws {
        _ = createTaskViaQuickAdd()

        // Wait for Inspector to update — poll until empty state disappears
        let emptyState = app.staticTexts["Kein Task ausgewählt"]
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && emptyState.exists {
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertFalse(
            emptyState.exists,
            "Bug 94: 'Kein Task ausgewaehlt' darf nach Erstellung nicht mehr sichtbar sein"
        )
    }

    /// Bug 94: Nach Task-Erstellung muss der neue Task in der Accessibility-Hierarchie
    /// existieren — beweist dass refreshTasks() den neuen Task einschliesst.
    @MainActor
    func testNewTaskExistsInListAfterCreation() throws {
        let taskTitle = createTaskViaQuickAdd()

        // Task muss in der Accessibility-Hierarchie existieren
        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(
            taskInList.exists,
            "Bug 94: Neuer Task muss in der Liste existieren"
        )
    }
}
