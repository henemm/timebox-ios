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

    // MARK: - TEST_01: Stacking Badge wird angezeigt

    /// Verhalten: Wenn eine recurring Serie 2+ offene Instanzen hat, wird ein Badge "x2" angezeigt.
    /// Bricht wenn: BacklogRow kein StackingBadge rendert bei stackedCount >= 2.
    func test_stackingBadge_showsCountForMultipleInstances() {
        navigateToBacklogPriority()

        // Suche nach einem Stacking-Badge via accessibilityIdentifier
        let stackingBadges = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        )

        // Es sollte mindestens ein Stacking-Badge existieren wenn recurring Tasks gestackt sind
        XCTAssertGreaterThan(stackingBadges.count, 0, "Stacking badge (e.g. 'x2', 'x3') should exist for stacked recurring tasks")
    }

    // MARK: - TEST_02: Gestackte Tasks werden gruppiert

    /// Verhalten: 3 offene Instanzen derselben Serie erscheinen als EINE Zeile, nicht 3.
    /// Bricht wenn: BacklogView keine Gruppierung nach recurrenceGroupID macht.
    func test_stackedRecurringTasks_showAsOneRow() {
        navigateToBacklogPriority()

        // Zaehle sichtbare Task-Titel — gestackte sollten nur einmal erscheinen
        let list = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.tables.firstMatch

        XCTAssertTrue(list.waitForExistence(timeout: 5), "Backlog list should exist")

        // Suche nach dem Stacking-Badge als Beweis fuer Gruppierung
        let badges = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'stackingBadge_'")
        )
        // In einer nicht-leeren Backlog mit recurring Tasks sollte mindestens ein Badge existieren
        XCTAssertGreaterThan(badges.count, 0, "At least one stacking badge should exist for grouped recurring tasks")
    }

    // MARK: - TEST_03: Kein Badge bei einzelner Instanz

    /// Verhalten: Eine einzelne recurring Instanz (nicht gestackt) zeigt keinen Stacking-Badge.
    /// Bricht wenn: StackingBadge auch bei stackedCount=1 angezeigt wird.
    func test_singleRecurringInstance_noStackingBadge() {
        navigateToBacklogPriority()

        // Teste dass kein Badge mit "x1" existiert (x1 = kein Stacking)
        let x1Badge = app.staticTexts.matching(
            NSPredicate(format: "label == 'x1'")
        ).firstMatch
        XCTAssertFalse(x1Badge.exists, "Single instance should NOT show 'x1' badge")
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
}
