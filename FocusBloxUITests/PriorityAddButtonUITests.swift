import XCTest

/// Bug: Toolbar inkonsistent ueber alle BacklogView View-Modes
/// Root Cause: SiriTipView im Group + zu viele Toolbar-Items + Import-Button
/// Fix: SiriTipView entfernen, Toolbar auf genau 3 Items: +, Dropdown, Gear
final class BacklogToolbarConsistencyUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    /// Wechselt zum angegebenen View-Mode ueber den viewModeSwitcher
    private func switchToMode(_ modeName: String) {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 3), "ViewMode switcher should exist")
        switcher.tap()
        sleep(1)
        let modeButton = app.buttons[modeName]
        if modeButton.waitForExistence(timeout: 2) {
            modeButton.tap()
            sleep(1)
        }
    }

    /// Prueft dass die 3 Pflicht-Items in der Toolbar existieren
    private func assertToolbarHasRequiredItems(mode: String) {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3),
            "\(mode): + Button (addTaskButton) muss existieren")
        XCTAssertTrue(addButton.isHittable,
            "\(mode): + Button muss hittable sein")

        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.exists,
            "\(mode): ViewMode Dropdown (viewModeSwitcher) muss existieren")
        XCTAssertTrue(switcher.isHittable,
            "\(mode): ViewMode Dropdown muss hittable sein")

        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.exists,
            "\(mode): Settings Gear (settingsButton) muss existieren")
        XCTAssertTrue(settings.isHittable,
            "\(mode): Settings Gear muss hittable sein")
    }

    /// Prueft dass Import-Button NICHT in der Toolbar ist
    private func assertNoImportButton(mode: String) {
        let importButton = app.buttons["importRemindersButton"]
        XCTAssertFalse(importButton.exists,
            "\(mode): Import-Button darf NICHT in der Toolbar sein")
    }

    /// Prueft dass keine SiriTipView sichtbar ist
    private func assertNoSiriTips() {
        let siriTip = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sage'")
        ).firstMatch
        XCTAssertFalse(siriTip.exists, "SiriTipView darf nicht existieren")
    }

    // MARK: - Toolbar Consistency Tests (alle 5 Modes)

    /// GIVEN: App startet im Default-Mode (Prioritaet)
    /// WHEN: Toolbar wird angezeigt
    /// THEN: Genau 3 Items: +, Dropdown, Gear. Kein Import, keine SiriTips.
    /// BREAKS AT: addTaskButton fehlt auf echtem Geraet
    func testToolbarInPriorityMode() throws {
        assertToolbarHasRequiredItems(mode: "Prioritaet")
        assertNoImportButton(mode: "Prioritaet")
        assertNoSiriTips()
    }

    /// GIVEN: User wechselt zu "Zuletzt"
    /// THEN: Identische Toolbar wie in Prioritaet
    /// BREAKS AT: Import-Button erscheint nur in Zuletzt
    func testToolbarInRecentMode() throws {
        switchToMode("Zuletzt")
        assertToolbarHasRequiredItems(mode: "Zuletzt")
        assertNoImportButton(mode: "Zuletzt")
    }

    /// GIVEN: User wechselt zu "Ueberfaellig"
    /// THEN: Identische Toolbar
    func testToolbarInOverdueMode() throws {
        switchToMode("Überfällig")
        assertToolbarHasRequiredItems(mode: "Ueberfaellig")
        assertNoImportButton(mode: "Ueberfaellig")
    }

    /// GIVEN: User wechselt zu "Wiederkehrend"
    /// THEN: Identische Toolbar (Dropdown war hier vorher weg!)
    /// BREAKS AT: viewModeSwitcher fehlt in Wiederkehrend
    func testToolbarInRecurringMode() throws {
        switchToMode("Wiederkehrend")
        assertToolbarHasRequiredItems(mode: "Wiederkehrend")
        assertNoImportButton(mode: "Wiederkehrend")
    }

    /// GIVEN: User wechselt zu "Erledigt"
    /// THEN: Identische Toolbar
    /// BREAKS AT: Import-Button erscheint in Erledigt
    func testToolbarInCompletedMode() throws {
        switchToMode("Erledigt")
        assertToolbarHasRequiredItems(mode: "Erledigt")
        assertNoImportButton(mode: "Erledigt")
    }

    // MARK: - Functional Test

    /// GIVEN: Prioritaet-Mode
    /// WHEN: User tippt + Button
    /// THEN: TaskFormSheet oeffnet sich
    func testAddButtonOpensTaskForm() throws {
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()

        let createNavBar = app.navigationBars["Neuer Task"]
        XCTAssertTrue(createNavBar.waitForExistence(timeout: 3),
            "TaskFormSheet should open when + is tapped")
    }
}
