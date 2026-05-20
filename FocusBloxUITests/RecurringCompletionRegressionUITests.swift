import XCTest

/// Smoke-Test für Bug #315: Wiederkehrender Task erscheint nach dem Abhaken nicht mehr.
///
/// Testet das sichtbare Symptom aus User-Perspektive: nach dem Abhaken einer
/// recurring-Task-Instanz muss die gleiche Serie wieder im Backlog sichtbar sein.
final class RecurringCompletionRegressionUITests: XCTestCase {

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

    // MARK: - Helper: Navigiere zum Backlog-Tab

    private func navigateToBacklog() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(
            backlogTab.waitForExistence(timeout: 10),
            "Backlog-Tab muss existieren"
        )
        backlogTab.tap()
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 10),
            "Backlog muss vollständig geladen sein (addTaskButton fehlt)"
        )
    }

    // MARK: - Helper: Scrolle durch die Liste um einen Task zu finden

    /// Scrollt durch den Backlog bis ein StaticText mit dem gesuchten Titel sichtbar wird.
    /// Gibt das Element zurück wenn gefunden (isHittable), sonst nil.
    private func findTaskByTitle(_ title: String, maxScrolls: Int = 8) -> XCUIElement? {
        let list = app.collectionViews["backlogTaskList"].exists
            ? app.collectionViews["backlogTaskList"]
            : (app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch)

        // Erst ohne Scrollen prüfen
        let initial = app.staticTexts.matching(NSPredicate(format: "label == %@", title))
        if initial.count > 0 {
            let el = initial.element(boundBy: 0)
            if el.isHittable { return el }
        }

        // Dann scrollen
        for _ in 0..<maxScrolls {
            list.swipeUp()
            let scrolled = app.staticTexts.matching(NSPredicate(format: "label == %@", title))
            if scrolled.count > 0 {
                let el = scrolled.element(boundBy: 0)
                if el.isHittable { return el }
            }
        }
        return nil
    }

    // MARK: - Helper: Suche completeButton auf gleicher Y-Höhe wie ein Element

    private func findCompleteButton(near element: XCUIElement) -> XCUIElement? {
        let titleFrame = element.frame
        let allCompleteButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'completeButton_' AND label == 'Als erledigt markieren'")
        ).allElementsBoundByIndex

        return allCompleteButtons.first { btn in
            abs(btn.frame.midY - titleFrame.midY) < 60
        }
    }

    // MARK: - Test 1: Mock-Task ist nach App-Start im Backlog sichtbar

    /// Verhalten: "[MOCK] Taeglich lesen" erscheint im Backlog (Scroll falls nötig).
    /// Bricht wenn: seedUITestData() den Task nicht korrekt anlegt,
    ///              oder BacklogView ihn filtert/ausblendet.
    func test_mockRecurringTaskVisibleOnLaunch() throws {
        try navigateToBacklog()

        let found = findTaskByTitle("[MOCK] Taeglich lesen")
        XCTAssertNotNil(
            found,
            "Bug #315: '[MOCK] Taeglich lesen' muss nach App-Start im Backlog sichtbar sein. " +
            "Entweder fehlt der Task oder er wurde durch einen Filter ausgeblendet."
        )
    }

    // MARK: - Test 2: Nach dem Abhaken erscheint die Serie wieder (Kern-Regression)

    /// Verhalten: Nach dem Abhaken eines daily recurring Tasks muss der Titel
    /// im Backlog sichtbar bleiben (entweder gleiche oder neue Instanz).
    ///
    /// Bricht wenn: Bug #315 aktiv ist — kein Nachfolger wird erstellt und
    ///              die Serie stirbt komplett aus dem Backlog.
    func test_afterCompletingRecurringTask_seriesRemainsVisible() throws {
        try navigateToBacklog()

        let taskTitle = "[MOCK] Taeglich lesen"

        // 1. Precondition: Task mit Scroll finden
        guard let titleElement = findTaskByTitle(taskTitle) else {
            XCTFail(
                "Precondition: '[MOCK] Taeglich lesen' muss vor dem Abhaken im Backlog sichtbar sein."
            )
            return
        }

        // 2. completeButton auf gleicher Y-Höhe wie der Titel finden und tippen
        guard let button = findCompleteButton(near: titleElement) else {
            XCTFail(
                "Es muss einen 'Als erledigt markieren' Button für '[MOCK] Taeglich lesen' geben."
            )
            return
        }
        button.tap()

        // 3. Kurz warten damit die Completion verarbeitet wird (~1.5s deferred)
        Thread.sleep(forTimeInterval: 3.0)

        // 4. Prüfen ob der Titel noch im Backlog sichtbar ist (andere Instanz oder gleichzeitig)
        // Zurück an den Anfang der Liste scrollen
        let list = app.collectionViews["backlogTaskList"].exists
            ? app.collectionViews["backlogTaskList"]
            : app.collectionViews.firstMatch
        if list.exists {
            list.swipeDown()
            list.swipeDown()
        }

        let remaining = findTaskByTitle(taskTitle)
        XCTAssertNotNil(
            remaining,
            "Bug #315 REPRODUZIERT: '[MOCK] Taeglich lesen' erscheint nach dem Abhaken NICHT mehr im Backlog. " +
            "Die recurring Serie spawnt keine neue Instanz oder eine andere Instanz sollte noch sichtbar sein."
        )
    }

    // MARK: - Test 3: Weekly recurring Task bleibt ebenfalls sichtbar (Regression)

    /// Verhalten: "[MOCK] Wochenreview" muss nach dem Abhaken ebenfalls wieder sichtbar sein.
    /// Bricht wenn: Bug #315 auch weekly Tasks betrifft.
    func test_afterCompletingWeeklyTask_seriesRemainsVisible() throws {
        try navigateToBacklog()

        let taskTitle = "[MOCK] Wochenreview"

        // 1. Precondition: Task mit Scroll finden
        guard let titleElement = findTaskByTitle(taskTitle) else {
            XCTFail(
                "Precondition: '[MOCK] Wochenreview' muss vor dem Abhaken im Backlog sichtbar sein."
            )
            return
        }

        // 2. completeButton finden und tippen
        guard let button = findCompleteButton(near: titleElement) else {
            XCTFail(
                "Es muss einen 'Als erledigt markieren' Button für '[MOCK] Wochenreview' geben."
            )
            return
        }
        button.tap()

        // 3. Kurz warten
        Thread.sleep(forTimeInterval: 3.0)

        // 4. Zurück scrollen und prüfen
        let list = app.collectionViews["backlogTaskList"].exists
            ? app.collectionViews["backlogTaskList"]
            : app.collectionViews.firstMatch
        if list.exists {
            list.swipeDown()
            list.swipeDown()
        }

        let remaining = findTaskByTitle(taskTitle)
        XCTAssertNotNil(
            remaining,
            "Bug #315 REPRODUZIERT (weekly): '[MOCK] Wochenreview' erscheint nach dem Abhaken NICHT mehr. " +
            "Weekly recurring Tasks spawnen keine neue Instanz."
        )
    }
}
