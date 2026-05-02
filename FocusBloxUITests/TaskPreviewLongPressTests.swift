import XCTest

/// Tests für Feature #300 — Long Press: Task-Preview-Karte
///
/// Verhalten: Ein langer Fingerdruck auf einen Task öffnet eine Read-only-Preview-Karte.
/// Die Karte trägt den AccessibilityIdentifier "taskPreviewCard".
///
/// ERWARTET FEHLSCHLAGEN (TDD RED): TaskPreviewView hat noch kein
/// .accessibilityIdentifier("taskPreviewCard") — deshalb schlägt
/// waitForExistence(timeout:) fehl und alle vier Tests sind RED.
final class TaskPreviewLongPressTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -UITesting aktiviert Mock-Daten (mindestens 1 Backlog-Task,
        // 1 Abgeschlossen-Task, 1 Scheduled-Task)
        app.launchArguments = ["-UITesting"]
        // launch() pro Test, weil Coach-Tests --coach-tab-layout brauchen
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func navigateTo(_ tabLabel: String) {
        let tab = app.tabBars.firstMatch.buttons[tabLabel]
        XCTAssertTrue(tab.waitForExistence(timeout: 5),
                      "Tab '\(tabLabel)' muss existieren")
        tab.tap()
    }

    private func firstElement(withIdentifierPrefix prefix: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Setzt den Backlog-ViewMode explizit auf das gewuenschte Label.
    /// AppStorage("backlogViewMode") persistiert zwischen Test-Runs — deshalb
    /// muss jeder Test seinen Mode aktiv setzen, statt sich auf einen Default zu verlassen.
    private func selectBacklogViewMode(_ label: String) {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5),
                      "viewModeSwitcher muss existieren")
        // Wenn der Mode bereits aktiv ist, ist nichts zu tun.
        if switcher.label == label { return }
        switcher.tap()
        // Mehrere Elemente koennen den Identifier "<label>" tragen
        // (Switcher-Label + Menue-Eintrag). Wir nehmen den letzten, das ist der Menue-Eintrag.
        let candidates = app.buttons.matching(identifier: label)
        let waitDeadline = Date().addingTimeInterval(3)
        while candidates.count == 0 && Date() < waitDeadline {
            usleep(100_000)
        }
        let count = candidates.count
        XCTAssertGreaterThan(count, 0, "ViewMode-Option '\(label)' muss im Menue erscheinen")
        let menuOption = count > 1
            ? candidates.element(boundBy: count - 1)
            : candidates.firstMatch
        XCTAssertTrue(menuOption.waitForExistence(timeout: 3),
                      "ViewMode-Option '\(label)' muss im Menue erscheinen")
        menuOption.tap()
    }

    // MARK: - Tests

    /// Verhalten: Langer Druck auf eine BacklogRow in der Hauptliste zeigt die Preview-Karte.
    /// Bricht wenn: BacklogView.swift hat kein `preview: { TaskPreviewView(task:) }`
    ///              im .contextMenu der Hauptlisten-BacklogRow ODER
    ///              TaskPreviewView hat kein .accessibilityIdentifier("taskPreviewCard").
    func testBacklogMainListLongPressShowsPreview() throws {
        app.launch()
        navigateTo("Backlog")

        // Sicherstellen, dass Priority-View aktiv ist (AppStorage kann auf "Erledigt" stehen)
        selectBacklogViewMode("Priorität")

        let firstRow = firstElement(withIdentifierPrefix: "taskTitle_")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5),
                      "Mindestens eine BacklogRow (taskTitle_*) muss sichtbar sein — Mock-Daten fehlen?")

        firstRow.press(forDuration: 1.0)

        let previewCard = app.descendants(matching: .any)["taskPreviewCard"]
        XCTAssertTrue(previewCard.waitForExistence(timeout: 3),
                      "Long Press auf BacklogRow muss taskPreviewCard anzeigen")
    }

    /// Verhalten: Langer Druck auf eine abgeschlossene Task-Row zeigt dieselbe Preview-Karte.
    /// Bricht wenn: BacklogView.swift hat kein `preview:` im .contextMenu der
    ///              Abgeschlossen-Sektion ODER TaskPreviewView hat keinen Identifier.
    func testBacklogCompletedListLongPressShowsPreview() throws {
        app.launch()
        navigateTo("Backlog")

        // ViewMode-Switcher auf "Erledigt" setzen.
        selectBacklogViewMode("Erledigt")

        let firstCompleted = firstElement(withIdentifierPrefix: "completedTaskRow_")
        XCTAssertTrue(firstCompleted.waitForExistence(timeout: 5),
                      "Mindestens eine completedTaskRow_* muss sichtbar sein — Mock-Daten fehlen?")

        firstCompleted.press(forDuration: 1.0)

        let previewCard = app.descendants(matching: .any)["taskPreviewCard"]
        XCTAssertTrue(previewCard.waitForExistence(timeout: 3),
                      "Long Press auf abgeschlossene TaskRow muss taskPreviewCard anzeigen")
    }

    /// Verhalten: Langer Druck auf eine BacklogRow im Coach-Tab zeigt die Preview-Karte.
    /// Bricht wenn: CoachView.swift hat kein `preview:` im .contextMenu der BacklogRow ODER
    ///              TaskPreviewView hat keinen Identifier.
    /// Hinweis: Coach-Layout wird via --coach-tab-layout aktiviert.
    func testCoachBacklogLongPressShowsPreview() throws {
        app.launchArguments.append("--coach-tab-layout")
        app.launch()
        navigateTo("Coach")

        let firstRow = firstElement(withIdentifierPrefix: "taskTitle_")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5),
                      "Mindestens eine BacklogRow (taskTitle_*) im Coach-Tab muss sichtbar sein — Mock-Daten fehlen?")

        firstRow.press(forDuration: 1.0)

        let previewCard = app.descendants(matching: .any)["taskPreviewCard"]
        XCTAssertTrue(previewCard.waitForExistence(timeout: 3),
                      "Long Press auf Coach-BacklogRow muss taskPreviewCard anzeigen")
    }

    /// Verhalten: Langer Druck auf einen Tagesplan-Block im Blox-Tab zeigt die Preview-Karte.
    /// Bricht wenn: ScheduledTaskBlock.swift hat kein `preview:` im .contextMenu ODER
    ///              TaskPreviewView hat keinen Identifier ODER
    ///              PositionedScheduledTask/BlockPlanningView/TimelineView geben kein PlanItem weiter.
    func testScheduledTaskBlockLongPressShowsPreview() throws {
        app.launch()
        navigateTo("Blox")

        // Warte auf Timeline-Container (analog ScheduledTaskBlockUITests)
        _ = app.scrollViews["planningTimeline"].waitForExistence(timeout: 5)

        let firstBlock = firstElement(withIdentifierPrefix: "scheduledTaskBlock_")
        XCTAssertTrue(firstBlock.waitForExistence(timeout: 5),
                      "Mindestens ein scheduledTaskBlock_* muss sichtbar sein — Mock-Daten fehlen?")

        firstBlock.press(forDuration: 1.0)

        let previewCard = app.descendants(matching: .any)["taskPreviewCard"]
        XCTAssertTrue(previewCard.waitForExistence(timeout: 3),
                      "Long Press auf scheduledTaskBlock muss taskPreviewCard anzeigen")
    }
}
