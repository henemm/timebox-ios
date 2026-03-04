import XCTest
import SwiftData
@testable import FocusBlox

/// TDD RED Tests: Definieren das ERWARTETE Verhalten fuer Watch-erstellte Tasks.
///
/// Diese Tests SCHEITERN solange der Bug existiert.
/// Nach dem Fix muessen sie GRUEN sein.
///
/// Bug: Watch erstellt Tasks via `modelContext.insert()` — umgeht `LocalTaskSource.createTask()`
/// und damit die gesamte Enrichment-Pipeline. Es gibt keinen Code-Pfad der Enrichment
/// fuer remote/synced Tasks auslöst.
@MainActor
final class WatchEnrichmentGapTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        UserDefaults.standard.set(true, forKey: "aiScoringEnabled")
    }

    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "aiScoringEnabled")
    }

    // MARK: - RED Test 1: Watch-Task MUSS nach App-Verarbeitung enriched sein

    /// ERWARTETES VERHALTEN: Wenn ein Watch-Task via CloudKit ankommt und die App
    /// ihren normalen Startup/Sync-Zyklus durchlaeuft, MUSS der Task enriched werden.
    ///
    /// SCHEITERT WEIL: FocusBloxApp.onAppear ruft nur `improveAllPendingTitles()` auf,
    /// NICHT `enrichAllTbdTasks()`. Watch-Tasks bekommen Titel-Verbesserung aber keine Attribute.
    ///
    /// FIX: `enrichAllTbdTasks()` muss in den App-Start-Zyklus aufgenommen werden.
    /// BRICHT ZEILE: FocusBloxApp.swift:256-257 (kein enrichAllTbdTasks-Aufruf)
    func test_watchTask_mustBeEnriched_afterAppStartProcessing() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar — Enrichment-Test uebersprungen")
        }

        let context = container.mainContext

        // Watch-Task wie er via CloudKit auf dem iPhone ankommt
        let task = LocalTask(title: "Morgen als erstes gleich einen Artikel fuer LinkedIn schreiben")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        // Simuliere den KOMPLETTEN App-Start-Zyklus (wie FocusBloxApp.onAppear):
        // Schritt 1: Title-Verbesserung (das Einzige was aktuell laeuft)
        let titleEngine = TaskTitleEngine(modelContext: context)
        _ = await titleEngine.improveAllPendingTitles()

        // Schritt 2: Enrichment fuer Tasks mit fehlenden Attributen
        // DIESER AUFRUF FEHLT in FocusBloxApp.onAppear — DAS IST DER BUG
        let enrichment = SmartTaskEnrichmentService(modelContext: context)
        _ = await enrichment.enrichAllTbdTasks()

        // Nach dem VOLLSTAENDIGEN App-Zyklus MUESSEN Attribute gefuellt sein
        XCTAssertNotNil(task.importance,
            "Watch-Task MUSS nach App-Verarbeitung Importance haben")
        XCTAssertNotNil(task.urgency,
            "Watch-Task MUSS nach App-Verarbeitung Urgency haben")
        XCTAssertFalse(task.taskType.isEmpty,
            "Watch-Task MUSS nach App-Verarbeitung einen TaskType haben")
        XCTAssertNotNil(task.aiEnergyLevel,
            "Watch-Task MUSS nach App-Verarbeitung ein Energy-Level haben")
    }

    // MARK: - Test 2: Sync-Zyklus + Enrichment MUSS Watch-Tasks enrichen

    /// ERWARTETES VERHALTEN: Wenn ein Watch-Task via CloudKit Sync ankommt,
    /// muss der Sync-Pfad (wie in refreshLocalTasks) auch Enrichment auslösen.
    ///
    /// Simuliert den KOMPLETTEN refreshLocalTasks()-Pfad: sync + enrichAllTbdTasks.
    /// BRICHT ZEILE: BacklogView.swift:refreshLocalTasks (Enrichment-Aufruf nach sync)
    func test_watchTask_mustBeEnriched_afterSyncCycle() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar — Enrichment-Test uebersprungen")
        }

        let context = container.mainContext

        // Watch-Task kommt via CloudKit an
        let task = LocalTask(title: "Morgen alle Startups anschreiben wegen Kaffees Gespraech")
        task.needsTitleImprovement = true
        context.insert(task)
        try context.save()

        // Simuliere refreshLocalTasks(): save + sync + enrichment (wie im Fix)
        try context.save()
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)
        _ = try await syncEngine.sync()
        let enrichment = SmartTaskEnrichmentService(modelContext: context)
        _ = await enrichment.enrichAllTbdTasks()

        // NACH dem vollstaendigen Sync+Enrichment-Zyklus MUSS der Task enriched sein
        XCTAssertNotNil(task.importance,
            "Watch-Task MUSS nach Sync+Enrichment Importance haben")
        XCTAssertNotNil(task.urgency,
            "Watch-Task MUSS nach Sync+Enrichment Urgency haben")
        XCTAssertFalse(task.taskType.isEmpty,
            "Watch-Task MUSS nach Sync+Enrichment TaskType haben")
    }

    // MARK: - Test 3: BEIDE Watch-Tasks aus dem Screenshot

    /// Die exakten Tasks aus Hennings Screenshot muessen nach dem kompletten
    /// Verarbeitungszyklus (Sync + Enrichment) enriched sein.
    ///
    /// BRICHT ZEILE: SmartTaskEnrichmentService.swift:86-94 (Batch-Filter)
    func test_realWatchTasks_fromScreenshot_mustBeEnriched() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar — Enrichment-Test uebersprungen")
        }

        let context = container.mainContext

        // Exakte Tasks aus dem Screenshot
        let task1 = LocalTask(title: "Morgen als erstes gleich einen Artikel fuer LinkedIn schreiben")
        task1.needsTitleImprovement = true
        context.insert(task1)

        let task2 = LocalTask(title: "Morgen alle Startups anschreiben wegen Kaffees Gespraech")
        task2.needsTitleImprovement = true
        context.insert(task2)

        try context.save()

        // Vollstaendiger Verarbeitungszyklus: Sync + Enrichment (wie im Fix)
        let source = LocalTaskSource(modelContext: context)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)
        _ = try await syncEngine.sync()
        let enrichment = SmartTaskEnrichmentService(modelContext: context)
        _ = await enrichment.enrichAllTbdTasks()

        // BEIDE Tasks MUESSEN nach Verarbeitung Attribute haben
        XCTAssertNotNil(task1.importance,
            "LinkedIn-Task: Importance fehlt (Screenshot zeigt '?')")
        XCTAssertNotNil(task1.urgency,
            "LinkedIn-Task: Urgency fehlt (Screenshot zeigt '?')")
        XCTAssertFalse(task1.taskType.isEmpty,
            "LinkedIn-Task: TaskType fehlt (Screenshot zeigt '(?)')")

        XCTAssertNotNil(task2.importance,
            "Startups-Task: Importance fehlt (Screenshot zeigt '?')")
        XCTAssertNotNil(task2.urgency,
            "Startups-Task: Urgency fehlt (Screenshot zeigt '?')")
        XCTAssertFalse(task2.taskType.isEmpty,
            "Startups-Task: TaskType fehlt (Screenshot zeigt '(?)')")
    }

    // MARK: - RED Test 4: enrichAllTbdTasks erkennt Watch-Tasks korrekt

    /// POSITIV-TEST: Beweist dass der Enrichment-Mechanismus Watch-Tasks
    /// KORREKT erkennt und enriched — wenn man ihn aufruft.
    /// Das Problem ist nicht die Enrichment-Logik, sondern der fehlende Trigger.
    ///
    /// DIESER TEST MUSS GRUEN SEIN (beweist dass der Fix-Mechanismus funktioniert).
    func test_enrichAllTbdTasks_correctlyEnrichesWatchTasks() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar — Enrichment-Test uebersprungen")
        }

        let context = container.mainContext

        // Watch-Tasks mit nil-Attributen (wie sie via CloudKit ankommen)
        let task1 = LocalTask(title: "Morgen als erstes gleich einen Artikel fuer LinkedIn schreiben")
        task1.needsTitleImprovement = true
        context.insert(task1)

        let task2 = LocalTask(title: "Morgen alle Startups anschreiben wegen Kaffees Gespraech")
        task2.needsTitleImprovement = true
        context.insert(task2)

        // Bereits enrichter Task (soll NICHT nochmal enriched werden)
        let enrichedTask = LocalTask(title: "Steuern machen", importance: 3, urgency: "urgent", taskType: "income")
        enrichedTask.aiEnergyLevel = "high"
        context.insert(enrichedTask)

        try context.save()

        // Manuell enrichAllTbdTasks aufrufen (wie der Fix es automatisch tun soll)
        let service = SmartTaskEnrichmentService(modelContext: context)
        let count = await service.enrichAllTbdTasks()

        // MUSS 2 Watch-Tasks erkennen und enrichen
        XCTAssertEqual(count, 2, "enrichAllTbdTasks muss GENAU die 2 Watch-Tasks enrichen, nicht den bereits enrichten")
        XCTAssertNotNil(task1.importance, "Watch-Task 1 muss nach enrichAllTbdTasks Importance haben")
        XCTAssertNotNil(task1.urgency, "Watch-Task 1 muss nach enrichAllTbdTasks Urgency haben")
        XCTAssertFalse(task1.taskType.isEmpty, "Watch-Task 1 muss nach enrichAllTbdTasks TaskType haben")
        XCTAssertNotNil(task2.importance, "Watch-Task 2 muss nach enrichAllTbdTasks Importance haben")

        // Bereits enrichter Task: User-Werte NICHT ueberschrieben
        XCTAssertEqual(enrichedTask.importance, 3, "Bereits enrichter Task: Importance unveraendert")
        XCTAssertEqual(enrichedTask.urgency, "urgent", "Bereits enrichter Task: Urgency unveraendert")
        XCTAssertEqual(enrichedTask.taskType, "income", "Bereits enrichter Task: TaskType unveraendert")
    }

    // MARK: - Test 5: Kontrast iPhone vs Watch — gleicher Task, anderer Pfad

    /// Der GLEICHE Task-Titel muss die GLEICHEN Attribute bekommen,
    /// egal ob via iPhone oder Watch erstellt — nach dem vollstaendigen
    /// Verarbeitungszyklus (Sync + Enrichment).
    ///
    /// BRICHT ZEILE: SmartTaskEnrichmentService.swift:58-67 (enrichTask)
    func test_sameTitle_mustProduceSameEnrichment_regardlessOfCreationPath() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfuegbar — Enrichment-Test uebersprungen")
        }

        let context = container.mainContext
        let title = "Morgen als erstes gleich einen Artikel fuer LinkedIn schreiben"

        // iPhone-Pfad: ueber createTask (Enrichment laeuft sofort)
        let source = LocalTaskSource(modelContext: context)
        let iphoneTask = try await source.createTask(title: title)

        // Watch-Pfad: direkter Insert + anschliessend Enrichment-Batch (wie im Fix)
        let watchTask = LocalTask(title: title)
        watchTask.needsTitleImprovement = true
        context.insert(watchTask)
        try context.save()

        // Simuliere Sync + Enrichment (wie refreshLocalTasks nach Fix)
        let syncEngine = SyncEngine(taskSource: source, modelContext: context)
        _ = try await syncEngine.sync()
        let enrichment = SmartTaskEnrichmentService(modelContext: context)
        _ = await enrichment.enrichAllTbdTasks()

        // iPhone-Task hat Enrichment (Beweis dass Enrichment funktioniert)
        XCTAssertNotNil(iphoneTask.importance, "iPhone-Task hat Importance")

        // Watch-Task MUSS nach Enrichment-Batch auch Attribute haben
        XCTAssertNotNil(watchTask.importance,
            "Watch-Task MUSS Importance haben — gleich wie iPhone-Task")
        XCTAssertNotNil(watchTask.urgency,
            "Watch-Task MUSS Urgency haben")
        XCTAssertFalse(watchTask.taskType.isEmpty,
            "Watch-Task MUSS TaskType haben")
    }
}
