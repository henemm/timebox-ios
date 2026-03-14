import XCTest
@testable import FocusBlox

/// Unit Tests for EveningReflectionTextService (Coach-based evening reflection).
///
/// Tests the prompt construction, guard conditions, and fallback integration.
/// AI output quality is NOT tested (non-deterministic) — only structure and guards.
@MainActor
final class EveningReflectionTextServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTask(
        title: String = "Test",
        importance: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        taskType: String = "",
        isNextUp: Bool = false,
        rescheduleCount: Int = 0,
        assignedFocusBlockID: String? = nil
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: importance)
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.taskType = taskType
        task.isNextUp = isNextUp
        task.rescheduleCount = rescheduleCount
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
    func test_isAvailable_returnsBool() {
        let available = EveningReflectionTextService.isAvailable
        XCTAssertEqual(
            available, EveningReflectionTextService.isAvailable,
            "isAvailable should return consistent results"
        )
    }

    // MARK: - Guard: AI Disabled

    /// Verhalten: generateText gibt nil zurueck wenn aiScoringEnabled == false.
    func test_generateText_returnsNilWhenAiDisabled() async {
        let previousValue = AppSettings.shared.aiScoringEnabled
        AppSettings.shared.aiScoringEnabled = false
        defer { AppSettings.shared.aiScoringEnabled = previousValue }

        let service = EveningReflectionTextService()
        let result = await service.generateText(
            coach: .eule,
            level: .fulfilled,
            tasks: [],
            focusBlocks: []
        )

        XCTAssertNil(result, "Should return nil when AI is disabled")
    }

    // MARK: - Prompt Building

    /// Verhalten: buildPrompt enthaelt den Coach-Namen.
    func test_buildPrompt_includesCoachName() {
        let service = EveningReflectionTextService()
        let prompt = service.buildPrompt(
            coach: .feuer,
            level: .fulfilled,
            tasks: [],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("Feuer"),
            "Prompt should contain the coach displayName 'Feuer'"
        )
    }

    /// Verhalten: buildPrompt enthaelt Titel erledigter Tasks.
    func test_buildPrompt_includesCompletedTaskTitles() {
        let service = EveningReflectionTextService()
        let task = makeTask(
            title: "Steuererklaerung",
            isCompleted: true,
            completedAt: today
        )

        let prompt = service.buildPrompt(
            coach: .feuer,
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
            coach: .golem,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        XCTAssertFalse(
            prompt.contains("Task 6"),
            "Prompt should not contain more than 5 tasks"
        )
        XCTAssertFalse(
            prompt.contains("Task 7"),
            "Prompt should not contain more than 5 tasks"
        )
        XCTAssertTrue(
            prompt.contains("Task 1"),
            "Prompt should contain the first 5 tasks"
        )
    }

    /// Verhalten: buildPrompt enthaelt nur heute erledigte Tasks, nicht gestrige.
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
            coach: .eule,
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
    func test_buildPrompt_includesFulfillmentLevel() {
        let service = EveningReflectionTextService()

        let fulfilledPrompt = service.buildPrompt(
            coach: .eule, level: .fulfilled,
            tasks: [], focusBlocks: [], now: today
        )
        XCTAssertTrue(
            fulfilledPrompt.contains("Erfuellt"),
            "Prompt should contain 'Erfuellt' for fulfilled level"
        )

        let partialPrompt = service.buildPrompt(
            coach: .eule, level: .partial,
            tasks: [], focusBlocks: [], now: today
        )
        XCTAssertTrue(
            partialPrompt.contains("Teilweise"),
            "Prompt should contain 'Teilweise' for partial level"
        )

        let notFulfilledPrompt = service.buildPrompt(
            coach: .eule, level: .notFulfilled,
            tasks: [], focusBlocks: [], now: today
        )
        XCTAssertTrue(
            notFulfilledPrompt.contains("Nicht erfuellt"),
            "Prompt should contain 'Nicht erfuellt' for notFulfilled level"
        )
    }

    /// Verhalten: buildPrompt enthaelt Focus-Block-Statistik wenn Blocks vorhanden.
    func test_buildPrompt_includesFocusBlockStats() {
        let service = EveningReflectionTextService()
        let blocks = [
            makeBlock(id: "b1", taskIDs: ["t1", "t2"], completedTaskIDs: ["t1"]),
            makeBlock(id: "b2", taskIDs: ["t3"], completedTaskIDs: ["t3"]),
            makeBlock(id: "b3", taskIDs: ["t4"], completedTaskIDs: [])
        ]

        let prompt = service.buildPrompt(
            coach: .eule,
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
    func test_buildPrompt_emptyTasksCase() {
        let service = EveningReflectionTextService()
        let prompt = service.buildPrompt(
            coach: .troll,
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
    func test_buildPrompt_includesHighImportanceMarker() {
        let service = EveningReflectionTextService()
        let task = makeTask(
            title: "Grosses Ding",
            importance: 3,
            isCompleted: true,
            completedAt: today
        )

        let prompt = service.buildPrompt(
            coach: .feuer,
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

    // MARK: - Coach-Relevanz Sortierung

    /// Verhalten: Bei Feuer-Coach steht der importance=3 Task VOR normalen Tasks.
    func test_buildPrompt_feuer_sortsHighImportanceFirst() {
        let service = EveningReflectionTextService()

        var tasks: [LocalTask] = (1...6).map { i in
            makeTask(title: "Admin \(i)", isCompleted: true, completedAt: today)
        }
        let bigTask = makeTask(
            title: "Das Grosse Ding",
            importance: 3,
            isCompleted: true,
            completedAt: today
        )
        tasks.append(bigTask)

        let prompt = service.buildPrompt(
            coach: .feuer,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        let bigPos = prompt.range(of: "Das Grosse Ding")
        let adminPos = prompt.range(of: "Admin 1")
        XCTAssertNotNil(bigPos, "Big task must appear in prompt")
        XCTAssertNotNil(adminPos, "Admin task must appear in prompt")
        XCTAssertTrue(
            bigPos!.lowerBound < adminPos!.lowerBound,
            "Feuer: importance-3 task must appear BEFORE normal tasks"
        )
    }

    /// Verhalten: Bei Eule-Coach steht der Block-Task VOR Tasks ohne Block.
    func test_buildPrompt_eule_sortsBlockTasksFirst() {
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
            coach: .eule,
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

    /// Verhalten: Bei Troll-Coach steht der aufgeschobene Task VOR normalen.
    func test_buildPrompt_troll_sortsProcrastinatedFirst() {
        let service = EveningReflectionTextService()

        var tasks: [LocalTask] = (1...6).map { i in
            makeTask(title: "Routine \(i)", isCompleted: true, completedAt: today)
        }
        let procrastinated = makeTask(
            title: "Endlich erledigt",
            isCompleted: true,
            completedAt: today,
            rescheduleCount: 5
        )
        tasks.append(procrastinated)

        let prompt = service.buildPrompt(
            coach: .troll,
            level: .fulfilled,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        let procPos = prompt.range(of: "Endlich erledigt")
        let routinePos = prompt.range(of: "Routine 1")
        XCTAssertNotNil(procPos, "Procrastinated task must appear in prompt")
        XCTAssertNotNil(routinePos, "Routine task must appear in prompt")
        XCTAssertTrue(
            procPos!.lowerBound < routinePos!.lowerBound,
            "Troll: procrastinated task must appear BEFORE normal tasks"
        )
    }

    // MARK: - Coach Guidance per Coach

    /// Verhalten: Jeder Coach hat eine spezifische Schwerpunkt-Guidance im Prompt.
    func test_buildPrompt_guidancePerCoach() {
        let service = EveningReflectionTextService()
        let expectations: [(CoachType, String)] = [
            (.troll, "aufgeschobene"),
            (.feuer, "Herausforderung"),
            (.eule, "fokussiert"),
            (.golem, "Balance"),
        ]

        for (coach, keyword) in expectations {
            let prompt = service.buildPrompt(
                coach: coach,
                level: .fulfilled,
                tasks: [],
                focusBlocks: [],
                now: today
            )
            XCTAssertTrue(
                prompt.contains("Schwerpunkt:"),
                "\(coach) prompt must contain 'Schwerpunkt:'"
            )
            XCTAssertTrue(
                prompt.lowercased().contains(keyword.lowercased()),
                "\(coach) guidance must contain '\(keyword)'"
            )
        }
    }

    // MARK: - Golem/Balance Guidance mit Kategorie-Aufschluesselung

    /// Verhalten: Golem-Guidance listet aktive und fehlende Kategorien auf.
    func test_buildPrompt_golem_showsCategoryBreakdown() {
        let service = EveningReflectionTextService()

        let tasks: [LocalTask] = [
            makeTask(title: "Gehalt", isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(title: "Rechnung", isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(title: "Yoga", isCompleted: true, completedAt: today, taskType: "recharge"),
        ]

        let prompt = service.buildPrompt(
            coach: .golem,
            level: .partial,
            tasks: tasks,
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(prompt.contains("Geld (2)"), "Must show 'Geld (2)' for 2 income tasks")
        XCTAssertTrue(prompt.contains("Energie (1)"), "Must show 'Energie (1)' for 1 recharge task")
        XCTAssertTrue(prompt.contains("Pflege"), "Must list missing category 'Pflege'")
        XCTAssertTrue(prompt.contains("Lernen"), "Must list missing category 'Lernen'")
        XCTAssertTrue(prompt.contains("Geben"), "Must list missing category 'Geben'")
        XCTAssertTrue(prompt.contains("Fehlend:"), "Must contain 'Fehlend:' label")
    }

    /// Verhalten: Golem-Guidance bei leeren Tasks zeigt "in keinem Bereich aktiv".
    func test_buildPrompt_golem_emptyTasksShowsNoneActive() {
        let service = EveningReflectionTextService()

        let prompt = service.buildPrompt(
            coach: .golem,
            level: .notFulfilled,
            tasks: [],
            focusBlocks: [],
            now: today
        )

        XCTAssertTrue(
            prompt.contains("keinem Bereich aktiv"),
            "Empty tasks must show 'in keinem Bereich aktiv'"
        )
        XCTAssertFalse(
            prompt.contains("Fehlend:"),
            "Must NOT show 'Fehlend:' when already saying 'keinem Bereich aktiv'"
        )
    }

    /// Verhalten: Golem-Guidance bei allen 5 Kategorien aktiv zeigt keine fehlenden.
    func test_buildPrompt_golem_allCategoriesActive() {
        let service = EveningReflectionTextService()

        let tasks: [LocalTask] = [
            makeTask(title: "T1", isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(title: "T2", isCompleted: true, completedAt: today, taskType: "maintenance"),
            makeTask(title: "T3", isCompleted: true, completedAt: today, taskType: "recharge"),
            makeTask(title: "T4", isCompleted: true, completedAt: today, taskType: "learning"),
            makeTask(title: "T5", isCompleted: true, completedAt: today, taskType: "giving_back"),
        ]

        let prompt = service.buildPrompt(
            coach: .golem,
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
