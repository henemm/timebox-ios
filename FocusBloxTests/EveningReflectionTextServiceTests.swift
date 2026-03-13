import XCTest
@testable import FocusBlox

/// Unit Tests for EveningReflectionTextService (Monster Coach Phase 3d).
///
/// Tests the prompt construction, guard conditions, and fallback integration.
/// AI output quality is NOT tested (non-deterministic) — only structure and guards.
///
/// EXPECTED TO FAIL (TDD RED): EveningReflectionTextService does not exist yet.
@MainActor
final class EveningReflectionTextServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTask(
        title: String = "Test",
        importance: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        taskType: String = ""
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: importance)
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.taskType = taskType
        return task
    }

    private func makeBlock(
        id: String = "block-1",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(3600),
        taskIDs: [String] = [],
        completedTaskIDs: [String] = []
    ) -> FocusBlock {
        FocusBlock(
            id: id, title: "Focus",
            startDate: startDate, endDate: endDate,
            taskIDs: taskIDs, completedTaskIDs: completedTaskIDs
        )
    }

    private var today: Date { Date() }

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    // MARK: - Availability

    /// Verhalten: isAvailable gibt einen konsistenten Bool zurueck.
    /// Bricht wenn: isAvailable Property nicht existiert auf EveningReflectionTextService.
    func test_isAvailable_returnsBool() {
        let available = EveningReflectionTextService.isAvailable
        XCTAssertEqual(
            available, EveningReflectionTextService.isAvailable,
            "isAvailable should return consistent results"
        )
    }

    // MARK: - Guard: AI Disabled

    /// Verhalten: generateText gibt nil zurueck wenn aiScoringEnabled == false.
    /// Bricht wenn: Der guard AppSettings.shared.aiScoringEnabled Zeile in generateText() fehlt.
    func test_generateText_returnsNilWhenAiDisabled() async {
        let previousValue = AppSettings.shared.aiScoringEnabled
        AppSettings.shared.aiScoringEnabled = false
        defer { AppSettings.shared.aiScoringEnabled = previousValue }

        let service = EveningReflectionTextService()
        let result = await service.generateText(
            intention: .fokus,
            level: .fulfilled,
            tasks: [],
            focusBlocks: []
        )

        XCTAssertNil(result, "Should return nil when AI is disabled")
    }

    /// Verhalten: generateTexts gibt leeres Dictionary zurueck wenn aiScoringEnabled == false.
    /// Bricht wenn: Der guard in generateTexts() die aiScoringEnabled-Pruefung nicht hat.
    func test_generateTexts_returnsEmptyWhenAiDisabled() async {
        let previousValue = AppSettings.shared.aiScoringEnabled
        AppSettings.shared.aiScoringEnabled = false
        defer { AppSettings.shared.aiScoringEnabled = previousValue }

        let service = EveningReflectionTextService()
        let result = await service.generateTexts(
            intentions: [.fokus, .bhag],
            tasks: [],
            focusBlocks: []
        )

        XCTAssertTrue(result.isEmpty, "Should return empty dict when AI is disabled")
    }

    // MARK: - Prompt Building

    /// Verhalten: buildPrompt enthaelt das Intention-Label.
    /// Bricht wenn: buildPrompt() den intention.label oder intention.rawValue nicht einbaut.
    func test_buildPrompt_includesIntentionLabel() {
        let service = EveningReflectionTextService()
        let prompt = service.buildPrompt(
            intention: .bhag,
            level: .fulfilled,
            tasks: [],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("bhag"),
            "Prompt should contain the intention rawValue 'bhag'"
        )
    }

    /// Verhalten: buildPrompt enthaelt Titel erledigter Tasks.
    /// Bricht wenn: buildPrompt() die Task-Titel nicht in den Prompt einbaut.
    func test_buildPrompt_includesCompletedTaskTitles() {
        let service = EveningReflectionTextService()
        let task = makeTask(
            title: "Steuererklaerung",
            isCompleted: true,
            completedAt: today
        )

        let prompt = service.buildPrompt(
            intention: .bhag,
            level: .fulfilled,
            tasks: [task],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("Steuererklaerung"),
            "Prompt should contain completed task title"
        )
    }

    /// Verhalten: buildPrompt begrenzt Tasks auf max 5.
    /// Bricht wenn: Die .prefix(5) Begrenzung in buildPrompt() fehlt.
    func test_buildPrompt_limitsTasksToFive() {
        let service = EveningReflectionTextService()
        let tasks = (1...7).map { i in
            makeTask(
                title: "Task \(i)",
                isCompleted: true,
                completedAt: today
            )
        }

        let prompt = service.buildPrompt(
            intention: .balance,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        // Task 6 and 7 should NOT appear
        XCTAssertFalse(
            prompt.contains("Task 6"),
            "Prompt should not contain more than 5 tasks"
        )
        XCTAssertFalse(
            prompt.contains("Task 7"),
            "Prompt should not contain more than 5 tasks"
        )
        // Task 1-5 should appear
        XCTAssertTrue(
            prompt.contains("Task 1"),
            "Prompt should contain the first 5 tasks"
        )
    }

    /// Verhalten: buildPrompt enthaelt nur heute erledigte Tasks, nicht gestrige.
    /// Bricht wenn: completedToday() Filter in buildPrompt() nicht angewendet wird.
    func test_buildPrompt_excludesYesterdayTasks() {
        let service = EveningReflectionTextService()
        let todayTask = makeTask(
            title: "Heute erledigt",
            isCompleted: true,
            completedAt: today
        )
        let yesterdayTask = makeTask(
            title: "Gestern erledigt",
            isCompleted: true,
            completedAt: yesterday
        )

        let prompt = service.buildPrompt(
            intention: .fokus,
            level: .partial,
            tasks: [todayTask, yesterdayTask],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("Heute erledigt"),
            "Prompt should contain today's completed task"
        )
        XCTAssertFalse(
            prompt.contains("Gestern erledigt"),
            "Prompt should NOT contain yesterday's task"
        )
    }

    /// Verhalten: buildPrompt enthaelt FulfillmentLevel-Beschreibung.
    /// Bricht wenn: levelDescription() nicht in den Prompt eingebaut wird.
    func test_buildPrompt_includesFulfillmentLevel() {
        let service = EveningReflectionTextService()

        let fulfilledPrompt = service.buildPrompt(
            intention: .fokus, level: .fulfilled,
            tasks: [], focusBlocks: [], now: today
        )
        XCTAssertTrue(
            fulfilledPrompt.contains("Erfuellt"),
            "Prompt should contain 'Erfuellt' for fulfilled level"
        )

        let partialPrompt = service.buildPrompt(
            intention: .fokus, level: .partial,
            tasks: [], focusBlocks: [], now: today
        )
        XCTAssertTrue(
            partialPrompt.contains("Teilweise"),
            "Prompt should contain 'Teilweise' for partial level"
        )

        let notFulfilledPrompt = service.buildPrompt(
            intention: .fokus, level: .notFulfilled,
            tasks: [], focusBlocks: [], now: today
        )
        XCTAssertTrue(
            notFulfilledPrompt.contains("Nicht erfuellt"),
            "Prompt should contain 'Nicht erfuellt' for notFulfilled level"
        )
    }

    /// Verhalten: buildPrompt enthaelt Focus-Block-Statistik wenn Blocks vorhanden.
    /// Bricht wenn: Die Block-Statistik-Zeile in buildPrompt() fehlt.
    func test_buildPrompt_includesFocusBlockStats() {
        let service = EveningReflectionTextService()
        let blocks = [
            makeBlock(id: "b1", taskIDs: ["t1", "t2"], completedTaskIDs: ["t1"]),
            makeBlock(id: "b2", taskIDs: ["t3"], completedTaskIDs: ["t3"]),
            makeBlock(id: "b3", taskIDs: ["t4"], completedTaskIDs: [])
        ]

        let prompt = service.buildPrompt(
            intention: .fokus,
            level: .partial,
            tasks: [],
            focusBlocks: blocks,
            now: today
        )

        XCTAssertTrue(
            prompt.contains("Focus-Blocks:"),
            "Prompt should contain Focus-Block stats when blocks exist"
        )
        XCTAssertTrue(
            prompt.contains("von 3"),
            "Prompt should show total block count"
        )
    }

    /// Verhalten: buildPrompt ist valide (kein Crash) auch ohne erledigte Tasks.
    /// Bricht wenn: buildPrompt() bei leeren Tasks crasht statt "keine" auszugeben.
    func test_buildPrompt_emptyTasksCase() {
        let service = EveningReflectionTextService()
        let prompt = service.buildPrompt(
            intention: .survival,
            level: .notFulfilled,
            tasks: [],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("keine"),
            "Prompt should handle empty tasks gracefully"
        )
        XCTAssertFalse(prompt.isEmpty, "Prompt should not be empty")
    }

    /// Verhalten: buildPrompt enthaelt Wichtigkeit-Marker fuer importance=3 Tasks.
    /// Bricht wenn: Die [Wichtigkeit: hoch] Annotation in buildPrompt() fehlt.
    func test_buildPrompt_includesHighImportanceMarker() {
        let service = EveningReflectionTextService()
        let task = makeTask(
            title: "Grosses Ding",
            importance: 3,
            isCompleted: true,
            completedAt: today
        )

        let prompt = service.buildPrompt(
            intention: .bhag,
            level: .fulfilled,
            tasks: [task],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("Wichtigkeit: hoch"),
            "Prompt should mark importance=3 tasks as high importance"
        )
    }
}
