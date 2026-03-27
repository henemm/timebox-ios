import XCTest

final class BacklogParkdeckUITests: XCTestCase {
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

    /// Scrolls down until parkdeckSection becomes visible or maxSwipes reached
    @discardableResult
    private func scrollToParkdeck() -> XCUIElement {
        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch
        let parkdeck = app.buttons["parkdeckSection"].firstMatch

        // Scroll down to find parkdeck (may be off-screen)
        for _ in 0..<5 {
            if parkdeck.exists { break }
            list.swipeUp()
        }
        return parkdeck
    }

    // MARK: - TEST_01: Parkdeck Section collapsed by default

    /// Bricht wenn: BacklogView.priorityView hat keine Parkdeck-Section mit .accessibilityIdentifier("parkdeckSection")
    func test_parkdeckSection_existsAndCollapsedByDefault() {
        navigateToBacklogPriority()

        let parkdeck = scrollToParkdeck()
        XCTAssertTrue(parkdeck.waitForExistence(timeout: 3), "Parkdeck Section Header muss im Priority-View sichtbar sein")

        // Parkdeck soll "Parkdeck" Text enthalten
        let parkdeckText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Parkdeck'")).firstMatch
        XCTAssertTrue(parkdeckText.exists, "Parkdeck Header muss 'Parkdeck' Text enthalten")
    }

    // MARK: - TEST_02: Aktive Tasks Section existiert

    /// Bricht wenn: BacklogView.priorityView hat keine Aktiv-Section mit .accessibilityIdentifier("activeTasksSection")
    func test_activeTasksSection_exists() {
        navigateToBacklogPriority()

        let activeSectionText = app.staticTexts["activeTasksSection"].firstMatch
        let exists = activeSectionText.waitForExistence(timeout: 5)
        XCTAssertTrue(exists, "Aktive Tasks Section Header muss im Priority-View sichtbar sein")
    }

    // MARK: - TEST_03: Parkdeck expandiert per Tap

    /// Bricht wenn: Parkdeck-Button hat kein Toggle-Verhalten oder keine Tasks gerendert
    func test_parkdeckSection_expandsOnTap() {
        navigateToBacklogPriority()

        let parkdeck = scrollToParkdeck()
        guard parkdeck.waitForExistence(timeout: 5) else {
            XCTFail("Parkdeck Section Header nicht gefunden")
            return
        }

        // Tap to expand
        parkdeck.tap()

        // After expanding, parkdeck tasks may render below visible area — scroll down
        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        // Mock data includes tbdTask (someday) and backlogTask2 (eventually)
        let anyTaskInParkdeck = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK] TBD Task' OR label CONTAINS '[MOCK] Backlog Task 2'")
        ).firstMatch

        // Scroll down a few times to find parkdeck content
        for _ in 0..<5 {
            if anyTaskInParkdeck.exists { break }
            list.swipeUp()
        }

        XCTAssertTrue(
            anyTaskInParkdeck.waitForExistence(timeout: 3),
            "Nach Expand muss mindestens ein Task im Parkdeck sichtbar sein"
        )
    }

    // MARK: - TEST_04: Suche findet Tasks im collapsed Parkdeck

    /// Bricht wenn: Suchlogik filtert Parkdeck-Tasks aus wenn Parkdeck collapsed ist
    func test_search_findsParkdeckTasksWhenCollapsed() {
        navigateToBacklogPriority()

        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Suchfeld nicht gefunden")
            return
        }
        searchField.tap()
        searchField.typeText("TBD Task")

        // The TBD task should appear in search results even though Parkdeck is collapsed
        let searchResult = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'TBD Task'")
        ).firstMatch

        XCTAssertTrue(
            searchResult.waitForExistence(timeout: 3),
            "Suche muss TBD Task finden, auch wenn Parkdeck collapsed ist"
        )
    }

    // MARK: - TEST_05: ViewMode Switcher hat alle 5 Modi

    /// Bricht wenn: ViewMode enum geaendert oder Parkdeck-Umbau ViewModes entfernt
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

    // MARK: - TEST_07: Aktiver Task kann via Swipe geparkt werden

    /// Bricht wenn: BacklogView.priorityView Active-Section keine "Parken" swipeAction hat
    func test_activeTask_swipeLeft_showsParkenAction() {
        navigateToBacklogPriority()

        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        // "[MOCK] Blocker: API fertigstellen" is active (importance=3, urgency=urgent, no dueDate → not overdue)
        let activeTask = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK] Blocker'")
        ).firstMatch

        // Scroll to find the active task
        for _ in 0..<5 {
            if activeTask.exists { break }
            list.swipeUp()
        }

        guard activeTask.waitForExistence(timeout: 5) else {
            XCTFail("Aktiver Task '[MOCK] Blocker' nicht gefunden")
            return
        }

        activeTask.swipeLeft()

        let parkenButton = app.buttons["Parken"]
        XCTAssertTrue(
            parkenButton.waitForExistence(timeout: 3),
            "Swipe auf aktiven Task muss 'Parken' Action zeigen"
        )
    }

    // MARK: - TEST_08: Parkdeck-Task kann via Swipe aktiviert werden

    /// Bricht wenn: BacklogView.priorityView Parkdeck-Section keine "Aktivieren" swipeAction hat
    func test_parkdeckTask_swipeLeft_showsAktivierenAction() {
        navigateToBacklogPriority()

        // Expand parkdeck first
        let parkdeck = scrollToParkdeck()
        guard parkdeck.waitForExistence(timeout: 5) else {
            XCTFail("Parkdeck Section Header nicht gefunden")
            return
        }
        parkdeck.tap()

        // Scroll to find a parkdeck task
        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        let parkdeckTask = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '[MOCK] Backlog Task 2'")
        ).firstMatch

        for _ in 0..<5 {
            if parkdeckTask.exists { break }
            list.swipeUp()
        }

        guard parkdeckTask.waitForExistence(timeout: 3) else {
            XCTFail("Parkdeck Task '[MOCK] Backlog Task 2' nicht gefunden nach Expand")
            return
        }

        parkdeckTask.swipeLeft()

        let aktivierenButton = app.buttons["Aktivieren"]
        XCTAssertTrue(
            aktivierenButton.waitForExistence(timeout: 3),
            "Swipe auf Parkdeck-Task muss 'Aktivieren' Action zeigen"
        )
    }

    // MARK: - TEST_06: Parkdeck Badge zeigt Anzahl

    /// Bricht wenn: Parkdeck Header keinen Count-Badge hat
    func test_parkdeckSection_showsBadgeCount() {
        navigateToBacklogPriority()

        let parkdeck = scrollToParkdeck()
        guard parkdeck.waitForExistence(timeout: 5) else {
            XCTFail("Parkdeck Section Header nicht gefunden")
            return
        }

        // Check that the Parkdeck header label contains a number >= 1
        let label = parkdeck.label
        let hasNumber = label.range(of: #"\d+"#, options: .regularExpression) != nil
        XCTAssertTrue(hasNumber, "Parkdeck Header muss eine Zahl (Badge Count) enthalten, hat aber: '\(label)'")
    }
}
