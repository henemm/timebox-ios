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
        taskType: String = "",
        assignedFocusBlockID: String? = nil
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: importance)
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.taskType = taskType
        task.assignedFocusBlockID = assignedFocusBlockID
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

    // MARK: - Intention-Relevanz Sortierung (Bug: Review nicht spezifisch)

    /// Verhalten: Bei BHAG-Intention steht der importance=3 Task VOR normalen Tasks.
    /// Bricht wenn: buildPrompt() Tasks nicht nach Intention-Relevanz sortiert.
    func test_buildPrompt_bhag_sortsHighImportanceFirst() {
        let service = EveningReflectionTextService()

        // 6 normale Tasks, dann 1 BHAG-Task am Ende — ohne Sortierung würde .prefix(5) ihn abschneiden
        var tasks: [LocalTask] = (1...6).map { i in
            makeTask(title: "Admin \(i)", isCompleted: true, completedAt: today)
        }
        let bhagTask = makeTask(
            title: "Das Grosse Ding",
            importance: 3,
            isCompleted: true,
            completedAt: today
        )
        tasks.append(bhagTask)

        let prompt = service.buildPrompt(
            intention: .bhag,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        // Task muss im Prompt sein UND vor den normalen Tasks stehen
        let bhagPos = prompt.range(of: "Das Grosse Ding")
        let adminPos = prompt.range(of: "Admin 1")
        XCTAssertNotNil(bhagPos, "BHAG task must appear in prompt")
        XCTAssertNotNil(adminPos, "Admin task must appear in prompt")
        XCTAssertTrue(
            bhagPos!.lowerBound < adminPos!.lowerBound,
            "BHAG task (importance=3) must appear BEFORE normal tasks"
        )
    }

    /// Verhalten: Bei Fokus-Intention steht der Block-Task VOR Tasks ohne Block.
    /// Bricht wenn: buildPrompt() Tasks nicht nach assignedFocusBlockID sortiert.
    func test_buildPrompt_fokus_sortsBlockTasksFirst() {
        let service = EveningReflectionTextService()

        var tasks: [LocalTask] = (1...6).map { i in
            makeTask(title: "Ohne Block \(i)", isCompleted: true, completedAt: today)
        }
        let blockTask = makeTask(
            title: "Im Block erledigt",
            isCompleted: true,
            completedAt: today,
            assignedFocusBlockID: "block-1"
        )
        tasks.append(blockTask)

        let prompt = service.buildPrompt(
            intention: .fokus,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        let blockPos = prompt.range(of: "Im Block erledigt")
        let ohnePos = prompt.range(of: "Ohne Block 1")
        XCTAssertNotNil(blockPos, "Block task must appear in prompt")
        XCTAssertNotNil(ohnePos, "Non-block task must appear in prompt")
        XCTAssertTrue(
            blockPos!.lowerBound < ohnePos!.lowerBound,
            "Block-assigned task must appear BEFORE non-block tasks"
        )
    }

    /// Verhalten: Bei Growth-Intention steht der Learning-Task VOR anderen.
    /// Bricht wenn: buildPrompt() nicht nach taskType=="learning" sortiert.
    func test_buildPrompt_growth_sortsLearningTasksFirst() {
        let service = EveningReflectionTextService()

        var tasks: [LocalTask] = (1...6).map { i in
            makeTask(title: "Routine \(i)", isCompleted: true, completedAt: today, taskType: "income")
        }
        let learningTask = makeTask(
            title: "Swift Kurs",
            isCompleted: true,
            completedAt: today,
            taskType: "learning"
        )
        tasks.append(learningTask)

        let prompt = service.buildPrompt(
            intention: .growth,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        let learnPos = prompt.range(of: "Swift Kurs")
        let routinePos = prompt.range(of: "Routine 1")
        XCTAssertNotNil(learnPos, "Learning task must appear in prompt")
        XCTAssertNotNil(routinePos, "Routine task must appear in prompt")
        XCTAssertTrue(
            learnPos!.lowerBound < routinePos!.lowerBound,
            "Learning task must appear BEFORE income tasks"
        )
    }

    /// Verhalten: Bei Connection-Intention steht der Giving-Back-Task VOR anderen.
    /// Bricht wenn: buildPrompt() nicht nach taskType=="giving_back" sortiert.
    func test_buildPrompt_connection_sortsGivingBackTasksFirst() {
        let service = EveningReflectionTextService()

        var tasks: [LocalTask] = (1...6).map { i in
            makeTask(title: "Arbeit \(i)", isCompleted: true, completedAt: today, taskType: "income")
        }
        let connectionTask = makeTask(
            title: "Oma anrufen",
            isCompleted: true,
            completedAt: today,
            taskType: "giving_back"
        )
        tasks.append(connectionTask)

        let prompt = service.buildPrompt(
            intention: .connection,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        let socialPos = prompt.range(of: "Oma anrufen")
        let workPos = prompt.range(of: "Arbeit 1")
        XCTAssertNotNil(socialPos, "Giving-back task must appear in prompt")
        XCTAssertNotNil(workPos, "Work task must appear in prompt")
        XCTAssertTrue(
            socialPos!.lowerBound < workPos!.lowerBound,
            "Giving-back task must appear BEFORE income tasks"
        )
    }

    // MARK: - Intention Guidance pro Intention

    /// Verhalten: Jede Intention hat eine spezifische Schwerpunkt-Guidance im Prompt.
    /// Bricht wenn: intentionGuidance() für eine Intention fehlt oder generisch ist.
    func test_buildPrompt_guidancePerIntention() {
        let service = EveningReflectionTextService()
        let expectations: [(IntentionOption, String)] = [
            (.survival, "überstanden"),
            (.fokus, "Focus-Blocks"),
            (.bhag, "große"),
            (.growth, "Lernen"),
            (.connection, "Verbundenheit"),
        ]

        for (intention, keyword) in expectations {
            let prompt = service.buildPrompt(
                intention: intention,
                level: .fulfilled,
                tasks: [],
                focusBlocks: [],
                now: today
            )
            XCTAssertTrue(
                prompt.contains("Schwerpunkt:"),
                "\(intention) prompt must contain 'Schwerpunkt:'"
            )
            XCTAssertTrue(
                prompt.contains(keyword),
                "\(intention) guidance must contain '\(keyword)'"
            )
        }
    }

    // MARK: - Balance Guidance mit Kategorie-Aufschlüsselung

    /// Verhalten: Balance-Guidance listet aktive und fehlende Kategorien auf.
    /// Bricht wenn: balanceGuidance() nicht nach TaskCategory aufschlüsselt.
    func test_buildPrompt_balance_showsCategoryBreakdown() {
        let service = EveningReflectionTextService()

        let tasks: [LocalTask] = [
            makeTask(title: "Gehalt", isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(title: "Rechnung", isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(title: "Yoga", isCompleted: true, completedAt: today, taskType: "recharge"),
        ]

        let prompt = service.buildPrompt(
            intention: .balance,
            level: .partial,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        // Aktive Kategorien mit Anzahl
        XCTAssertTrue(prompt.contains("Geld (2)"), "Must show 'Geld (2)' for 2 income tasks")
        XCTAssertTrue(prompt.contains("Energie (1)"), "Must show 'Energie (1)' for 1 recharge task")

        // Fehlende Kategorien
        XCTAssertTrue(prompt.contains("Pflege"), "Must list missing category 'Pflege'")
        XCTAssertTrue(prompt.contains("Lernen"), "Must list missing category 'Lernen'")
        XCTAssertTrue(prompt.contains("Geben"), "Must list missing category 'Geben'")
        XCTAssertTrue(prompt.contains("Fehlend:"), "Must contain 'Fehlend:' label")
    }

    /// Verhalten: Balance-Guidance bei leeren Tasks zeigt "in keinem Bereich aktiv".
    /// Bricht wenn: balanceGuidance() bei leeren Tasks redundanten Output erzeugt.
    func test_buildPrompt_balance_emptyTasksShowsNoneActive() {
        let service = EveningReflectionTextService()

        let prompt = service.buildPrompt(
            intention: .balance,
            level: .notFulfilled,
            tasks: [],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("keinem Bereich aktiv"),
            "Empty tasks must show 'in keinem Bereich aktiv'"
        )
        // Darf NICHT gleichzeitig "Fehlend:" zeigen (wäre redundant)
        XCTAssertFalse(
            prompt.contains("Fehlend:"),
            "Must NOT show 'Fehlend:' when already saying 'keinem Bereich aktiv'"
        )
    }

    /// Verhalten: Balance-Guidance bei allen 5 Kategorien aktiv zeigt keine fehlenden.
    /// Bricht wenn: balanceGuidance() fälschlich fehlende Kategorien anzeigt.
    func test_buildPrompt_balance_allCategoriesActive() {
        let service = EveningReflectionTextService()

        let tasks: [LocalTask] = [
            makeTask(title: "T1", isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(title: "T2", isCompleted: true, completedAt: today, taskType: "maintenance"),
            makeTask(title: "T3", isCompleted: true, completedAt: today, taskType: "recharge"),
            makeTask(title: "T4", isCompleted: true, completedAt: today, taskType: "learning"),
            makeTask(title: "T5", isCompleted: true, completedAt: today, taskType: "giving_back"),
        ]

        let prompt = service.buildPrompt(
            intention: .balance,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(prompt.contains("Heute aktiv:"), "Must show active categories")
        XCTAssertFalse(prompt.contains("Fehlend:"), "Must NOT show 'Fehlend:' when all categories active")
        XCTAssertFalse(prompt.contains("keinem Bereich"), "Must NOT say 'keinem Bereich' when all active")
    }
}
