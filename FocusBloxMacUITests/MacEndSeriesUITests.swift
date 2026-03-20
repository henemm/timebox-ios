import XCTest

/// Reproduziert den endSeries() Crash-Pfad:
/// "Wiederkehrend"-Filter → Template-Task Checkbox klicken → "Serie beenden?" Dialog → "Serie beenden" klicken
/// → Crash wenn task.recurrenceGroupID nach deleteRecurringTemplate() via SwiftData BackingData Fault
final class MacEndSeriesUITests: XCTestCase {

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

    private func navigateToRecurringFilter() {
        // Klickt auf "Wiederkehrend" in der Sidebar — zeigt Template-Tasks
        let recurringFilter = app.staticTexts["sidebarFilter_recurring"]
        if recurringFilter.waitForExistence(timeout: 3) {
            recurringFilter.click()
        } else {
            // Fallback: Label-Text direkt suchen
            let wiederkehrendLabel = app.staticTexts["Wiederkehrend"]
            if wiederkehrendLabel.waitForExistence(timeout: 3) {
                wiederkehrendLabel.click()
            }
        }
        Thread.sleep(forTimeInterval: 1)
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
        let exists = app.buttons[label].waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Confirmation Button '\(label)' muss erscheinen")
        app.windows.firstMatch.buttons[label].click()
    }

    /// GIVEN: macOS App mit Mock-Daten (Template-Task "[MOCK] Taeglich lesen")
    /// WHEN:  "Wiederkehrend"-Filter → Template-Checkbox klicken → "Serie beenden?" → "Serie beenden"
    /// THEN:  App crasht NICHT (kein SwiftData BackingData fault auf LocalTask.recurrenceGroupID)
    ///
    /// Bricht wenn: endSeries() liest task.recurrenceGroupID NACH deleteRecurringTemplate()
    @MainActor
    func test_endSeries_doesNotCrash() throws {
        navigateToBacklog()
        navigateToRecurringFilter()
        takeScreenshot(name: "01_WiederkehrendFilter_geladen")

        // Im "Wiederkehrend"-Filter sind Template-Tasks sichtbar
        let taskTitle = "[MOCK] Taeglich lesen"
        let taskCell = app.staticTexts[taskTitle]
        XCTAssertTrue(
            taskCell.waitForExistence(timeout: 5),
            "'\(taskTitle)' muss im Wiederkehrend-Filter sichtbar sein (isTemplate=true)"
        )

        takeScreenshot(name: "02_TemplateTask_gefunden")

        // Checkbox-Button finden: accessibilityIdentifier = "completeButton_<task.id>"
        // Da die ID nicht bekannt ist, suchen wir per Präfix-Predicate
        let completeButtonPredicate = NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        let completeButtons = app.buttons.matching(completeButtonPredicate)
        XCTAssertTrue(
            completeButtons.firstMatch.waitForExistence(timeout: 3),
            "completeButton_* muss für Template-Task existieren"
        )
        completeButtons.firstMatch.click()
        Thread.sleep(forTimeInterval: 1)

        takeScreenshot(name: "03_NachCheckboxKlick")

        // "Serie beenden?" Dialog muss erscheinen (taskToEndSeries = task wurde gesetzt)
        let endSeriesButton = app.buttons["Serie beenden"]
        if endSeriesButton.waitForExistence(timeout: 3) {
            takeScreenshot(name: "04_SerieBeendenDialog")

            // Klick — hier kann der Crash passieren:
            // endSeries(task) → deleteRecurringTemplate() → task gelöscht →
            // taskToEndSeries = nil (danach) → SwiftUI greift auf task.recurrenceGroupID zu
            clickConfirmationButton("Serie beenden")
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(name: "05_NachSerieBeenden_keinCrash")

            XCTAssertTrue(
                app.windows.firstMatch.exists,
                "App muss nach 'Serie beenden' noch laufen — kein SwiftData BackingData fault!"
            )
        } else {
            takeScreenshot(name: "04_KeinDialog_DebugState")
            XCTFail(
                "'Serie beenden?' Dialog ist nicht erschienen. " +
                "Bitte Screenshot 03 prüfen — im 'Wiederkehrend'-Filter sollte " +
                "ein Checkbox-Klick auf ein Template den Dialog auslösen."
            )
        }
    }
}
