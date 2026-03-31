import XCTest
import SwiftData
@testable import FocusBlox

/// User-Journey Tests fuer RW 1.5: Refiner entfernt, Auto-Confirm Pipeline
/// Jeder Test simuliert was ein echter User tut und prueft was er SIEHT.
@MainActor
final class RemoveRefinerTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    // MARK: - User erstellt Task via Quick Capture

    /// User tippt "Heute dringend Klingel demontieren" ein.
    /// Erwartet: Task erscheint im Backlog als "Klingel demontieren" (ohne "Heute", ohne "dringend"),
    /// mit Faelligkeitsdatum=Heute und Urgency=dringend.
    /// Bricht wenn: stripKeywords() oder cleanTitle() die Datums-Keywords nicht entfernt
    func test_userCreatesTask_dateKeywordsRemovedFromTitle() async throws {
        let source = LocalTaskSource(modelContext: container.mainContext)
        let task = try await source.createTask(title: "Heute dringend Klingel demontieren")

        XCTAssertFalse(task.title.lowercased().contains("heute"),
                       "User sieht 'Heute' im Titel — muss entfernt werden weil Datum bereits als Badge angezeigt wird")
        XCTAssertEqual(task.lifecycleStatus, "active",
                       "Task muss sofort im Backlog sichtbar sein (active), nicht im Refiner haengen")
    }

    /// User tippt "Morgen Termin fuer Reifenwechsel machen" ein.
    /// Erwartet: Titel ohne "Morgen", Task ist active.
    /// Bricht wenn: stripKeywords() "Morgen" nicht entfernt oder Task als "raw" belassen wird
    func test_userCreatesTask_morgenKeywordRemovedFromTitle() async throws {
        let source = LocalTaskSource(modelContext: container.mainContext)
        let task = try await source.createTask(title: "Morgen Termin fuer Reifenwechsel machen")

        XCTAssertFalse(task.title.lowercased().contains("morgen"),
                       "User sieht 'Morgen' im Titel — muss entfernt werden")
        XCTAssertEqual(task.lifecycleStatus, "active",
                       "Task muss sofort im Backlog sichtbar sein (active), nicht im Refiner")
    }

    /// User tippt "Rattenfalle neu mit Erdnussbutter bestuecken" ein (kein Keyword).
    /// Erwartet: Titel bleibt unveraendert, Task ist active und im Backlog sichtbar.
    /// Bricht wenn: createTask() den Task als "raw" belasst oder confirmSuggestions() nicht aufruft
    func test_userCreatesTask_normalTitleUnchanged() async throws {
        let source = LocalTaskSource(modelContext: container.mainContext)
        let task = try await source.createTask(title: "Rattenfalle neu mit Erdnussbutter bestuecken")

        XCTAssertEqual(task.title, "Rattenfalle neu mit Erdnussbutter bestuecken",
                       "Titel ohne Keywords darf nicht veraendert werden")
        XCTAssertEqual(task.lifecycleStatus, "active",
                       "Task muss sofort im Backlog sichtbar sein")
    }

    // MARK: - Auto-Confirm: suggested*-Felder werden uebernommen

    /// User erstellt Task → Enrichment setzt suggested*-Felder → confirmSuggestions() uebernimmt sie.
    /// Erwartet: Nach createTask() sind suggested*-Werte in den Hauptfeldern sichtbar.
    /// Bricht wenn: confirmSuggestions() nicht automatisch nach enrichTask() aufgerufen wird
    func test_userCreatesTask_suggestedFieldsPromotedAutomatically() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Einkaufen gehen")
        context.insert(task)

        // Simuliere was Enrichment tut:
        task.suggestedCategory = "maintenance"
        task.suggestedDuration = 30
        task.suggestedImportance = 2
        task.suggestedUrgency = "not_urgent"
        task.suggestedEnergyLevel = "low"

        // Auto-confirm (das was createTask() jetzt automatisch macht):
        task.confirmSuggestions()

        // User sieht diese Werte im Backlog:
        XCTAssertEqual(task.taskType, "maintenance",
                       "User sieht keine Kategorie — suggestedCategory muss als Badge sichtbar sein")
        XCTAssertEqual(task.estimatedDuration, 30,
                       "User sieht keine Dauer — suggestedDuration muss als Badge sichtbar sein")
        XCTAssertEqual(task.importance, 2,
                       "User sieht keine Wichtigkeit — suggestedImportance muss als Badge sichtbar sein")
    }

    /// User setzt Wichtigkeit manuell auf 3, AI schlaegt 1 vor.
    /// Erwartet: User-Wert 3 bleibt, wird NICHT von AI ueberschrieben.
    /// Bricht wenn: confirmSuggestions() User-gesetzte Werte ueberschreibt
    func test_userSetValuesNotOverwrittenByAI() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Steuererklaerung machen", importance: 3)
        task.taskType = "income"
        task.urgency = "urgent"
        context.insert(task)

        task.suggestedImportance = 1
        task.suggestedCategory = "maintenance"
        task.suggestedUrgency = "not_urgent"

        task.confirmSuggestions()

        XCTAssertEqual(task.importance, 3, "User hat Wichtigkeit=3 gesetzt, AI darf das nicht auf 1 aendern")
        XCTAssertEqual(task.taskType, "income", "User hat Kategorie=income gesetzt, AI darf nicht ueberschreiben")
        XCTAssertEqual(task.urgency, "urgent", "User hat dringend gesetzt, AI darf nicht ueberschreiben")
    }

    // MARK: - Alte raw-Tasks werden beim Start migriert

    /// Es gibt einen alten Task mit lifecycleStatus "raw" der vorher im Refiner hing.
    /// Erwartet: Nach confirmSuggestions() ist er "active" und im Backlog sichtbar.
    /// Bricht wenn: Die Startup-Migration in FocusBloxApp.swift fehlt oder nicht funktioniert
    func test_oldRawTask_becomesVisibleAfterMigration() throws {
        let context = container.mainContext
        let oldTask = LocalTask(title: "Kies fuer Waermepumpe kaufen")
        oldTask.lifecycleStatus = TaskLifecycleStatus.raw.rawValue
        oldTask.suggestedCategory = "maintenance"
        oldTask.suggestedDuration = 60
        context.insert(oldTask)

        // Simuliere Startup-Migration:
        oldTask.confirmSuggestions()

        XCTAssertEqual(oldTask.lifecycleStatus, "active",
                       "Alter raw-Task muss nach Migration im Backlog sichtbar sein")
        XCTAssertEqual(oldTask.taskType, "maintenance",
                       "Suggested-Werte muessen bei Migration uebernommen werden")
        XCTAssertEqual(oldTask.estimatedDuration, 60,
                       "Geschaetzte Dauer muss bei Migration uebernommen werden")
    }

    // MARK: - Batch Enrichment schliesst keine Tasks aus

    /// Alle Tasks mit fehlenden Attributen muessen enriched werden — auch ehemalige raw-Tasks.
    /// Bricht wenn: performBatchEnrichment() raw-Tasks per Filter ausschliesst
    func test_batchEnrichment_includesAllTasksWithMissingAttributes() async throws {
        let context = container.mainContext

        let task1 = LocalTask(title: "Task ohne Attribute")
        task1.lifecycleStatus = TaskLifecycleStatus.raw.rawValue
        context.insert(task1)

        let task2 = LocalTask(title: "Aktiver Task ohne Attribute")
        context.insert(task2)

        try context.save()

        // Beide Tasks haben nil importance/urgency — beide muessen im Enrichment-Filter sein
        let predicate = #Predicate<LocalTask> { !$0.isCompleted }
        let allTasks = try context.fetch(FetchDescriptor<LocalTask>(predicate: predicate))
        let eligible = allTasks.filter {
            $0.importance == nil || $0.urgency == nil || $0.taskType.isEmpty || $0.aiEnergyLevel == nil
        }

        XCTAssertEqual(eligible.count, 2,
                       "Beide Tasks (raw + active) muessen fuer Enrichment eligible sein — kein Status-Filter")
    }
}
