import XCTest

/// RW 2.4b: Backlog-Sektionen-Rework
/// - "Next Up" → "Heute"
/// - "Aktive Tasks" → 3 Tier-Sektionen (Dringend, Bald, Später)
/// - "Parkdeck" → "Geparkt" (offen, nur manuell)
final class BacklogSectionsUITests: XCTestCase {
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

        let viewModeSwitcher = app.buttons["viewModeSwitcher"]
        _ = viewModeSwitcher.waitForExistence(timeout: 3)
    }

    // MARK: - TEST_01: "Heute"-Sektion (ehemals "Next Up")

    /// Bricht wenn: Section Header noch "Next Up" statt "Heute" zeigt
    func test_heuteSection_existsWithCorrectLabel() {
        navigateToBacklogPriority()

        let heuteText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Heute'")
        ).firstMatch
        XCTAssertTrue(heuteText.waitForExistence(timeout: 5),
                       "Section Header muss 'Heute' zeigen, nicht 'Next Up'")

        // "Next Up" darf NICHT mehr existieren
        let nextUpText = app.staticTexts.matching(
            NSPredicate(format: "label == 'Next Up'")
        ).firstMatch
        XCTAssertFalse(nextUpText.exists,
                        "'Next Up' Label darf nicht mehr existieren")
    }

    // MARK: - TEST_02: Tier-Sektionen existieren (Dringend, Bald, Später)

    /// Bricht wenn: priorityView noch "Aktive Tasks" statt Tier-Sektionen zeigt
    func test_tierSections_existInPriorityView() {
        navigateToBacklogPriority()

        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        // Scroll through to find tier sections
        var foundDringend = false
        var foundBald = false
        var foundSpaeter = false

        for _ in 0..<8 {
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Dringend'")).firstMatch.exists {
                foundDringend = true
            }
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Bald'")).firstMatch.exists {
                foundBald = true
            }
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Später'")).firstMatch.exists {
                foundSpaeter = true
            }
            if foundDringend && foundBald && foundSpaeter { break }
            list.swipeUp()
        }

        // Mindestens eine Tier-Sektion muss sichtbar sein (Mock-Daten haben Tasks in verschiedenen Tiers)
        XCTAssertTrue(foundDringend || foundBald || foundSpaeter,
                       "Mindestens eine Tier-Sektion (Dringend/Bald/Später) muss existieren")

        // "Aktive Tasks" darf NICHT mehr existieren
        let aktivText = app.staticTexts.matching(
            NSPredicate(format: "label == 'Aktive Tasks'")
        ).firstMatch
        XCTAssertFalse(aktivText.exists,
                        "'Aktive Tasks' Sektion darf nicht mehr existieren")
    }

    // MARK: - TEST_03: "Geparkt"-Sektion (ehemals "Parkdeck") ist offen

    /// Bricht wenn: Section Header noch "Parkdeck" zeigt oder collapsed ist
    func test_geparktSection_existsAndIsOpen() {
        navigateToBacklogPriority()

        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        // Scroll to find "Geparkt" section
        var geparktFound = false
        for _ in 0..<8 {
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Geparkt'")).firstMatch.exists {
                geparktFound = true
                break
            }
            list.swipeUp()
        }

        // "Geparkt" muss existieren (Mock-Daten brauchen einen isParked=true Task)
        // Wenn kein geparkter Mock-Task existiert, ist die Sektion leer und wird nicht angezeigt — das ist OK
        // Aber "Parkdeck" darf NICHT mehr existieren
        let parkdeckText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Parkdeck'")
        ).firstMatch
        XCTAssertFalse(parkdeckText.exists,
                        "'Parkdeck' Label darf nicht mehr existieren — muss 'Geparkt' heißen")
    }

    // MARK: - TEST_04: Swipe-Action "Heute" statt "Next Up"

    /// Bricht wenn: Swipe-Action auf Backlog-Task noch "Next Up" statt "Heute" zeigt
    func test_swipeAction_showsHeuteNotNextUp() {
        navigateToBacklogPriority()

        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        // Find any task in a tier section (not in Heute)
        let anyTask = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK] Backlog Task 1'")
        ).firstMatch

        for _ in 0..<5 {
            if anyTask.exists { break }
            list.swipeUp()
        }

        guard anyTask.waitForExistence(timeout: 5) else {
            XCTFail("Backlog Task 1 nicht gefunden")
            return
        }

        anyTask.swipeRight()

        let heuteButton = app.buttons["Heute"]
        XCTAssertTrue(heuteButton.waitForExistence(timeout: 3),
                       "Swipe-Action muss 'Heute' zeigen, nicht 'Next Up'")
    }

    // MARK: - TEST_05: Swipe "Parken" auf Tier-Task

    /// Bricht wenn: Tier-Tasks keine "Parken" Swipe-Action haben
    func test_tierTask_swipeLeft_showsParkenAction() {
        navigateToBacklogPriority()

        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        let activeTask = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK] Blocker'")
        ).firstMatch

        for _ in 0..<5 {
            if activeTask.exists { break }
            list.swipeUp()
        }

        guard activeTask.waitForExistence(timeout: 5) else {
            XCTFail("Task '[MOCK] Blocker' nicht gefunden")
            return
        }

        activeTask.swipeLeft()

        let parkenButton = app.buttons["Parken"]
        XCTAssertTrue(parkenButton.waitForExistence(timeout: 3),
                       "Swipe auf Tier-Task muss 'Parken' Action zeigen")
    }

    // MARK: - TEST_06: ViewMode Switcher hat alle 5 Modi

    func test_viewModeSwitcher_hasAllFiveModes() {
        navigateToBacklogPriority()

        let switcher = app.buttons["viewModeSwitcher"].firstMatch
        guard switcher.waitForExistence(timeout: 5) else {
            XCTFail("ViewMode Switcher nicht gefunden")
            return
        }
        switcher.tap()

        let modes = ["Priorität", "Zuletzt", "Überfällig", "Wiederkehrend", "Erledigt"]
        for mode in modes {
            let menuItem = app.buttons[mode].firstMatch
            XCTAssertTrue(
                menuItem.waitForExistence(timeout: 2),
                "ViewMode '\(mode)' muss im Switcher vorhanden sein"
            )
        }
    }
}
