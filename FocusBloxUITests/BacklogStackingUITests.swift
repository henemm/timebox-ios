import XCTest

final class BacklogStackingUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helper

    private func navigateToBacklogPriority() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
    }

    /// Scrollt die Backlog-Liste mehrmals nach unten, um Lazy-Rendered Items
    /// (recurring stacks in unteren Sektionen) sichtbar/findbar zu machen.
    @discardableResult
    private func scrollBacklogToFindCounterBar() -> Bool {
        let counterBars = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingCounterBar_'")
        )
        if counterBars.firstMatch.waitForExistence(timeout: 2) { return true }

        let list = app.collectionViews["backlogTaskList"]
        if !list.waitForExistence(timeout: 5) { return counterBars.firstMatch.exists }

        for _ in 0..<8 {
            list.swipeUp()
            if counterBars.firstMatch.exists { return true }
        }
        return counterBars.firstMatch.exists
    }

    // MARK: - TEST_01: Stacking Counter-Bar wird angezeigt

    /// Verhalten: Wenn eine recurring Serie 2+ offene Instanzen hat, wird oben an der Card
    /// eine Counter-Bar gerendert ("⚠ N× AUFGELAUFEN — seit ...").
    /// Bricht wenn: BacklogRow keine StackingCounterBar rendert bei stackedInstanceCount >= 2.
    func test_stackingCounterBar_showsCountForMultipleInstances() {
        navigateToBacklogPriority()
        XCTAssertTrue(scrollBacklogToFindCounterBar(),
            "Counter-Bar muss fuer gestackte Tasks existieren (nach Scroll)")
    }

    // MARK: - TEST_02: Counter-Bar Label enthaelt N und 'AUFGELAUFEN'

    /// Verhalten: Die Counter-Bar enthaelt eine Zahl und das Wort "AUFGELAUFEN".
    func test_counterBar_labelHasCountAndAufgelaufen() {
        navigateToBacklogPriority()
        XCTAssertTrue(scrollBacklogToFindCounterBar(),
            "Counter-Bar muss existieren")

        let predicate = NSPredicate(
            format: "identifier BEGINSWITH 'stackingCounterBar_' AND label CONTAINS 'AUFGELAUFEN'"
        )
        let bar = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 3),
            "Counter-Bar muss 'AUFGELAUFEN' im Label tragen")

        let label = bar.label
        let containsNumber = label.range(of: #"\d+"#, options: .regularExpression) != nil
        XCTAssertTrue(containsNumber, "Counter-Bar Label muss eine Zahl enthalten: \(label)")
    }

    // MARK: - TEST_03: Kein Counter-Bar bei einzelner Instanz

    /// Verhalten: Eine einzelne recurring Instanz zeigt KEINE Counter-Bar.
    func test_singleRecurringInstance_noCounterBar() {
        navigateToBacklogPriority()

        let oneBar = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingCounterBar_' AND label CONTAINS '1× AUFGELAUFEN'")
        ).firstMatch
        XCTAssertFalse(oneBar.exists,
            "Einzelne Instanz darf KEINE '1× AUFGELAUFEN' Counter-Bar zeigen")
    }

    // MARK: - TEST_04: Counter-Bar verschwindet/aendert sich nach Completion

    /// Verhalten: Abhaken eines gestackten Repraesentanten reduziert die aufgelaufene Anzahl.
    func test_completeStackedTask_decrementsCounter() {
        navigateToBacklogPriority()

        if !scrollBacklogToFindCounterBar() {
            XCTFail("Keine Counter-Bar gefunden — Test nicht moeglich")
            return
        }

        let counterQuery = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingCounterBar_'")
        )

        let firstBar = counterQuery.firstMatch
        if !firstBar.waitForExistence(timeout: 5) {
            XCTFail("Keine Counter-Bar gefunden — Test nicht moeglich")
            return
        }

        let initialCount = counterQuery.count
        let barId = firstBar.identifier
        let taskId = String(barId.dropFirst("stackingCounterBar_".count))
        let completeButton = app.buttons["completeButton_\(taskId)"]

        if !completeButton.waitForExistence(timeout: 3) {
            XCTFail("Complete-Button nicht gefunden fuer Task \(taskId)")
            return
        }

        completeButton.tap()

        let pendingCheckbox = app.buttons["completeButton_\(taskId)"]
        XCTAssertTrue(pendingCheckbox.waitForExistence(timeout: 3),
            "Complete-Button bleibt sichtbar waehrend pending Completion")
        XCTAssertEqual(pendingCheckbox.label, "Erledigt",
            "Checkbox zeigt 'Erledigt' im Pending-State")

        let oldBarGone = counterQuery.element(matching:
            NSPredicate(format: "identifier == %@", barId)
        ).waitForNonExistence(timeout: 10)

        if oldBarGone { return }

        let currentBars = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingCounterBar_'")
        )
        XCTAssertTrue(currentBars.count != initialCount,
            "Counter-Bar-Anzahl muss sich nach Completion aendern")
    }

    // MARK: - TEST_05: Kein 'Instanzen seit'-Untertitel mehr (AK-3)

    /// Verhalten: Der frühere "X Instanzen seit"-Untertitel ist entfernt.
    func test_noLegacyInstancesSubtitle() {
        navigateToBacklogPriority()

        let legacySubtitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Instanzen seit'")
        ).firstMatch

        XCTAssertFalse(legacySubtitle.waitForExistence(timeout: 3),
            "Der alte 'Instanzen seit ...'-Untertitel darf nicht mehr existieren")
    }

    // MARK: - TEST_06: Counter-Bar fuer mindestens 2 Instanzen sichtbar

    /// Verhalten: Counter-Bar erscheint ab 2 Instanzen — Mocks haben x2 (group1) und x3 (group2).
    func test_counterBarExistsForTwoInstances() {
        navigateToBacklogPriority()
        _ = scrollBacklogToFindCounterBar()

        let twoBars = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingCounterBar_' AND label CONTAINS '2×'")
        )

        // Vielleicht ist die '2×' Counter-Bar weiter unten — weiter scrollen.
        let list = app.collectionViews["backlogTaskList"]
        var scrolls = 0
        while !twoBars.firstMatch.exists && scrolls < 10 {
            list.swipeUp()
            scrolls += 1
        }

        XCTAssertTrue(twoBars.firstMatch.exists,
            "Eine Counter-Bar mit '2×' muss existieren (Schwelle ab 2 Instanzen)")
    }
}
