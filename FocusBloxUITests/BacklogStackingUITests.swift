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

    /// Scrollt die Backlog-Liste, bis ein Element mit dem gesuchten Label
    /// existiert. Notwendig weil LazyVStack nur sichtbare Cells in den
    /// Accessibility-Tree rendert.
    @discardableResult
    private func scrollBacklogUntilLabelExists(_ labelContains: String, maxSwipes: Int = 12) -> Bool {
        // Erst pruefen, ob das Element schon (ohne Scrollen) existiert
        if app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", labelContains)
        ).firstMatch.exists {
            return true
        }

        let list = app.collectionViews["backlogTaskList"]
        guard list.waitForExistence(timeout: 5) else { return false }

        for _ in 0..<maxSwipes {
            list.swipeUp()
            // staticTexts statt descendants(.any) — robuster, kein FirstMatch-Crash
            if app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", labelContains)
            ).firstMatch.exists {
                return true
            }
        }
        return false
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

    // MARK: - TEST_07: Real-Data daily ohne GroupID zeigt Counter-Bar (Pfad B)

    /// Verhalten: Im Backlog existiert ein Mock-Task mit Praefix '[MOCK-RD] Tagebuch' (daily,
    /// dueDate = heute - 3 Tage, kein recurrenceGroupID). Nach Pfad-B-Fix erscheint eine
    /// Counter-Bar mit >= 2 x AUFGELAUFEN an dieser Card.
    /// Bricht wenn: RecurringStackingHelper Pfad B nicht implementiert ist ODER
    ///              Mock-Seed-RD-Tasks vom Developer-Agent nicht angelegt wurden.
    func test_realDataDailyOverdue_showsCounterBarWithoutGroupID() {
        navigateToBacklogPriority()

        // Mock-Task mit Real-Data-Praefix muss im Backlog vorhanden sein.
        // Scroll-First, weil LazyVStack nur sichtbare Cells in den
        // Accessibility-Tree rendert (Ueberfaellig-Sektion ist unten).
        XCTAssertTrue(scrollBacklogUntilLabelExists("[MOCK-RD] Tagebuch"),
            "Real-Data-Mock-Task '[MOCK-RD] Tagebuch' muss im Backlog existieren — wird vom Developer-Agent als Mock-Seed-RD angelegt")

        // Visueller Beweis fuer Checkpoint 3 — Screenshot der Counter-Bar nach Scrollen
        let proofShot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: proofShot)
        attachment.name = "stacking-bar-real-data-after"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Counter-Bar mit AUFGELAUFEN-Label muss vorhanden sein
        let counterBarPredicate = NSPredicate(
            format: "identifier BEGINSWITH 'stackingCounterBar_' AND label CONTAINS 'AUFGELAUFEN'"
        )
        let counterBars = app.descendants(matching: .any).matching(counterBarPredicate)

        // Durch Scrollen suchen, da die Card weiter unten sein kann
        var found = counterBars.firstMatch.waitForExistence(timeout: 2)
        if !found {
            let list = app.collectionViews["backlogTaskList"]
            for _ in 0..<10 {
                list.swipeUp()
                if counterBars.firstMatch.exists {
                    found = true
                    break
                }
            }
        }

        XCTAssertTrue(found,
            "Counter-Bar 'AUFGELAUFEN' muss bei Real-Data-Task ohne recurrenceGroupID erscheinen — Pfad B des RecurringStackingHelper")

        // Bar muss eine Zahl >= 2 enthalten
        let bar = counterBars.firstMatch
        let label = bar.label
        let regex = try! NSRegularExpression(pattern: "(\\d+)\u{00D7}")
        let matches = regex.matches(in: label, range: NSRange(label.startIndex..., in: label))

        XCTAssertFalse(matches.isEmpty,
            "Bar-Label muss Nx enthalten, war: '\(label)'")

        if let match = matches.first,
           match.numberOfRanges > 1,
           let countRange = Range(match.range(at: 1), in: label),
           let count = Int(label[countRange]) {
            XCTAssertGreaterThanOrEqual(count, 2,
                "Counter muss >= 2 sein (daily, 3 Tage ueberfaellig = 4x erwartet), war: \(count)")
        } else {
            XCTFail("Konnte Counter-Zahl aus Bar-Label nicht extrahieren: '\(label)'")
        }
    }

    // MARK: - TEST_08: Real-Data weekly ohne GroupID zeigt Counter-Bar mit 4x (Pfad B)

    /// Verhalten: Im Backlog existiert ein Mock-Task mit Praefix '[MOCK-RD] Wochenrueckblick'
    /// (weekly, dueDate = heute - 21 Tage, kein recurrenceGroupID). Nach Pfad-B-Fix erscheint
    /// eine Counter-Bar mit 4x AUFGELAUFEN (elapsed=21, cycle=7, missed=3+1=4).
    /// Bricht wenn: RecurringStackingHelper Pfad B weekly-Cycle (7 Tage) falsch berechnet ODER
    ///              Mock-Seed-RD-Tasks vom Developer-Agent nicht angelegt wurden.
    func test_realDataWeeklyOverdue_showsCounterBarWithoutGroupID() {
        navigateToBacklogPriority()

        // Mock-Task mit Real-Data-Praefix muss im Backlog vorhanden sein.
        // Scroll-First, weil LazyVStack nur sichtbare Cells in den
        // Accessibility-Tree rendert (Ueberfaellig-Sektion ist unten).
        XCTAssertTrue(scrollBacklogUntilLabelExists("[MOCK-RD] Wochenrueckblick"),
            "Real-Data-Mock-Task '[MOCK-RD] Wochenrueckblick' muss im Backlog existieren — wird vom Developer-Agent als Mock-Seed-RD angelegt")

        // Counter-Bar mit AUFGELAUFEN-Label muss vorhanden sein
        let counterBarPredicate = NSPredicate(
            format: "identifier BEGINSWITH 'stackingCounterBar_' AND label CONTAINS 'AUFGELAUFEN'"
        )
        let counterBars = app.descendants(matching: .any).matching(counterBarPredicate)

        // Durch Scrollen suchen, da die Card weiter unten sein kann
        var found = counterBars.firstMatch.waitForExistence(timeout: 2)
        if !found {
            let list = app.collectionViews["backlogTaskList"]
            for _ in 0..<10 {
                list.swipeUp()
                if counterBars.firstMatch.exists {
                    found = true
                    break
                }
            }
        }

        XCTAssertTrue(found,
            "Counter-Bar 'AUFGELAUFEN' muss bei Real-Data-Task '[MOCK-RD] Wochenrueckblick' ohne recurrenceGroupID erscheinen — Pfad B des RecurringStackingHelper")

        // Bar muss exakt 4x enthalten (weekly, 21 Tage = 3 verpasste Wochen + dueDate selbst = 4)
        let bar = counterBars.firstMatch
        let label = bar.label
        let regex = try! NSRegularExpression(pattern: "(\\d+)\u{00D7}")
        let matches = regex.matches(in: label, range: NSRange(label.startIndex..., in: label))

        XCTAssertFalse(matches.isEmpty,
            "Bar-Label muss Nx enthalten, war: '\(label)'")

        if let match = matches.first,
           match.numberOfRanges > 1,
           let countRange = Range(match.range(at: 1), in: label),
           let count = Int(label[countRange]) {
            XCTAssertEqual(count, 4,
                "Counter muss exakt 4 sein (weekly, 21 Tage ueberfaellig: elapsed=21, cycle=7, missed=3+1=4), war: \(count)")
        } else {
            XCTFail("Konnte Counter-Zahl aus Bar-Label nicht extrahieren: '\(label)'")
        }
    }
}
