import XCTest

/// UI Tests für FEATURE backlog-tags-view
///
/// Testet die Tags-Ansicht im Backlog-Dropdown:
/// - AC1: "Tags" im Dropdown sichtbar, "Überfällig" nicht mehr
/// - AC2: Tasks werden nach Tag gruppiert (tagSection_<name>)
/// - AC3: "Heute"-Sektion steht vor allen Tag-Gruppen
/// - AC4: Tasks ohne Tag erscheinen in "Kein Tag"-Sektion (tagSection_noTag)
/// - AC5: NextUp-Tasks erscheinen nicht in ihrer Tag-Sektion (kein Duplikat)
///
/// TDD RED: Alle Tests FEHLSCHLAGEN weil die Tags-View noch nicht implementiert ist.
///
/// Identifier aus /inspect-ui (verifiziert):
///   viewModeSwitcher   — Button im NavigationBar, label "Priorität"
///   nextUpSection      — StaticText im Section-Header, label "Heute"
///   addTaskButton      — Button im NavigationBar
///
/// Neue Identifier aus Spec (noch nicht existierend → TDD RED):
///   tagSection_<name>  — Section-Header für benannte Tag-Gruppen
///   tagSection_noTag   — Section-Header für Tasks ohne Tag
///
/// Mock-Daten (aus FocusBloxApp.swift):
///   task1:        isNextUp=true,  tags=["feature","ui"]    → Heute
///   backlogTask1: isNextUp=false, tags=["work","urgent"]   → Backlog
///   backlogTask2: isNextUp=false, tags=[]                  → Backlog, kein Tag
final class BacklogTagsViewUITests: XCTestCase {

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

    // MARK: - Hilfsmethoden

    private func navigateToBacklog() {
        let backlogTab = app.tabBars.buttons["Backlog"]
        XCTAssertTrue(backlogTab.waitForExistence(timeout: 5), "Backlog-Tab muss vorhanden sein")
        backlogTab.tap()
    }

    private func openTagsView() {
        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5), "viewModeSwitcher muss vorhanden sein")
        switcher.tap()

        let tagsButton = app.buttons["Tags"]
        XCTAssertTrue(tagsButton.waitForExistence(timeout: 3), "Tags-Option muss im Dropdown erscheinen")
        tagsButton.tap()

        // Lade-Anker: Warte bis die Liste gerendert ist
        _ = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'nextUpSection'")
        ).firstMatch.waitForExistence(timeout: 3)
    }

    // MARK: - AC1

    /// Verhalten: Dropdown enthält "Tags" und kein "Überfällig" mehr.
    /// Bricht wenn: ViewMode.overdue wieder hinzugefügt wird ODER ViewMode.tags entfernt wird.
    func test_dropdown_zeigt_tags_und_nicht_ueberfaellig() throws {
        navigateToBacklog()

        let switcher = app.buttons["viewModeSwitcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5), "viewModeSwitcher muss vorhanden sein")
        switcher.tap()

        // "Tags" muss als Menü-Option erscheinen
        let tagsButton = app.buttons["Tags"]
        XCTAssertTrue(
            tagsButton.waitForExistence(timeout: 3),
            "AC1: 'Tags' muss als Dropdown-Option vorhanden sein"
        )

        // "Überfällig" darf nicht mehr im Dropdown erscheinen
        let ueberfaelligButton = app.buttons["Überfällig"]
        XCTAssertFalse(
            ueberfaelligButton.exists,
            "AC1: 'Überfällig' darf nicht mehr im Dropdown erscheinen — wurde durch 'Tags' ersetzt"
        )
    }

    // MARK: - AC2

    /// Verhalten: Task mit Tag "work" erscheint unter Section-Header tagSection_work.
    /// Bricht wenn: tasksByTag-Gruppierung fehlt oder Header-Identifier falsch gesetzt ist.
    /// Mock: "[MOCK] Backlog Task 1" hat tags=["work","urgent"] und isNextUp=false
    func test_task_mit_tag_erscheint_in_korrekter_tag_sektion() throws {
        navigateToBacklog()
        openTagsView()

        // tagSection_work muss als Section-Header sichtbar sein
        let tagSectionWork = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'tagSection_work'")
        ).firstMatch

        var found = tagSectionWork.waitForExistence(timeout: 3)
        if !found {
            app.swipeUp()
            found = tagSectionWork.waitForExistence(timeout: 3)
        }

        XCTAssertTrue(
            found,
            "AC2: Section-Header mit identifier 'tagSection_work' muss sichtbar sein " +
            "(Mock '[MOCK] Backlog Task 1' hat tag 'work')"
        )

        // "[MOCK] Backlog Task 1" muss in der Tags-View auffindbar sein
        let taskTitle = app.staticTexts.matching(
            NSPredicate(format: "label == '[MOCK] Backlog Task 1'")
        ).firstMatch

        var taskFound = taskTitle.waitForExistence(timeout: 3)
        if !taskFound {
            app.swipeUp()
            taskFound = taskTitle.waitForExistence(timeout: 3)
        }

        XCTAssertTrue(
            taskFound,
            "AC2: '[MOCK] Backlog Task 1' muss in der Tags-View in seiner Tag-Sektion sichtbar sein"
        )
    }

    // MARK: - AC3

    /// Verhalten: nextUpSection erscheint im Layout VOR dem ersten tagSection_*.
    /// Bricht wenn: nextUpListSection nicht an erster Stelle der tagsView steht.
    /// Mock: task1 hat isNextUp=true → Heute-Sektion;
    ///       backlogTask1 hat isNextUp=false, tags=["work","urgent"] → tagSection_work
    func test_heute_sektion_steht_vor_tag_sektionen() throws {
        navigateToBacklog()
        openTagsView()

        // nextUpSection-Header muss vorhanden sein (identifier aus /inspect-ui bestätigt)
        let nextUpSection = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'nextUpSection'")
        ).firstMatch
        XCTAssertTrue(
            nextUpSection.waitForExistence(timeout: 5),
            "AC3: nextUpSection muss in der Tags-View sichtbar sein"
        )

        // Mindestens eine Tag-Sektion muss vorhanden sein
        let anyTagSection = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'tagSection_'")
        ).firstMatch

        var tagFound = anyTagSection.waitForExistence(timeout: 3)
        if !tagFound {
            app.swipeUp()
            tagFound = anyTagSection.waitForExistence(timeout: 3)
        }

        XCTAssertTrue(
            tagFound,
            "AC3: Mindestens eine tagSection_* muss in der Tags-View sichtbar sein"
        )

        // nextUpSection muss weiter oben (kleinerer Y-Wert) liegen als die erste Tag-Sektion
        let nextUpY = nextUpSection.frame.minY
        let tagSectionY = anyTagSection.frame.minY

        XCTAssertLessThan(
            nextUpY, tagSectionY,
            "AC3: nextUpSection (y=\(nextUpY)) muss oberhalb der ersten Tag-Sektion (y=\(tagSectionY)) stehen"
        )
    }

    // MARK: - AC4

    /// Verhalten: Task ohne Tag erscheint in Sektion "Kein Tag" (identifier tagSection_noTag),
    ///            die ganz unten nach allen benannten Tag-Sektionen steht.
    /// Bricht wenn: Tasks ohne Tag gefiltert werden ODER tagSection_noTag-Identifier fehlt
    ///              ODER tagSection_noTag nicht am Ende steht.
    /// Mock: "[MOCK] Backlog Task 2" hat tags=[] und isNextUp=false
    func test_task_ohne_tag_erscheint_in_kein_tag_sektion() throws {
        navigateToBacklog()
        openTagsView()

        // Bis ans Ende scrollen — tagSection_noTag steht laut Spec immer ganz unten
        for _ in 0..<6 {
            app.swipeUp()
        }

        let noTagSection = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'tagSection_noTag'")
        ).firstMatch

        XCTAssertTrue(
            noTagSection.waitForExistence(timeout: 5),
            "AC4: tagSection_noTag muss sichtbar sein — Mock '[MOCK] Backlog Task 2' hat keine Tags"
        )

        // Alle benannten Tag-Sektionen müssen ÜBER tagSection_noTag liegen
        let namedTagSections = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'tagSection_' AND identifier != 'tagSection_noTag'")
        )
        let noTagY = noTagSection.frame.minY

        let count = namedTagSections.count
        for i in 0..<count {
            let namedSection = namedTagSections.element(boundBy: i)
            if namedSection.exists {
                XCTAssertLessThan(
                    namedSection.frame.minY, noTagY,
                    "AC4: Benannte Tag-Sektion '\(namedSection.identifier)' " +
                    "(y=\(namedSection.frame.minY)) muss ÜBER 'Kein Tag' (y=\(noTagY)) stehen"
                )
            }
        }
    }

    // MARK: - AC5

    /// Verhalten: Task der in "Heute" (NextUp) ist, erscheint NICHT in seiner Tag-Sektion.
    /// Bricht wenn: tasksByTag den nextUpTasks-Filter nicht anwendet.
    /// Mock: task1 hat isNextUp=true und tags=["feature","ui"]
    ///       → nur in nextUpSection, NICHT in tagSection_feature
    func test_nextup_task_erscheint_nicht_in_tag_sektion() throws {
        navigateToBacklog()
        openTagsView()

        // Lade-Anker: Tags-View vollständig gerendert
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "App muss geladen sein")

        // Durch die gesamte Liste scrollen um sicherzustellen dass alle Sektionen gerendert sind
        app.swipeUp()
        app.swipeUp()
        app.swipeDown()
        app.swipeDown()

        // tagSection_feature darf NICHT existieren:
        // Der einzige Task mit tag "feature" (task1) ist isNextUp=true
        // → muss aus tasksByTag gefiltert sein
        let tagSectionFeature = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'tagSection_feature'")
        ).firstMatch

        XCTAssertFalse(
            tagSectionFeature.waitForExistence(timeout: 2),
            "AC5: tagSection_feature darf NICHT existieren — " +
            "der einzige 'feature'-Task ist NextUp und muss aus Tag-Sektionen herausgefiltert sein"
        )

        // Der Task muss weiterhin in der Heute-Sektion sichtbar sein (nicht verschwunden)
        let nextUpTask = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Dark Mode'")
        ).firstMatch
        XCTAssertTrue(
            nextUpTask.waitForExistence(timeout: 3),
            "AC5: '[MOCK] Feature: Dark Mode fuer Settings' muss weiterhin in nextUpSection sichtbar sein"
        )
    }
}
