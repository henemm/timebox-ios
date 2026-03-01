import XCTest
import CoreSpotlight
@testable import FocusBlox

/// Tests for SpotlightIndexingService (ITB-G2).
/// Verifies that tasks are correctly indexed/deindexed in Spotlight.
final class SpotlightIndexingServiceTests: XCTestCase {

    // MARK: - Attribute Building Tests

    /// Verhalten: buildAttributeSet erstellt korrekte Spotlight-Attribute aus LocalTask
    /// Bricht wenn: SpotlightIndexingService.buildAttributeSet() nicht existiert oder title/description falsch setzt
    func test_buildAttributeSet_setsTitle() async throws {
        let task = LocalTask(title: "Einkaufen gehen")
        task.taskDescription = "Milch, Brot, Butter"

        let attributes = await SpotlightIndexingService.shared.buildAttributeSet(for: task)

        XCTAssertEqual(attributes.title, "Einkaufen gehen")
        XCTAssertEqual(attributes.contentDescription, "Milch, Brot, Butter")
    }

    /// Verhalten: buildAttributeSet setzt Tags als Keywords
    /// Bricht wenn: tags-Mapping in buildAttributeSet fehlt oder falsch ist
    func test_buildAttributeSet_setsTagsAsKeywords() async throws {
        let task = LocalTask(title: "Shopping")
        task.tags = ["groceries", "weekend"]

        let attributes = await SpotlightIndexingService.shared.buildAttributeSet(for: task)

        XCTAssertNotNil(attributes.keywords)
        XCTAssertTrue(attributes.keywords!.contains("groceries"))
        XCTAssertTrue(attributes.keywords!.contains("weekend"))
    }

    /// Verhalten: buildAttributeSet setzt taskType als Keyword
    /// Bricht wenn: taskType nicht in keywords aufgenommen wird
    func test_buildAttributeSet_includesTaskTypeInKeywords() async throws {
        let task = LocalTask(title: "Klavier ueben")
        task.taskType = "recharge"

        let attributes = await SpotlightIndexingService.shared.buildAttributeSet(for: task)

        XCTAssertNotNil(attributes.keywords)
        XCTAssertTrue(attributes.keywords!.contains("recharge"))
    }

    // MARK: - Filter Tests (shouldIndex)

    /// Verhalten: Erledigte Tasks werden NICHT indexiert
    /// Bricht wenn: guard !task.isCompleted in shouldIndex/indexTask entfernt wird
    func test_shouldIndex_returnsFalse_forCompletedTask() async {
        let task = LocalTask(title: "Done")
        task.isCompleted = true

        let result = await SpotlightIndexingService.shared.shouldIndex(task)

        XCTAssertFalse(result)
    }

    /// Verhalten: Recurring Templates werden NICHT indexiert
    /// Bricht wenn: guard !task.isTemplate in shouldIndex entfernt wird
    func test_shouldIndex_returnsFalse_forTemplate() async {
        let task = LocalTask(title: "Template")
        task.isTemplate = true

        let result = await SpotlightIndexingService.shared.shouldIndex(task)

        XCTAssertFalse(result)
    }

    /// Verhalten: Aktive, nicht-Template Tasks werden indexiert
    /// Bricht wenn: shouldIndex faelschlicherweise false fuer normale Tasks zurueckgibt
    func test_shouldIndex_returnsTrue_forActiveTask() async {
        let task = LocalTask(title: "Active")
        task.isCompleted = false
        task.isTemplate = false

        let result = await SpotlightIndexingService.shared.shouldIndex(task)

        XCTAssertTrue(result)
    }

    /// Verhalten: Recurring Instanzen (nicht Templates) werden indexiert
    /// Bricht wenn: recurrencePattern-Check faelschlicherweise Instanzen filtert
    func test_shouldIndex_returnsTrue_forRecurringInstance() async {
        let task = LocalTask(title: "Daily Standup")
        task.recurrencePattern = "daily"
        task.isTemplate = false
        task.isCompleted = false

        let result = await SpotlightIndexingService.shared.shouldIndex(task)

        XCTAssertTrue(result)
    }

    // MARK: - Unique Identifier

    /// Verhalten: CSSearchableItem bekommt task.uuid als uniqueIdentifier
    /// Bricht wenn: uniqueIdentifier nicht auf uuid.uuidString gesetzt wird
    func test_buildSearchableItem_usesUUIDAsIdentifier() async throws {
        let task = LocalTask(title: "ID Test")
        let expectedID = task.uuid.uuidString

        let item = try await SpotlightIndexingService.shared.buildSearchableItem(for: task)

        XCTAssertEqual(item.uniqueIdentifier, expectedID)
    }

    /// Verhalten: domainIdentifier ist "com.focusblox.tasks"
    /// Bricht wenn: domainIdentifier geaendert wird (batch-delete wuerde dann nicht funktionieren)
    func test_buildSearchableItem_usesCorrectDomain() async throws {
        let task = LocalTask(title: "Domain Test")

        let item = try await SpotlightIndexingService.shared.buildSearchableItem(for: task)

        XCTAssertEqual(item.domainIdentifier, "com.focusblox.tasks")
    }
}
