//
//  Bug94FocusAfterAddUITests.swift
//  FocusBloxMacUITests
//
//  Bug 94: macOS — Neuer Task ueber Eingabeschlitz bekommt keinen Fokus
//
//  Root Cause: addTask() wartet auf async AI-Enrichment (3-8 Sek.)
//  BEVOR der Inspector-Override gesetzt wird. Der User sieht solange
//  "Kein Task ausgewaehlt".
//
//  Fix: Task sofort erstellen + Inspector-Override SOFORT setzen,
//  AI-Enrichment im Hintergrund nachlaufen lassen.
//

import XCTest

final class Bug94FocusAfterAddUITests: XCTestCase {
    var app: XCUIApplication!
    private var createdTaskTitle: String?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Warten bis App vollstaendig geladen ist
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "App-Window muss erscheinen")

        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(
            textField.waitForExistence(timeout: 10),
            "Quick-Add TextField muss bereit sein bevor Tests starten"
        )

        // Warten bis .task { refreshTasks() } + Mock-Daten-Seeding abgeschlossen
        Thread.sleep(forTimeInterval: 3)
    }

    override func tearDownWithError() throws {
        // Kein explizites Loeschen noetig — App verwendet in-memory Store
        // bei UI-Tests (-UITesting). Jeder Test startet mit frischen Daten.
        // Falls Tasks in die Produktion leaken: cleanupLeakedTestData()
        // erkennt den [TEST] Prefix und raeumt auf.
        app?.terminate()
        app = nil
        createdTaskTitle = nil
    }

    // MARK: - Helper

    /// Creates a task via the quick-add text field and Return key.
    /// Title is clearly marked as test data with [TEST] prefix.
    @MainActor
    private func createTaskViaQuickAdd() -> String {
        let textField = app.textFields["newTaskTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Quick-Add TextField muss existieren")

        textField.click()
        let taskTitle = "[TEST] Bug94 \(Int.random(in: 1000...9999))"
        textField.typeText(taskTitle)
        textField.typeKey(.return, modifierFlags: [])

        // Warten bis Task in der Liste erscheint
        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(taskInList.waitForExistence(timeout: 10), "Task muss in Liste erscheinen")

        createdTaskTitle = taskTitle
        return taskTitle
    }

    // MARK: - Bug 94 Kern-Tests

    /// Bug 94: Inspector muss den neuen Task INNERHALB von 2 Sekunden anzeigen.
    ///
    /// Vor dem Fix: Inspector zeigt Task erst nach 3-8 Sek. (AI-Enrichment).
    /// Nach dem Fix: Inspector zeigt Task sofort (< 2 Sek.).
    ///
    /// Bricht wenn: addTask() den Inspector-Override erst nach AI-Enrichment setzt.
    @MainActor
    func testNewTaskShowsInInspectorWithin2Seconds() throws {
        let taskTitle = createTaskViaQuickAdd()

        // 2 Sekunden Timeout — der Inspector MUSS sofort reagieren.
        // Vor dem Fix dauert es 3-8 Sekunden (AI-Enrichment blockiert),
        // daher wird dieser Test FEHLSCHLAGEN bis der Fix implementiert ist.
        let inspectorTitle = app.textFields.matching(
            NSPredicate(format: "value == %@", taskTitle)
        ).firstMatch
        XCTAssertTrue(
            inspectorTitle.waitForExistence(timeout: 2),
            "Bug 94: Inspector muss den neuen Task SOFORT anzeigen (max 2 Sek.), nicht erst nach AI-Enrichment"
        )
    }

    /// Basis-Test: Task existiert in der Liste nach Erstellung.
    @MainActor
    func testNewTaskExistsInListAfterCreation() throws {
        let taskTitle = createTaskViaQuickAdd()

        let taskInList = app.staticTexts[taskTitle]
        XCTAssertTrue(
            taskInList.exists,
            "Task muss in der Accessibility-Hierarchie existieren"
        )
    }
}
