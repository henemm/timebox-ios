import XCTest

/// UI Tests fuer RW_3.4: Emotional Nudge (Micro-Tasks).
///
/// Prueft dass Blockade-Marker und Nudge-Section fuer chronisch
/// verschobene Tasks (rescheduleCount >= 3) korrekt angezeigt werden.
///
/// EXPECTED TO FAIL (TDD RED): Blockade-Marker und Nudge-Section existieren noch nicht.
final class EmotionalNudgeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-MockData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test 1: Blockade-Marker sichtbar fuer stuck Task

    /// GIVEN: Ein Task mit rescheduleCount >= 3 ist im Backlog
    /// WHEN: Backlog-Tab geoeffnet
    /// THEN: Orange Dreieck-Marker (stuckMarker_<id>) ist sichtbar
    ///
    /// Bricht wenn: BacklogRow.swift — isStuck-Overlay entfernt oder accessibilityIdentifier geaendert
    func test_blockadeMarker_visibleForStuckTask() throws {
        // Backlog-Tab oeffnen
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }

        // Suche nach irgendeinem stuckMarker (Pattern: stuckMarker_<uuid>)
        let stuckMarkers = app.images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stuckMarker_'")
        )

        // Warte kurz auf Laden
        let firstMarker = stuckMarkers.firstMatch
        XCTAssertTrue(
            firstMarker.waitForExistence(timeout: 5),
            "Blockade-Marker sollte fuer mindestens einen stuck Task sichtbar sein"
        )
    }

    // MARK: - Test 2: Nudge-Section in TaskDetailSheet sichtbar

    /// GIVEN: Ein Task mit rescheduleCount >= 3 existiert
    /// WHEN: TaskDetailSheet fuer diesen Task geoeffnet (via Swipe → Bearbeiten)
    /// THEN: Nudge-Text und "Nur 2 Minuten anfangen"-Button sichtbar
    ///
    /// Bricht wenn: TaskDetailSheet.swift — Nudge-Section entfernt oder Bedingung geaendert
    func test_nudgeSection_showsInTaskDetail() throws {
        // Backlog-Tab oeffnen
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }

        // Stuck Task ueber Titel finden
        let stuckTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '5x verschoben'")
        ).firstMatch

        guard stuckTitle.waitForExistence(timeout: 5) else {
            XCTFail("Stuck Task nicht im Backlog gefunden")
            return
        }

        // Swipe left to reveal edit action, then tap "Bearbeiten"
        stuckTitle.swipeLeft()
        let editButton = app.buttons["Bearbeiten"]
        guard editButton.waitForExistence(timeout: 3) else {
            XCTFail("Bearbeiten-Button nicht nach Swipe sichtbar")
            return
        }
        editButton.tap()

        // Scroll to bottom of form to find nudge section
        let scrollView = app.scrollViews["taskFormScrollView"]
        guard scrollView.waitForExistence(timeout: 5) else {
            XCTFail("TaskFormSheet ScrollView nicht gefunden")
            return
        }
        scrollView.swipeUp()
        scrollView.swipeUp()

        // Check for nudge elements
        let nudgeText = app.staticTexts["nudgeText"]
        XCTAssertTrue(
            nudgeText.waitForExistence(timeout: 5),
            "Nudge-Motivationstext sollte im TaskFormSheet sichtbar sein"
        )

        let nudgeButton = app.buttons["startNudgeSprintButton"]
        XCTAssertTrue(
            nudgeButton.exists,
            "'Nur 2 Minuten anfangen'-Button sollte sichtbar sein"
        )
    }

    // MARK: - Test 3: Nudge-Sprint startet bei Tap

    /// GIVEN: TaskDetailSheet fuer stuck Task ist offen, Nudge-Button sichtbar
    /// WHEN: User tippt auf "Nur 2 Minuten anfangen"
    /// THEN: Focus Sprint wird gestartet (FocusLiveView erscheint)
    ///
    /// Bricht wenn: onStartNudgeSprint-Callback nicht verdrahtet
    /// oder FocusBlockActionService.startImmediate(durationMinutes: 2) fehlschlaegt
    func test_nudgeTap_startsMiniSprint() throws {
        // Backlog-Tab oeffnen
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }

        // Stuck Task ueber Titel finden
        let stuckTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '5x verschoben'")
        ).firstMatch

        guard stuckTitle.waitForExistence(timeout: 5) else {
            XCTFail("Stuck Task nicht im Backlog gefunden")
            return
        }

        // Swipe left → Bearbeiten → TaskDetailSheet oeffnen
        stuckTitle.swipeLeft()
        let editButton = app.buttons["Bearbeiten"]
        guard editButton.waitForExistence(timeout: 3) else {
            XCTFail("Bearbeiten-Button nicht nach Swipe sichtbar")
            return
        }
        editButton.tap()

        // Nudge-Button finden (ggf. im Sheet scrollen)
        let nudgeButton = app.buttons["startNudgeSprintButton"]
        if !nudgeButton.waitForExistence(timeout: 3) {
            let scrollView = app.scrollViews["taskFormScrollView"]
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
        }
        guard nudgeButton.waitForExistence(timeout: 5) else {
            XCTFail("Nudge-Button sollte sichtbar sein")
            return
        }
        nudgeButton.tap()

        // Pruefen ob Focus Sprint gestartet wurde
        // FocusLiveView sollte erscheinen (z.B. Timer oder Sprint-UI)
        let sprintIndicator = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '2'")
        ).firstMatch

        XCTAssertTrue(
            sprintIndicator.waitForExistence(timeout: 5),
            "Nach Nudge-Tap sollte ein 2-Min Focus Sprint gestartet werden"
        )
    }

    // MARK: - Test 4: Kein Blockade-Marker fuer normalen Task

    /// GIVEN: Ein Task mit rescheduleCount < 3
    /// WHEN: Backlog angezeigt
    /// THEN: Kein stuckMarker fuer diesen Task
    ///
    /// Bricht wenn: isStuck-Berechnung falsch (z.B. >= 0 statt >= 3)
    func test_blockadeMarker_hiddenForNormalTask() throws {
        // Backlog-Tab oeffnen
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }

        // Pruefen ob Tasks existieren aber KEINE stuck-Marker haben
        // Dies ist ein Negativtest: Wir erwarten dass normale Tasks keinen Marker haben
        // Da Mock-Daten sowohl stuck als auch normale Tasks enthalten,
        // zaehlen wir Marker vs. alle Tasks
        let allTaskRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_'")
        )
        let stuckMarkers = app.images.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stuckMarker_'")
        )

        // Warten bis Tasks geladen
        let firstTask = allTaskRows.firstMatch
        guard firstTask.waitForExistence(timeout: 5) else {
            XCTFail("Keine Tasks im Backlog gefunden")
            return
        }

        // Es sollten weniger Marker als Tasks sein (nicht alle Tasks sind stuck)
        XCTAssertLessThan(
            stuckMarkers.count,
            allTaskRows.count,
            "Nicht alle Tasks sollten einen Blockade-Marker haben — nur rescheduleCount >= 3"
        )
    }
}
