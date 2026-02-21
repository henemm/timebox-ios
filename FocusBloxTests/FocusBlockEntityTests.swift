import XCTest
@testable import FocusBlox

/// Tests for FocusBlockEntity — AppEntity for Siri/Shortcuts integration.
/// All tests MUST FAIL in TDD RED because FocusBlockEntity doesn't exist yet.
final class FocusBlockEntityTests: XCTestCase {

    // MARK: - Entity Creation from FocusBlock

    /// Verhalten: FocusBlockEntity lässt sich aus einem FocusBlock erstellen
    /// Bricht wenn: FocusBlockEntity.init(from:) nicht existiert oder falsch mappt
    func test_entityFromBlock_mapsAllFields() {
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour
        let block = FocusBlock(
            id: "event-123",
            title: "Deep Work",
            startDate: start,
            endDate: end,
            taskIDs: ["task-1", "task-2"],
            completedTaskIDs: ["task-1"]
        )

        let entity = FocusBlockEntity(from: block)

        XCTAssertEqual(entity.id, "event-123")
        XCTAssertEqual(entity.title, "Deep Work")
        XCTAssertEqual(entity.startDate, start)
        XCTAssertEqual(entity.endDate, end)
        XCTAssertEqual(entity.taskCount, 2)
        XCTAssertEqual(entity.completedTaskCount, 1)
        XCTAssertEqual(entity.durationMinutes, 60)
    }

    /// Verhalten: Entity berechnet Dauer korrekt für verschiedene Zeitspannen
    /// Bricht wenn: durationMinutes falsch berechnet wird
    func test_entityFromBlock_calculatesCorrectDuration() {
        let start = Date()
        let end = start.addingTimeInterval(5400) // 90 minutes
        let block = FocusBlock(
            id: "event-456",
            title: "Planning",
            startDate: start,
            endDate: end
        )

        let entity = FocusBlockEntity(from: block)

        XCTAssertEqual(entity.durationMinutes, 90)
    }

    /// Verhalten: Entity mit leeren Task-Listen hat 0 Counts
    /// Bricht wenn: Default-Werte für taskCount/completedTaskCount falsch
    func test_entityFromBlock_emptyTasks_hasZeroCounts() {
        let start = Date()
        let end = start.addingTimeInterval(1800)
        let block = FocusBlock(
            id: "event-789",
            title: "Focus",
            startDate: start,
            endDate: end
        )

        let entity = FocusBlockEntity(from: block)

        XCTAssertEqual(entity.taskCount, 0)
        XCTAssertEqual(entity.completedTaskCount, 0)
    }

    // MARK: - Display Representation

    /// Verhalten: DisplayRepresentation zeigt Titel und Dauer
    /// Bricht wenn: displayRepresentation nicht korrekt formatiert
    func test_displayRepresentation_showsTitleAndDuration() {
        let start = Date()
        let end = start.addingTimeInterval(3600)

        let entity = FocusBlockEntity(
            id: "test-1",
            title: "Deep Work",
            startDate: start,
            endDate: end,
            durationMinutes: 60,
            taskCount: 3,
            completedTaskCount: 1
        )

        let repr = entity.displayRepresentation
        // title is a LocalizedStringResource — check it's not empty
        XCTAssertNotNil(repr.title)
        // Subtitle should contain duration and task info
        XCTAssertNotNil(repr.subtitle)
    }
}
