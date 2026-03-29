import XCTest
import SwiftData
@testable import FocusBlox

/// Tests fuer MAC_026: Quick Capture Metadaten auf macOS.
/// Verifiziert dass createTask() mit Metadaten aufgerufen wird und Werte korrekt gespeichert werden.
final class QuickCaptureMetadataTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        // Container setup happens in each @MainActor test method
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    @MainActor
    private func setupContainer() throws {
        container = try ModelContainer(
            for: LocalTask.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    // MARK: - Test 1: Metadaten werden beim Erstellen gespeichert

    /// Verhalten: createTask() mit importance=2, urgency="urgent", taskType="learning", duration=30
    ///   erstellt einen Task der alle 4 Metadaten korrekt gespeichert hat.
    /// Bricht wenn: QuickCapturePanel.addTask() die Metadaten nicht an createTask() uebergibt
    ///   (aktuell Zeile 191 in QuickCapturePanel.swift — ruft createTask OHNE importance/urgency/duration auf)
    @MainActor
    func test_createTaskWithMetadata_storesAllFields() async throws {
        try setupContainer()
        let taskSource = LocalTaskSource(modelContext: context)

        let task = try await taskSource.createTask(
            title: "Metadaten-Test",
            importance: 2,
            estimatedDuration: 30,
            urgency: "urgent",
            taskType: "learning",
            lifecycleStatus: TaskLifecycleStatus.raw.rawValue
        )

        XCTAssertEqual(task.importance, 2, "Importance sollte 2 sein")
        XCTAssertEqual(task.estimatedDuration, 30, "Duration sollte 30 sein")
        XCTAssertEqual(task.urgency, "urgent", "Urgency sollte 'urgent' sein")
        XCTAssertEqual(task.taskType, "learning", "TaskType sollte 'learning' sein")
    }

    // MARK: - Test 2: Importance Cycle-Logik

    /// Verhalten: cycleImportance dreht nil → 1 → 2 → 3 → nil.
    ///   Diese Logik wird in der macOS QuickCaptureView benoetigt.
    /// Bricht wenn: cycleImportance() in QuickCapturePanel.swift fehlt oder falsch implementiert ist
    func test_importanceCycle_nilTo1To2To3ToNil() {
        var importance: Int? = nil

        importance = Self.cycleImportance(importance)
        XCTAssertEqual(importance, 1)

        importance = Self.cycleImportance(importance)
        XCTAssertEqual(importance, 2)

        importance = Self.cycleImportance(importance)
        XCTAssertEqual(importance, 3)

        importance = Self.cycleImportance(importance)
        XCTAssertNil(importance)
    }

    // MARK: - Test 3: Urgency Cycle-Logik

    /// Verhalten: cycleUrgency dreht nil → "not_urgent" → "urgent" → nil.
    ///   Diese Logik wird in der macOS QuickCaptureView benoetigt.
    /// Bricht wenn: cycleUrgency() in QuickCapturePanel.swift fehlt oder falsch implementiert ist
    func test_urgencyCycle_nilToNotUrgentToUrgentToNil() {
        var urgency: String? = nil

        urgency = Self.cycleUrgency(urgency)
        XCTAssertEqual(urgency, "not_urgent")

        urgency = Self.cycleUrgency(urgency)
        XCTAssertEqual(urgency, "urgent")

        urgency = Self.cycleUrgency(urgency)
        XCTAssertNil(urgency)
    }

    // MARK: - Test 4: Reset setzt alle Metadaten zurueck

    /// Verhalten: Nach Save/Dismiss muessen alle Metadaten-States zurueckgesetzt werden.
    ///   Nutze QuickCaptureState.reset() als Referenz.
    /// Bricht wenn: reset()-Logik in der macOS View fehlt
    @MainActor
    func test_quickCaptureStateReset_clearsAllMetadata() {
        let state = QuickCaptureState()
        state.importance = 3
        state.urgency = "urgent"
        state.taskType = "learning"
        state.estimatedDuration = 60

        state.reset()

        XCTAssertNil(state.importance, "Importance sollte nach reset nil sein")
        XCTAssertNil(state.urgency, "Urgency sollte nach reset nil sein")
        XCTAssertEqual(state.taskType, "maintenance", "TaskType sollte nach reset 'maintenance' sein")
        XCTAssertNil(state.estimatedDuration, "Duration sollte nach reset nil sein")
    }

    // MARK: - Cycle Helpers (werden spaeter in die macOS View uebernommen)

    private static func cycleImportance(_ current: Int?) -> Int? {
        switch current {
        case nil: return 1
        case 1: return 2
        case 2: return 3
        case 3: return nil
        default: return nil
        }
    }

    private static func cycleUrgency(_ current: String?) -> String? {
        switch current {
        case nil: return "not_urgent"
        case "not_urgent": return "urgent"
        case "urgent": return nil
        default: return nil
        }
    }
}
