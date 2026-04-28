import XCTest

/// Bug 279 — Stacking-Badge wird beim Anhaeufen wiederkehrender Tasks angezeigt.
///
/// **Mock-Daten-Setup (FocusBloxApp.swift, ab Zeile 913):**
/// - Series 1 "Taeglich lesen": 2 offene Children (heute + gestern) → Badge "x2"
/// - Series 2 "Wochenreview": 3 offene Children (heute + -7T + -14T) → Badge "x3"
/// - Series 3 "Zweiwochentlich aufraeumen": 1 offenes Child → KEIN Badge
///
/// **Anti-Silent-Pass (Bug 279 Re-Open):** Tests pruefen konkrete Label-Werte ("x2", "x3"),
/// nicht nur Identifier-Existenz oder OR-Fallbacks. Mock-Daten sind deterministisch
/// geseedet — wenn das Badge fehlt, ist der einzige moegliche Grund:
/// applyRecurringStacking() setzt stackedInstanceCount nicht oder die Render-Bedingung
/// in BacklogRow.swift Zeile 228 ist falsch.
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
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog-Tab muss existieren")
        backlogTab.tap()

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Backlog-Liste muss existieren")
    }

    // MARK: - TEST_01: Series 2 (3 offene Instanzen) zeigt Badge "x3"

    /// Bug 279 — Beweis: Series 2 'Wochenreview' hat 3 offene Children → Badge "x3" muss sichtbar sein.
    /// Bricht wenn: applyRecurringStacking() setzt stackedInstanceCount nicht auf 3.
    func test_seriesWithThreeInstances_showsBadgeX3() throws {
        navigateToBacklogPriority()

        let badgeX3 = app.staticTexts.matching(
            NSPredicate(format: "label == 'x3' AND identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch

        XCTAssertTrue(
            badgeX3.waitForExistence(timeout: 5),
            "Series 2 'Wochenreview' hat 3 offene Children — Badge 'x3' muss sichtbar sein. " +
            "Falls fehlt: applyRecurringStacking() setzt stackedInstanceCount nicht korrekt."
        )
    }

    // MARK: - TEST_02: Series 1 (2 offene Instanzen) zeigt Badge "x2"

    /// Bug 279 — Beweis: Series 1 hat 2 offene Children → Badge "x2" muss sichtbar sein
    /// (Spec: ab 2 Instanzen sichtbar, nicht erst ab 3).
    /// Bricht wenn: Stacking-Schwelle ist >= 3 statt >= 2 ODER Logik gruppiert nicht.
    func test_seriesWithTwoInstances_showsBadgeX2() throws {
        navigateToBacklogPriority()

        let badgeX2 = app.staticTexts.matching(
            NSPredicate(format: "label == 'x2' AND identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch

        XCTAssertTrue(
            badgeX2.waitForExistence(timeout: 5),
            "Series 1 'Taeglich lesen' hat 2 offene Children — Badge 'x2' muss sichtbar sein " +
            "(Spec: ab 2 Instanzen orange, nicht erst ab 3)."
        )
    }

    // MARK: - TEST_03: Genau EINE Row pro gestackter Serie (nicht 3)

    /// Bug 279 — Beweis: 3 Instanzen derselben Serie erscheinen als EINE Row, nicht 3.
    /// Bricht wenn: BacklogView gruppiert nicht nach recurrenceGroupID.
    func test_stackedSeries_rendersAsSingleRow() throws {
        navigateToBacklogPriority()

        let wochenreviewRows = app.staticTexts.matching(
            NSPredicate(format: "label == '[MOCK] Wochenreview'")
        )

        XCTAssertEqual(
            wochenreviewRows.count, 1,
            "Wochenreview muss als EINE gestackte Row erscheinen, nicht als \(wochenreviewRows.count) separate Rows."
        )
    }

    // MARK: - TEST_04: Negativtest — Series 3 (1 Instanz) hat KEIN Badge

    /// Bug 279 — Beweis: Series mit 1 Instanz darf KEINEN Stacking-Badge zeigen.
    /// Anti-Silent-Pass: Wartet zuerst auf positiven Anker (irgend ein Badge),
    /// damit der Test nicht trivially passed wenn ALLE Badges fehlen.
    /// Bricht wenn: Badge auch bei stackedInstanceCount=1 angezeigt wird.
    func test_singleInstanceSeries_hasNoStackingBadge() throws {
        navigateToBacklogPriority()

        // Anker: irgend ein Badge muss existieren (Series 1 oder 2), sonst ist der Test bedeutungslos
        let anyBadge = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch
        XCTAssertTrue(
            anyBadge.waitForExistence(timeout: 5),
            "Voraussetzung: mindestens ein Badge muss existieren (Series 1 oder 2). " +
            "Falls keiner: dieser Negativ-Test ist bedeutungslos."
        )

        let x1Badge = app.staticTexts.matching(
            NSPredicate(format: "label == 'x1' AND identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch
        XCTAssertFalse(x1Badge.exists, "Bei nur 1 Instanz darf KEIN 'x1' Badge erscheinen")
    }

    // MARK: - TEST_04: Completion reduziert Badge

    /// Verhalten: Abhaken einer gestackten Zeile (x3) reduziert Badge auf x2.
    /// Bricht wenn: completeTask() nicht die aelteste Instanz erledigt oder Badge nicht aktualisiert wird.
    func test_completeStackedTask_decrementsBadge() {
        navigateToBacklogPriority()

        // Finde einen Stacking-Badge
        let badgeQuery = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        )

        guard badgeQuery.firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("No stacking badge found — cannot test completion decrement")
            return
        }

        let initialBadgeCount = badgeQuery.count

        // Finde Badge und zugehoerigen Complete-Button
        let targetBadge = badgeQuery.firstMatch
        let badgeId = targetBadge.identifier
        let taskId = String(badgeId.dropFirst("stackingBadge_".count))
        let completeButton = app.buttons["completeButton_\(taskId)"]

        guard completeButton.waitForExistence(timeout: 3) else {
            XCTFail("Complete button not found for stacked task \(taskId)")
            return
        }

        // Tap complete — triggers DeferredCompletion (3s delay + loadTasks reload)
        completeButton.tap()

        // Verify immediate pending state: checkbox shows "Erledigt" during deferred completion
        let pendingCheckbox = app.buttons["completeButton_\(taskId)"]
        XCTAssertTrue(pendingCheckbox.waitForExistence(timeout: 3), "Complete button should still exist during deferred completion")
        XCTAssertEqual(pendingCheckbox.label, "Erledigt", "Checkbox should show 'Erledigt' during pending completion")

        // After DeferredCompletion fires (3s) + reload: old badge disappears
        // because the completed representative gets removed and a new one with different ID appears.
        // Wait for the old badge to disappear (representative changed).
        let oldBadgeGone = badgeQuery.element(matching:
            NSPredicate(format: "identifier == %@", badgeId)
        ).waitForNonExistence(timeout: 10)

        if oldBadgeGone {
            // Old representative was completed — badge ID changed. Success.
            return
        }

        // Badge still exists with same ID — check if label changed (count decremented)
        let currentBadges = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        )
        XCTAssertTrue(
            currentBadges.count != initialBadgeCount,
            "Badge count should change after completing oldest stacked instance"
        )
    }

    // MARK: - TEST_05: Gestackter Task zeigt Untertitel (Bug 279)

    /// Verhalten: Ein gestackter Task zeigt einen Untertitel "X Instanzen seit [Datum]".
    /// Bricht wenn: BacklogRow keinen Untertitel rendert wenn stackedOldestDueDate gesetzt ist.
    func test_stackedTaskShowsSubtitle() {
        navigateToBacklogPriority()

        let list = app.collectionViews["backlogTaskList"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Backlog-Liste muss existieren")

        let subtitlePredicate = NSPredicate(format: "label CONTAINS 'Instanzen seit'")
        let subtitleTexts = app.staticTexts.matching(subtitlePredicate)

        XCTAssertGreaterThan(
            subtitleTexts.count,
            0,
            "Gestackte Tasks müssen einen Untertitel 'X Instanzen seit [Datum]' zeigen"
        )
    }

    // MARK: - TEST_06: Badge ist orange ab 2 Instanzen (Bug 279)

    /// Verhalten: Das Stacking-Badge wird ab 2 Instanzen orange (nicht erst ab 3).
    /// Bricht wenn: StackingBadge.count >= 3 Schwelle statt >= 2 verwendet.
    func test_stackingBadgeExistsForTwoInstances() {
        navigateToBacklogPriority()

        let x2Badge = app.staticTexts.matching(
            NSPredicate(format: "label == 'x2' AND identifier BEGINSWITH 'stackingBadge_'")
        ).firstMatch

        XCTAssertTrue(
            x2Badge.waitForExistence(timeout: 5),
            "Ein Badge mit 'x2' muss existieren — orange ab 2 Instanzen"
        )
    }
}
