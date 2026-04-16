import XCTest
import SwiftData
@testable import FocusBlox

/// Feature #235: AI schlägt Tags vor beim Task-Erstellen
/// Tests für suggestedTags — sowohl Live (Formular) als auch Hintergrund-Enrichment.
@MainActor
final class AITagSuggestionsTests: XCTestCase {

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

    // MARK: - LocalTask Model: suggestedTags Feld

    /// GIVEN: Ein neuer Task ohne Tags
    /// WHEN: suggestedTags gesetzt wird
    /// THEN: Wert wird korrekt gespeichert und geladen
    func test_localTask_suggestedTags_persistsCorrectly() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Rasen mähen")
        task.suggestedTags = ["garten", "zuhause"]
        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<LocalTask>()
        let fetched = try context.fetch(descriptor).first!
        XCTAssertEqual(fetched.suggestedTags, ["garten", "zuhause"],
                       "suggestedTags muss persistiert werden")
    }

    /// GIVEN: Ein neuer Task
    /// WHEN: suggestedTags nicht gesetzt
    /// THEN: Default ist nil
    func test_localTask_suggestedTags_defaultIsNil() throws {
        let context = container.mainContext
        let task = LocalTask(title: "Test Task")
        context.insert(task)
        try context.save()

        XCTAssertNil(task.suggestedTags,
                     "suggestedTags Default muss nil sein")
    }

    // MARK: - Hintergrund-Enrichment: suggestedTags werden gesetzt

    /// GIVEN: Ein Task ohne manuelle Tags
    /// WHEN: performEnrichment() läuft (Hintergrund)
    /// THEN: suggestedTags wird mit 1-3 Vorschlägen befüllt
    func test_enrichment_setsSuggestedTags_whenNoManualTags() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfügbar")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Rasen mähen")
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        XCTAssertNotNil(task.suggestedTags,
                        "suggestedTags muss nach Enrichment gesetzt sein")
        XCTAssertFalse((task.suggestedTags ?? []).isEmpty,
                       "suggestedTags darf nicht leer sein für 'Rasen mähen'")
        XCTAssertLessThanOrEqual((task.suggestedTags ?? []).count, 3,
                                "Maximal 3 Tag-Vorschläge erlaubt")
    }

    /// GIVEN: Ein Task MIT manuellen Tags
    /// WHEN: performEnrichment() läuft
    /// THEN: suggestedTags wird NICHT gesetzt (User hat schon Tags)
    func test_enrichment_skipsTagSuggestions_whenManualTagsExist() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfügbar")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Rasen mähen", tags: ["garten"])
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        XCTAssertNil(task.suggestedTags,
                     "suggestedTags darf nicht gesetzt werden wenn User schon Tags hat")
    }

    // MARK: - TaskEnrichment: suggestedTags via Enrichment

    /// GIVEN: TaskEnrichment @Generable struct hat suggestedTags Feld
    /// WHEN: Enrichment läuft
    /// THEN: suggestedTags werden auf dem Task gespeichert
    func test_taskEnrichment_suggestedTags_existsViaEnrichment() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfügbar")
        }

        let context = container.mainContext
        let task = LocalTask(title: "Wäsche waschen")
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        // Wenn TaskEnrichment.suggestedTags existiert, wird es via performEnrichment auf den Task geschrieben
        XCTAssertNotNil(task.suggestedTags,
                        "suggestedTags muss nach Enrichment gesetzt sein — beweist TaskEnrichment.suggestedTags Feld")
    }

    // MARK: - Live-Vorschläge: suggestTagsForTitle()

    /// GIVEN: Titel "Rasen mähen" und bestehende Tags ["garten", "computer", "einkauf"]
    /// WHEN: suggestTagsForTitle() aufgerufen
    /// THEN: Gibt 1-3 passende Tags zurück
    func test_suggestTagsForTitle_returnsRelevantTags() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfügbar")
        }

        let context = container.mainContext
        let service = SmartTaskEnrichmentService(modelContext: context)
        let result = await service.suggestTagsForTitle(
            "Rasen mähen",
            existingTags: ["garten", "computer", "einkauf"]
        )

        XCTAssertFalse(result.isEmpty, "Muss mindestens 1 Tag vorschlagen für 'Rasen mähen'")
        XCTAssertLessThanOrEqual(result.count, 3, "Maximal 3 Vorschläge")
    }

    /// GIVEN: Titel "Einkaufen gehen" und leere existingTags
    /// WHEN: suggestTagsForTitle() aufgerufen
    /// THEN: Gibt Vorschläge aus Seed-Tags zurück
    func test_suggestTagsForTitle_usesSeedTags_whenNoExistingTags() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfügbar")
        }

        let context = container.mainContext
        let service = SmartTaskEnrichmentService(modelContext: context)
        let result = await service.suggestTagsForTitle(
            "Einkaufen gehen",
            existingTags: []
        )

        XCTAssertFalse(result.isEmpty, "Muss auch ohne existingTags Vorschläge liefern (Seed-Tags)")
    }

    /// GIVEN: suggestTagsForTitle() mit AI deaktiviert
    /// WHEN: Aufgerufen
    /// THEN: Gibt leeres Array zurück (kein Crash)
    func test_suggestTagsForTitle_returnsEmpty_whenDisabled() async throws {
        UserDefaults.standard.set(false, forKey: "aiScoringEnabled")

        let context = container.mainContext
        let service = SmartTaskEnrichmentService(modelContext: context)
        let result = await service.suggestTagsForTitle(
            "Rasen mähen",
            existingTags: ["garten"]
        )

        XCTAssertTrue(result.isEmpty, "Muss leeres Array zurückgeben wenn AI deaktiviert")
    }

    // MARK: - Seed-Tags

    /// GIVEN: SmartTaskEnrichmentService
    /// WHEN: seedTags abgefragt
    /// THEN: Enthält die 5 definierten Basis-Tags
    func test_seedTags_containsExpectedBaseTags() {
        let seeds = SmartTaskEnrichmentService.seedTags
        XCTAssertEqual(seeds.count, 5, "Seed-Set muss genau 5 Tags enthalten")
        XCTAssertTrue(seeds.contains("computer"), "Seed muss 'computer' enthalten")
        XCTAssertTrue(seeds.contains("telefon"), "Seed muss 'telefon' enthalten")
        XCTAssertTrue(seeds.contains("unterwegs"), "Seed muss 'unterwegs' enthalten")
        XCTAssertTrue(seeds.contains("zuhause"), "Seed muss 'zuhause' enthalten")
        XCTAssertTrue(seeds.contains("einkauf"), "Seed muss 'einkauf' enthalten")
    }

    // MARK: - Maximal 1 neuer Tag

    /// GIVEN: AI gibt Tag-Vorschläge zurück
    /// WHEN: Vorschläge gefiltert werden
    /// THEN: Maximal 1 Tag darf NICHT in existingTags sein
    func test_enrichment_maxOneNewTag() async throws {
        guard SmartTaskEnrichmentService.isAvailable else {
            throw XCTSkip("Apple Intelligence nicht verfügbar")
        }

        let context = container.mainContext
        let existingTags = ["computer", "telefon", "unterwegs", "zuhause", "einkauf"]

        // Erstelle Tasks mit den Tags damit fetchAllUsedTags() sie findet
        for tag in existingTags {
            let t = LocalTask(title: "Task mit \(tag)", tags: [tag])
            context.insert(t)
        }

        let task = LocalTask(title: "Rasen mähen")
        context.insert(task)
        try context.save()

        let service = SmartTaskEnrichmentService(modelContext: context)
        await service.enrichTask(task)

        let suggestions = task.suggestedTags ?? []
        let newTags = suggestions.filter { !existingTags.contains($0) }
        XCTAssertLessThanOrEqual(newTags.count, 1,
                                "Maximal 1 neuer Tag erlaubt, gefunden: \(newTags)")
    }
}
