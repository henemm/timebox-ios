import XCTest

final class DayViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Tab Navigation

    /// Verhalten: Tab "Tag" existiert in der Tab-Bar und ist tappbar
    /// Bricht wenn: AppTab.day case fehlt oder tabItem Label falsch
    func test_dayTab_existsInTabBar() throws {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tab 'Tag' sollte in der Tab-Bar existieren")
    }

    /// Verhalten: Tap auf Tab "Tag" navigiert zur DayView
    /// Bricht wenn: DayView nicht als TabView-Child eingebunden ist
    func test_dayTab_tap_showsDayView() throws {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tab 'Tag' muss existieren")
        tagTab.tap()

        // DayView sollte einen der drei Modus-Texte zeigen
        let morningExists = app.staticTexts["Guten Morgen"].waitForExistence(timeout: 3)
        let daytimeExists = app.staticTexts["Dein Tag"].exists
        let eveningExists = app.staticTexts["Tagesrueckblick"].exists

        XCTAssertTrue(
            morningExists || daytimeExists || eveningExists,
            "DayView sollte einen Modus-Titel zeigen (Guten Morgen / Dein Tag / Tagesrueckblick)"
        )
    }

    /// Verhalten: Tab "Tag" ist zwischen "Blox" und "Focus" positioniert
    /// Bricht wenn: AppTab.day an falscher Position im enum steht
    func test_dayTab_positionedBetweenBloxAndFocus() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let bloxTab = tabBar.buttons["Blox"]
        let tagTab = tabBar.buttons["Tag"]
        let focusTab = tabBar.buttons["Focus"]

        XCTAssertTrue(bloxTab.exists, "Blox Tab muss existieren")
        XCTAssertTrue(tagTab.exists, "Tag Tab muss existieren")
        XCTAssertTrue(focusTab.exists, "Focus Tab muss existieren")

        // Tag-Tab muss rechts von Blox und links von Focus sein
        XCTAssertGreaterThan(
            tagTab.frame.midX, bloxTab.frame.midX,
            "Tag-Tab sollte rechts von Blox sein"
        )
        XCTAssertLessThan(
            tagTab.frame.midX, focusTab.frame.midX,
            "Tag-Tab sollte links von Focus sein"
        )
    }

    // MARK: - Phase Content

    /// Verhalten: DayView zeigt phasen-spezifischen Content (nicht leer)
    /// Bricht wenn: DayView body keinen Content fuer die aktuelle Phase rendert
    func test_dayView_showsPhaseContent() throws {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5))
        tagTab.tap()

        // Daytime/Evening zeigen weiterhin Platzhalter, Morning zeigt echten Content
        // Dieser Test akzeptiert beides (zeitunabhaengig)
        let hasMorningContent = app.staticTexts["Team Meeting"].waitForExistence(timeout: 5)
        let hasDaytimePlaceholder = app.staticTexts["Timeline kommt bald"].exists
        let hasEveningPlaceholder = app.staticTexts["Reflexion kommt bald"].exists

        XCTAssertTrue(
            hasMorningContent || hasDaytimePlaceholder || hasEveningPlaceholder,
            "DayView sollte Content zeigen: Morning=Kalender-Events, Daytime/Evening=Platzhalter"
        )
    }

    // MARK: - Morning Mode Content (RW_2.1b)

    /// Helper: App im erzwungenen Morgen-Modus starten
    private func launchInMorningMode() {
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-morningEndHour", "24"]
        app.launch()
    }

    /// Verhalten: Im Morgen-Modus zeigt die DayView echte Kalender-Events statt Platzhalter
    /// Bricht wenn: loadMorningData() nicht aufgerufen wird oder morningContent keine Events-Sektion rendert
    func test_morningMode_showsCalendarEvents() throws {
        launchInMorningMode()

        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5))
        tagTab.tap()

        // Mock-Daten enthalten "Team Meeting" (08:00-08:30) — muss im Morgen-Modus sichtbar sein
        let teamMeeting = app.staticTexts["Team Meeting"]
        XCTAssertTrue(
            teamMeeting.waitForExistence(timeout: 5),
            "Morgen-Modus sollte Kalender-Events anzeigen (z.B. 'Team Meeting')"
        )

        // Alter Platzhalter-Text darf NICHT mehr erscheinen
        let placeholder = app.staticTexts["Kalender-Uebersicht kommt bald"]
        XCTAssertFalse(
            placeholder.exists,
            "Morgen-Modus sollte keinen Platzhalter mehr zeigen"
        )
    }

    /// Verhalten: Im Morgen-Modus zeigt die DayView "Next Up" Tasks
    /// Bricht wenn: SyncEngine.sync() nicht aufgerufen oder nextUpTasks nicht gefiltert/gerendert werden
    func test_morningMode_showsNextUpTasks() throws {
        launchInMorningMode()

        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5))
        tagTab.tap()

        // Mock-Daten enthalten "[MOCK] Task 1 #30min" mit isNextUp=true
        let nextUpTask = app.staticTexts["[MOCK] Task 1 #30min"]
        XCTAssertTrue(
            nextUpTask.waitForExistence(timeout: 5),
            "Morgen-Modus sollte Next-Up Tasks anzeigen"
        )
    }

    /// Verhalten: Im Morgen-Modus zeigt die DayView freie Zeitluecken (GapFinder)
    /// Bricht wenn: GapFinder nicht aufgerufen oder freeSlots-Sektion nicht gerendert wird
    func test_morningMode_showsFreeTimeSlots() throws {
        launchInMorningMode()

        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5))
        tagTab.tap()

        // GapFinder berechnet Luecken zwischen Mock-Events/FocusBlocks.
        // Die Sektion "Freie Luecken" muss sichtbar sein mit mindestens einem Slot.
        let gapsSection = app.staticTexts["Freie Luecken"]
        XCTAssertTrue(
            gapsSection.waitForExistence(timeout: 5),
            "Morgen-Modus sollte eine 'Freie Luecken'-Sektion anzeigen"
        )
    }
}
