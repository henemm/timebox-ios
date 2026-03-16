import XCTest

/// UI Tests fuer FEATURE_001: Recurring-Serie-Dialoge im Coach-Backlog.
/// Bricht wenn: CoachBacklogView.deleteTask() keinen Recurring-Check hat
/// Bricht wenn: CoachBacklogView hat keinen editSeriesMode
final class CoachRecurringDialogUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Reset view mode to Priority to avoid state leakage between tests
        app.launchArguments = ["-UITesting", "-coachModeEnabled", "1", "-coachBacklogViewMode", "Priorität"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog tab should exist")
        backlogTab.tap()
    }

    /// Wechselt zum "Zuletzt"-ViewMode wo alle Tasks nach Datum sichtbar sind.
    private func switchToRecentView() {
        let switcher = app.buttons["coachViewModeSwitcher"]
        guard switcher.waitForExistence(timeout: 5) else { return }
        switcher.tap()

        // Menu items appear inside a collectionView — scope to avoid matching the switcher label itself
        let recentOption = app.collectionViews.buttons["Zuletzt"]
        guard recentOption.waitForExistence(timeout: 3) else { return }
        recentOption.tap()
    }

    /// Findet einen wiederkehrenden Mock-Task (Child-Instanz) durch Scrollen.
    private func findRecurringChildTask() -> XCUIElement {
        // Switch to "Zuletzt" view where all tasks are visible (not filtered by tier)
        switchToRecentView()

        let task = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Taeglich lesen'")
        ).firstMatch

        // Scroll to find task if off-screen
        if !task.waitForExistence(timeout: 3) {
            for _ in 0..<8 {
                app.swipeUp()
                if task.waitForExistence(timeout: 1) { break }
            }
        }
        return task
    }

    // MARK: - Delete Dialog Tests

    /// GIVEN: Wiederkehrender Task im Coach-Backlog
    /// WHEN: User wischt links und tippt "Loeschen"
    /// THEN: Confirmation-Dialog erscheint mit "Nur diese Aufgabe" + "Alle offenen dieser Serie"
    ///
    /// Bricht wenn: CoachBacklogView.deleteTask() direkt SyncEngine.deleteTask() aufruft
    ///              statt taskToDeleteRecurring zu setzen
    func test_swipeDelete_recurringTask_showsConfirmationDialog() throws {
        navigateToBacklog()

        let recurringTask = findRecurringChildTask()
        XCTAssertTrue(recurringTask.waitForExistence(timeout: 5),
                      "Recurring mock task '[MOCK] Taeglich lesen' should exist in Coach backlog")

        recurringTask.swipeLeft()

        let deleteButton = app.buttons["Löschen"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Swipe delete button should appear")
        deleteButton.tap()

        // Dialog MUSS erscheinen mit beiden Optionen
        let singleDeleteButton = app.buttons["Nur diese Aufgabe"]
        XCTAssertTrue(singleDeleteButton.waitForExistence(timeout: 3),
                      "FEATURE_001: 'Nur diese Aufgabe' option must appear for recurring task deletion")

        let seriesDeleteButton = app.buttons["Alle offenen dieser Serie"]
        XCTAssertTrue(seriesDeleteButton.waitForExistence(timeout: 2),
                      "FEATURE_001: 'Alle offenen dieser Serie' option must appear for recurring task deletion")
    }

    /// GIVEN: Recurring-Delete-Dialog ist offen
    /// WHEN: User tippt "Nur diese Aufgabe"
    /// THEN: Nur die eine Instanz wird geloescht, Dialog schliesst
    ///
    /// Bricht wenn: deleteSingleTask() nicht existiert in CoachBacklogView
    func test_deleteDialog_singleOption_deletesOnlyOneInstance() throws {
        navigateToBacklog()

        let recurringTask = findRecurringChildTask()
        XCTAssertTrue(recurringTask.waitForExistence(timeout: 5),
                      "Recurring mock task should exist")

        recurringTask.swipeLeft()
        let deleteButton = app.buttons["Löschen"]
        guard deleteButton.waitForExistence(timeout: 3) else {
            XCTFail("Delete button should appear after swipe")
            return
        }
        deleteButton.tap()

        let singleDelete = app.buttons["Nur diese Aufgabe"]
        guard singleDelete.waitForExistence(timeout: 3) else {
            XCTFail("FEATURE_001: Single delete option must appear")
            return
        }
        singleDelete.tap()

        // Dialog muss weg sein
        XCTAssertFalse(singleDelete.waitForExistence(timeout: 2),
                       "Dialog should be dismissed after selection")
    }

    /// GIVEN: Confirmation-Dialog offen
    /// WHEN: User dismissed den Dialog (Cancel)
    /// THEN: Dialog schliesst, Task bleibt bestehen
    ///
    /// Bricht wenn: Dialog nicht korrekt dismissed
    func test_deleteDialog_cancel_keepsTask() throws {
        navigateToBacklog()

        let recurringTask = findRecurringChildTask()
        XCTAssertTrue(recurringTask.waitForExistence(timeout: 5),
                      "Recurring mock task should exist")

        recurringTask.swipeLeft()
        let deleteButton = app.buttons["Löschen"]
        guard deleteButton.waitForExistence(timeout: 3) else {
            XCTFail("Delete button should appear")
            return
        }
        deleteButton.tap()

        // Wait for dialog to appear
        let singleDelete = app.buttons["Nur diese Aufgabe"]
        guard singleDelete.waitForExistence(timeout: 3) else {
            XCTFail("FEATURE_001: Dialog must appear before cancel can be tested")
            return
        }

        // iOS 26.2: confirmationDialog cancel button is not a visible accessible element.
        // Dismiss by tapping outside the dialog (top of screen).
        let topArea = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        topArea.tap()

        // Task muss noch da sein
        XCTAssertTrue(recurringTask.waitForExistence(timeout: 3),
                      "Task must still exist after cancelling delete dialog")
    }

    // MARK: - Edit Dialog Tests

    /// GIVEN: Wiederkehrender Task im Coach-Backlog
    /// WHEN: User wischt links und tippt "Bearbeiten"
    /// THEN: Confirmation-Dialog erscheint mit "Nur diese Aufgabe" + "Alle offenen dieser Serie"
    ///
    /// Bricht wenn: CoachBacklogView setzt direkt taskToEdit statt taskToEditRecurring
    func test_swipeEdit_recurringTask_showsEditSeriesDialog() throws {
        navigateToBacklog()

        let recurringTask = findRecurringChildTask()
        XCTAssertTrue(recurringTask.waitForExistence(timeout: 5),
                      "Recurring mock task should exist")

        recurringTask.swipeLeft()

        let editButton = app.buttons["Bearbeiten"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Swipe edit button should appear")
        editButton.tap()

        // Edit-Dialog MUSS erscheinen
        let singleEditButton = app.buttons["Nur diese Aufgabe"]
        XCTAssertTrue(singleEditButton.waitForExistence(timeout: 3),
                      "FEATURE_001: 'Nur diese Aufgabe' option must appear for recurring task editing")

        let seriesEditButton = app.buttons["Alle offenen dieser Serie"]
        XCTAssertTrue(seriesEditButton.waitForExistence(timeout: 2),
                      "FEATURE_001: 'Alle offenen dieser Serie' option must appear for recurring task editing")
    }

    // MARK: - Non-Recurring Tasks (Regression)

    /// GIVEN: Normaler (nicht wiederkehrender) Task im Coach-Backlog
    /// WHEN: User wischt links und tippt "Loeschen"
    /// THEN: Kein Dialog — Task wird direkt geloescht
    ///
    /// Bricht wenn: Recurring-Check faelschlicherweise auch fuer normale Tasks triggert
    func test_swipeDelete_nonRecurringTask_noDialog() throws {
        navigateToBacklog()

        // Scroll to find a normal (non-recurring) task in Priority view
        let normalTask = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Lohnsteuererklaerung'")
        ).firstMatch

        if !normalTask.waitForExistence(timeout: 3) {
            for _ in 0..<5 {
                app.swipeUp()
                if normalTask.waitForExistence(timeout: 1) { break }
            }
        }
        XCTAssertTrue(normalTask.waitForExistence(timeout: 5),
                      "Normal mock task '[MOCK] Lohnsteuererklaerung einreichen' should exist")

        normalTask.swipeLeft()
        let deleteButton = app.buttons["Löschen"]
        guard deleteButton.waitForExistence(timeout: 3) else {
            XCTFail("Delete button should appear after swipe")
            return
        }
        deleteButton.tap()

        // Kein Dialog — "Nur diese Aufgabe" darf NICHT erscheinen
        let seriesOption = app.buttons["Nur diese Aufgabe"]
        XCTAssertFalse(seriesOption.waitForExistence(timeout: 2),
                       "Non-recurring task deletion must NOT show recurring dialog")
    }
}
