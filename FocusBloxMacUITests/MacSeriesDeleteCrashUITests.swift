import XCTest

/// TDD RED: macOS Crash beim Löschen einer Serie → "Alle offenen dieser Serie"
///
/// Bug: Fatal error: This backing data was detached from a context without resolving
/// attribute faults: \LocalTask.tags
///
/// Reproduktionsschritte:
/// 1. Wiederkehrenden Task rechtsklicken
/// 2. "Löschen" wählen
/// 3. "Alle offenen dieser Serie" wählen
/// → App crasht mit SwiftData BackingData-Fehler auf LocalTask.tags
///
/// Diese Tests müssen FEHLSCHLAGEN (RED) bis der Fix implementiert ist.
final class MacSeriesDeleteCrashUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "App-Window muss erscheinen")
        Thread.sleep(forTimeInterval: 2)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Helpers

    private func navigateToBacklog() {
        let radioGroup = app.radioGroups["mainNavigationPicker"]
        if radioGroup.waitForExistence(timeout: 3) {
            let backlogButton = radioGroup.radioButtons["list.bullet"]
            if backlogButton.waitForExistence(timeout: 3) {
                backlogButton.click()
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }

    private func takeScreenshot(name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Klickt einen Button im Confirmation Dialog — vermeidet Touch Bar Elemente.
    ///
    /// macOS .confirmationDialog erstellt Touch Bar Repräsentationen seiner Buttons.
    /// app.buttons["X"].firstMatch findet den Touch Bar Button zuerst → click() schlägt fehl.
    /// Lösung: Button über app.windows.firstMatch suchen (Touch Bar liegt außerhalb des Window-Containers).
    private func clickConfirmationButton(_ label: String, timeout: TimeInterval = 3) {
        // Erst warten bis Button existiert (globale Suche für Existence-Check)
        let exists = app.buttons[label].waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Confirmation Button '\(label)' muss erscheinen")
        // Dann im Window-Kontext klicken (schließt Touch Bar aus)
        app.windows.firstMatch.buttons[label].click()
    }

    // MARK: - TDD RED Tests

    /// GIVEN: macOS App mit Mock-Daten (wiederkehrender Task "[MOCK] Taeglich lesen")
    /// WHEN:  Rechtsklick → "Löschen" → "Alle offenen dieser Serie"
    /// THEN:  App crasht NICHT (kein SwiftData BackingData fault auf LocalTask.tags)
    ///
    /// Bricht wenn: deleteRecurringSeries accessed task.tags nach modelContext.delete(task)
    @MainActor
    func test_deleteAllInSeries_doesNotCrash() throws {
        navigateToBacklog()
        takeScreenshot(name: "01_Backlog_geladen")

        // Finde den wiederkehrenden Mock-Task mit Tags
        let taskTitle = "[MOCK] Taeglich lesen"
        let taskCell = app.staticTexts[taskTitle]
        XCTAssertTrue(
            taskCell.waitForExistence(timeout: 5),
            "'\(taskTitle)' muss im Backlog sichtbar sein"
        )

        takeScreenshot(name: "02_RecurringTask_gefunden")

        // Rechtsklick → Context-Menu
        taskCell.rightClick()
        Thread.sleep(forTimeInterval: 0.5)

        takeScreenshot(name: "03_ContextMenu_geoeffnet")

        // "Löschen" im Context-Menu klicken
        let deleteMenuItem = app.menuItems["Löschen"]
        XCTAssertTrue(
            deleteMenuItem.waitForExistence(timeout: 3),
            "Context-Menu muss 'Löschen' enthalten"
        )
        deleteMenuItem.click()
        Thread.sleep(forTimeInterval: 0.5)

        takeScreenshot(name: "04_ConfirmationDialog_geoeffnet")

        // Confirmation Dialog: "Alle offenen dieser Serie"
        // Hinweis: clickConfirmationButton() vermeidet Touch Bar Elemente (macOS-Bug)
        clickConfirmationButton("Alle offenen dieser Serie")

        // Kurz warten — crash würde hier sofort passieren
        Thread.sleep(forTimeInterval: 1)

        takeScreenshot(name: "05_NachLoeschen_keinCrash")

        // Assert: App läuft noch (kein Crash)
        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "App muss nach 'Alle offenen dieser Serie' löschen noch laufen — kein SwiftData-Crash!"
        )
    }

    /// GIVEN: macOS App mit Mock-Daten (wöchentlicher Task "[MOCK] Wochenreview" mit tags)
    /// WHEN:  Rechtsklick → "Löschen" → "Alle offenen dieser Serie"
    /// THEN:  App crasht NICHT
    ///
    /// Bricht wenn: Crash bei anderem recurring Task mit tags
    @MainActor
    func test_deleteAllInSeries_weeklyTask_doesNotCrash() throws {
        navigateToBacklog()

        let taskTitle = "[MOCK] Wochenreview"
        let taskCell = app.staticTexts[taskTitle]
        XCTAssertTrue(
            taskCell.waitForExistence(timeout: 5),
            "'\(taskTitle)' muss im Backlog sichtbar sein"
        )

        takeScreenshot(name: "06_WeeklyTask_gefunden")

        taskCell.rightClick()
        Thread.sleep(forTimeInterval: 0.5)

        let deleteMenuItem = app.menuItems["Löschen"]
        XCTAssertTrue(
            deleteMenuItem.waitForExistence(timeout: 3),
            "Context-Menu 'Löschen' muss erscheinen"
        )
        deleteMenuItem.click()
        Thread.sleep(forTimeInterval: 0.5)

        clickConfirmationButton("Alle offenen dieser Serie")

        Thread.sleep(forTimeInterval: 1)

        takeScreenshot(name: "07_WeeklySerieGeloescht_keinCrash")

        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "App muss nach Löschen des Weekly-Tasks noch laufen"
        )
    }

    /// GIVEN: macOS App mit Mock-Daten (wiederkehrender Task)
    /// WHEN:  Rechtsklick → "Löschen" → "Nur diese Aufgabe"
    /// THEN:  App crasht NICHT (Kontrolle: dieser Pfad sollte nicht crashen)
    ///
    /// Bricht wenn: auch der Einzel-Delete crasht
    @MainActor
    func test_deleteSingleFromSeries_doesNotCrash() throws {
        navigateToBacklog()

        let taskTitle = "[MOCK] Taeglich lesen"
        let taskCell = app.staticTexts[taskTitle]
        XCTAssertTrue(
            taskCell.waitForExistence(timeout: 5),
            "'\(taskTitle)' muss im Backlog sichtbar sein"
        )

        taskCell.rightClick()
        Thread.sleep(forTimeInterval: 0.5)

        let deleteMenuItem = app.menuItems["Löschen"]
        XCTAssertTrue(
            deleteMenuItem.waitForExistence(timeout: 3),
            "Context-Menu 'Löschen' muss erscheinen"
        )
        deleteMenuItem.click()
        Thread.sleep(forTimeInterval: 0.5)

        clickConfirmationButton("Nur diese Aufgabe")

        Thread.sleep(forTimeInterval: 1)

        takeScreenshot(name: "08_EinzelDelete_keinCrash")

        XCTAssertTrue(
            app.windows.firstMatch.exists,
            "App muss nach 'Nur diese Aufgabe' löschen noch laufen"
        )
    }
}
