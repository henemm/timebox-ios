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

        // Morning zeigt Kalender-Events, Daytime zeigt Timeline, Evening zeigt Platzhalter
        // Dieser Test akzeptiert alle drei (zeitunabhaengig)
        let hasMorningContent = app.staticTexts["Team Meeting"].waitForExistence(timeout: 5)
        let hasDaytimeTimeline = app.staticTexts["08:00"].exists
        let hasEveningPlaceholder = app.staticTexts["Reflexion kommt bald"].exists

        XCTAssertTrue(
            hasMorningContent || hasDaytimeTimeline || hasEveningPlaceholder,
            "DayView sollte Content zeigen: Morning=Events, Daytime=Timeline, Evening=Platzhalter"
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

    /// Verhalten: Im Morgen-Modus ohne Events/Tasks zeigt die DayView einen Empty-State
    /// Bricht wenn: morningContent nicht den ContentUnavailableView rendert bei leeren Daten
    func test_morningMode_showsEmptyState() throws {
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-morningEndHour", "24", "--empty-morning"]
        app.launch()

        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5))
        tagTab.tap()

        // Empty State: "Keine Vorschlaege" + "Plan deinen Tag selbst" (DayView.swift:82-86)
        let emptyTitle = app.staticTexts["Keine Vorschlaege"]
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 5),
            "Morgen-Modus ohne Events sollte 'Keine Vorschlaege' anzeigen"
        )

        let emptyDescription = app.staticTexts["Plan deinen Tag selbst"]
        XCTAssertTrue(
            emptyDescription.exists,
            "Empty-State sollte 'Plan deinen Tag selbst' als Beschreibung zeigen"
        )

        // Kalender-Sektionen duerfen NICHT erscheinen
        let termine = app.staticTexts["Termine"]
        XCTAssertFalse(termine.exists, "Keine 'Termine'-Sektion bei leerem Kalender")
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

    // MARK: - Daytime Mode Content (RW_2.1c)

    /// Helper: App im erzwungenen Daytime-Modus starten
    /// morningEndHour=0 → Morning ist sofort vorbei
    /// eveningStartHour=24 → Evening beginnt nie
    private func launchInDaytimeMode() {
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-morningEndHour", "0", "-eveningStartHour", "24"]
        app.launch()
    }

    /// Helper: Zum Tag-Tab navigieren
    private func navigateToDayTab() {
        let tagTab = app.tabBars.buttons["Tag"]
        XCTAssertTrue(tagTab.waitForExistence(timeout: 5), "Tag-Tab muss existieren")
        tagTab.tap()
    }

    /// Verhalten: Im Daytime-Modus zeigt die DayView eine Timeline mit Stunden-Labels (06:00, 07:00, ...)
    /// Bricht wenn: daytimeContent nicht TimelineView rendert sondern weiterhin den Placeholder zeigt
    func test_daytimeMode_showsTimeline() throws {
        launchInDaytimeMode()
        navigateToDayTab()

        // TimelineView rendert Stunden-Labels wie "08:00", "12:00" etc.
        // Wenn diese sichtbar sind, ist die Timeline aktiv (nicht der Placeholder)
        let hourLabel = app.staticTexts["08:00"]
        XCTAssertTrue(
            hourLabel.waitForExistence(timeout: 5),
            "Daytime-Modus sollte Timeline mit Stunden-Labels zeigen (z.B. '08:00')"
        )

        // Alter Placeholder-Text darf NICHT mehr erscheinen
        let placeholder = app.staticTexts["Timeline kommt bald"]
        XCTAssertFalse(
            placeholder.exists,
            "Daytime-Modus sollte keinen Platzhalter mehr zeigen"
        )
    }

    /// Verhalten: Im Daytime-Modus zeigt die Timeline Kalender-Events als Bloecke
    /// Bricht wenn: loadDaytimeData() keine Events laedt oder events nicht an TimelineView uebergeben werden
    func test_daytimeMode_showsCalendarEvents() throws {
        launchInDaytimeMode()
        navigateToDayTab()

        // Mock-Events: "Team Meeting" (08:00), "Lunch Meeting" (12:00), "Workshop" (16:00)
        // EventBlock rendert den Titel als StaticText
        let lunchMeeting = app.staticTexts["Lunch Meeting"]
        XCTAssertTrue(
            lunchMeeting.waitForExistence(timeout: 5),
            "Daytime-Timeline sollte Kalender-Events anzeigen (z.B. 'Lunch Meeting')"
        )
    }

    /// Verhalten: Im Daytime-Modus zeigt die Timeline geplante Tasks als orange Bloecke
    /// Bricht wenn: scheduledTasks nicht aus SyncEngine geladen oder nicht als TimelineItem gemappt werden
    func test_daytimeMode_showsScheduledTasks() throws {
        launchInDaytimeMode()
        navigateToDayTab()

        // Mock-Daten enthalten "[MOCK] Scheduled: Bericht schreiben" um 11:00, 45min
        // ScheduledTaskBlock hat accessibilityIdentifier "scheduledTaskBlock_<id>"
        // Wir suchen nach dem Titel-Text
        let scheduledTask = app.staticTexts["[MOCK] Scheduled: Bericht schreiben"]
        XCTAssertTrue(
            scheduledTask.waitForExistence(timeout: 5),
            "Daytime-Timeline sollte geplante Tasks anzeigen"
        )
    }

    /// Verhalten: Im Daytime-Modus ohne Events/Tasks zeigt die DayView einen Empty-State
    /// Bricht wenn: daytimeContent nicht den ContentUnavailableView rendert bei leeren Daten
    func test_daytimeMode_showsEmptyState() throws {
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-morningEndHour", "0", "-eveningStartHour", "24", "--empty-morning"]
        app.launch()
        navigateToDayTab()

        // Empty State: "Keine Termine" + "Dein Tag ist frei"
        let emptyTitle = app.staticTexts["Keine Termine"]
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 5),
            "Daytime-Modus ohne Events sollte 'Keine Termine' anzeigen"
        )

        // Timeline-Elemente duerfen NICHT erscheinen
        let hourLabel = app.staticTexts["08:00"]
        XCTAssertFalse(
            hourLabel.exists,
            "Empty-State sollte keine Timeline-Stunden zeigen"
        )
    }

    // MARK: - Evening Mode Content (RW_2.1d)

    /// Helper: App im erzwungenen Abend-Modus starten
    /// eveningStartHour=0 → Evening startet um Mitternacht, also ist es IMMER Abend
    private func launchInEveningMode() {
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-eveningStartHour", "0"]
        app.launch()
    }

    /// Verhalten: Im Abend-Modus zeigt die DayView den Titel "Tagesrueckblick"
    /// Bricht wenn: navigationTitle im evening case nicht "Tagesrueckblick" liefert
    func test_eveningMode_showsTagesrueckblick() throws {
        launchInEveningMode()
        navigateToDayTab()

        let title = app.navigationBars["Tagesrueckblick"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "Abend-Modus sollte 'Tagesrueckblick' als NavigationBar-Titel zeigen"
        )

        // Alter Platzhalter-Text darf NICHT mehr erscheinen
        let placeholder = app.staticTexts["Reflexion kommt bald"]
        XCTAssertFalse(
            placeholder.exists,
            "Abend-Modus sollte keinen Platzhalter mehr zeigen"
        )
    }

    /// Verhalten: Im Abend-Modus zeigt die DayView erledigte Tasks
    /// Bricht wenn: eveningContent den completedTasksSection ViewBuilder nicht rendert
    func test_eveningMode_showsCompletedSection() throws {
        launchInEveningMode()
        navigateToDayTab()

        // Mock-Daten enthalten "[MOCK] Erledigte Backlog-Aufgabe" mit completedAt=Date()
        let completedSection = app.otherElements["eveningCompletedSection"]
        XCTAssertTrue(
            completedSection.waitForExistence(timeout: 5),
            "Abend-Modus sollte eine Sektion fuer erledigte Tasks zeigen"
        )

        // Der erledigte Mock-Task muss sichtbar sein
        let completedTask = app.staticTexts["[MOCK] Erledigte Backlog-Aufgabe"]
        XCTAssertTrue(
            completedTask.waitForExistence(timeout: 3),
            "Abend-Modus sollte den erledigten Mock-Task anzeigen"
        )
    }

    /// Verhalten: Im Abend-Modus zeigt die DayView die DayTimelineBar
    /// Bricht wenn: eveningContent die DayTimelineBar nicht einbindet
    func test_eveningMode_showsTimelineBar() throws {
        launchInEveningMode()
        navigateToDayTab()

        let timelineBar = app.otherElements["dayTimelineBar"]
        XCTAssertTrue(
            timelineBar.waitForExistence(timeout: 5),
            "Abend-Modus sollte die DayTimelineBar anzeigen"
        )
    }

    /// Verhalten: Im Abend-Modus zeigt die DayView Success Story Card und Failure Protocol Stub
    /// Bricht wenn: SuccessStoryView oder failureQuickSelectStub ViewBuilder fehlen
    func test_eveningMode_showsStubCards() throws {
        launchInEveningMode()
        navigateToDayTab()

        let successCard = app.otherElements["successStoryCard"]
        XCTAssertTrue(
            successCard.waitForExistence(timeout: 10),
            "Abend-Modus sollte die Success-Story-Card zeigen"
        )

        let failureStub = app.otherElements["failureQuickSelectStubCard"]
        XCTAssertTrue(
            failureStub.exists,
            "Abend-Modus sollte die Failure-QuickSelect-Stub-Card zeigen"
        )
    }
}
