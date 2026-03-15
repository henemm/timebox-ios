import XCTest
@testable import FocusBlox

final class IntentionEvaluationServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTask(
        title: String = "Test",
        importance: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        taskType: String = "",
        isNextUp: Bool = false,
        assignedFocusBlockID: String? = nil,
        rescheduleCount: Int = 0
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

    // MARK: - isFulfilled: Troll

    /// Verhalten: Troll ist erfuellt wenn ein aufgeschobener Task (rescheduleCount >= 2) HEUTE erledigt wurde.
    func test_isFulfilled_troll_whenProcrastinatedTaskCompleted_returnsTrue() {
        let task = makeTask(isCompleted: true, completedAt: today, rescheduleCount: 3)
        let result = IntentionEvaluationService.isFulfilled(
            coach: .troll, tasks: [task], focusBlocks: []
        )
        XCTAssertTrue(result, "Troll should be fulfilled when procrastinated task completed")
    }

    /// Verhalten: Ohne aufgeschobenen erledigten Task ist Troll NICHT erfuellt.
    func test_isFulfilled_troll_whenNoProcrastinatedTaskDone_returnsFalse() {
        let task = makeTask(isCompleted: true, completedAt: today, rescheduleCount: 0)
        let result = IntentionEvaluationService.isFulfilled(
            coach: .troll, tasks: [task], focusBlocks: []
        )
        XCTAssertFalse(result, "Troll needs a procrastinated task completed")
    }

    // MARK: - isFulfilled: Feuer

    /// Verhalten: Feuer ist erfuellt wenn ein Task mit importance=3 HEUTE erledigt wurde.
    func test_isFulfilled_feuer_whenImportance3TaskCompleted_returnsTrue() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.isFulfilled(
            coach: .feuer, tasks: [task], focusBlocks: []
        )
        XCTAssertTrue(result, "Feuer should be fulfilled when importance-3 task completed today")
    }

    /// Verhalten: Gestern erledigte Tasks zaehlen NICHT fuer heute.
    func test_isFulfilled_feuer_whenImportance3TaskCompletedYesterday_returnsFalse() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: yesterday)
        let result = IntentionEvaluationService.isFulfilled(
            coach: .feuer, tasks: [task], focusBlocks: []
        )
        XCTAssertFalse(result, "Yesterday's completion should not count for today")
    }

    /// Verhalten: Tasks mit importance < 3 erfuellen Feuer NICHT.
    func test_isFulfilled_feuer_whenNoImportance3Task_returnsFalse() {
        let task = makeTask(importance: 2, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.isFulfilled(
            coach: .feuer, tasks: [task], focusBlocks: []
        )
        XCTAssertFalse(result, "Only importance=3 counts for Feuer")
    }

    // MARK: - isFulfilled: Eule

    /// Verhalten: Eule ist erfuellt wenn Focus Blocks existieren und nur geplante Tasks erledigt.
    func test_isFulfilled_eule_whenOnlyPlannedTasksInBlocks_returnsTrue() {
        let block = makeBlock(taskIDs: ["task-1"])
        let task = makeTask(isCompleted: true, completedAt: today, isNextUp: true)
        let result = IntentionEvaluationService.isFulfilled(
            coach: .eule, tasks: [task], focusBlocks: [block]
        )
        XCTAssertTrue(result, "Eule should be fulfilled when only planned tasks completed in blocks")
    }

    /// Verhalten: Ohne Focus Blocks ist Eule NICHT erfuellt.
    func test_isFulfilled_eule_whenNoFocusBlock_returnsFalse() {
        let task = makeTask(isCompleted: true, completedAt: today, isNextUp: true)
        let result = IntentionEvaluationService.isFulfilled(
            coach: .eule, tasks: [task], focusBlocks: []
        )
        XCTAssertFalse(result, "Eule should not be fulfilled without focus blocks")
    }

    // MARK: - isFulfilled: Golem

    /// Verhalten: Golem ist erfuellt bei Tasks in >= 3 verschiedenen Kategorien HEUTE.
    func test_isFulfilled_golem_whenThreeCategoriesCompleted_returnsTrue() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
            makeTask(isCompleted: true, completedAt: today, taskType: "giving_back"),
        ]
        let result = IntentionEvaluationService.isFulfilled(
            coach: .golem, tasks: tasks, focusBlocks: []
        )
        XCTAssertTrue(result, "Golem needs tasks in >= 3 distinct categories")
    }

    /// Verhalten: Nur 2 Kategorien reichen NICHT fuer Golem.
    func test_isFulfilled_golem_whenOnlyTwoCategories_returnsFalse() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
        ]
        let result = IntentionEvaluationService.isFulfilled(
            coach: .golem, tasks: tasks, focusBlocks: []
        )
        XCTAssertFalse(result, "Two tasks in same category should not fulfill Golem")
    }

    // MARK: - detectGap: Troll

    /// Verhalten: Aufgeschobene Tasks noch offen → Gap .procrastinatedTasksPending.
    func test_detectGap_troll_whenProcrastinatedTasksPending_returnsGap() {
        let task = makeTask(isCompleted: false, rescheduleCount: 3)
        let result = IntentionEvaluationService.detectGap(
            coach: .troll, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .procrastinatedTasksPending)
    }

    /// Verhalten: Aufgeschobener Task erledigt → kein Gap.
    func test_detectGap_troll_whenProcrastinatedTaskDone_returnsNil() {
        let task = makeTask(isCompleted: true, completedAt: today, rescheduleCount: 3)
        let result = IntentionEvaluationService.detectGap(
            coach: .troll, tasks: [task], focusBlocks: []
        )
        XCTAssertNil(result, "Fulfilled troll should have no gap")
    }

    // MARK: - detectGap: Feuer

    /// Verhalten: Keine Tasks erledigt → Gap .noBigTaskStarted.
    func test_detectGap_feuer_whenNoTasksCompleted_returnsNoBigTaskStarted() {
        let result = IntentionEvaluationService.detectGap(
            coach: .feuer, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .noBigTaskStarted)
    }

    /// Verhalten: Feuer-Task erledigt → kein Gap.
    func test_detectGap_feuer_whenBigTaskDone_returnsNil() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.detectGap(
            coach: .feuer, tasks: [task], focusBlocks: []
        )
        XCTAssertNil(result, "Fulfilled Feuer should have no gap")
    }

    // MARK: - detectGap: Eule

    /// Verhalten: Ohne Focus Blocks → Gap .noPlannedTasks.
    func test_detectGap_eule_whenNoFocusBlock_returnsNoPlannedTasks() {
        let result = IntentionEvaluationService.detectGap(
            coach: .eule, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .noPlannedTasks)
    }

    /// Verhalten: Tasks ausserhalb von Blocks erledigt → Gap .tasksOutsideBlocks.
    func test_detectGap_eule_whenTasksCompletedOutsideBlocks_returnsTasksOutsideBlocks() {
        let block = makeBlock(taskIDs: ["in-block"])
        let taskOutside = makeTask(isCompleted: true, completedAt: today, assignedFocusBlockID: nil)
        let result = IntentionEvaluationService.detectGap(
            coach: .eule, tasks: [taskOutside], focusBlocks: [block]
        )
        XCTAssertEqual(result, .tasksOutsideBlocks)
    }

    // MARK: - detectGap: Golem

    /// Verhalten: Golem nicht erfuellt → Gap .onlySingleCategory.
    func test_detectGap_golem_whenNotFulfilled_returnsOnlySingleCategory() {
        let task = makeTask(isCompleted: true, completedAt: today, taskType: "income")
        let result = IntentionEvaluationService.detectGap(
            coach: .golem, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .onlySingleCategory)
    }

    // MARK: - completedToday helper

    /// Verhalten: Filtert Tasks auf heute erledigte (completedAt >= startOfDay).
    func test_completedToday_filtersByCompletedAtDate() {
        let todayTask = makeTask(isCompleted: true, completedAt: today)
        let yesterdayTask = makeTask(isCompleted: true, completedAt: yesterday)
        let incompleteTask = makeTask(isCompleted: false)

        let result = IntentionEvaluationService.completedToday(
            [todayTask, yesterdayTask, incompleteTask]
        )
        XCTAssertEqual(result.count, 1, "Only today's completed task should be returned")
    }

    // MARK: - evaluateFulfillment: Troll

    /// Verhalten: Troll + aufgeschobener Task erledigt → .fulfilled
    func test_evaluateFulfillment_troll_fulfilled() {
        let task = makeTask(isCompleted: true, completedAt: today, rescheduleCount: 3)
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .troll, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Troll with procrastinated task completed should be fulfilled")
    }

    /// Verhalten: Troll + Tasks erledigt aber keine aufgeschobenen → .partial
    func test_evaluateFulfillment_troll_partial() {
        let task = makeTask(isCompleted: true, completedAt: today, rescheduleCount: 0)
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .troll, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "Troll with tasks but no procrastinated should be partial")
    }

    /// Verhalten: Troll + keine Tasks erledigt → .notFulfilled
    func test_evaluateFulfillment_troll_notFulfilled() {
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .troll, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Troll with no tasks should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: Eule

    /// Verhalten: Eule + Block-Completion >= 70% → .fulfilled
    func test_evaluateFulfillment_eule_fulfilled() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1", "t2", "t3"]
        )
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .eule, tasks: [], focusBlocks: [block]
        )
        XCTAssertEqual(result, .fulfilled, "Eule with 75% block completion should be fulfilled")
    }

    /// Verhalten: Eule + Block-Completion 40-69% → .partial
    func test_evaluateFulfillment_eule_partial() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1", "t2"]
        )
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .eule, tasks: [], focusBlocks: [block]
        )
        XCTAssertEqual(result, .partial, "Eule with 50% block completion should be partial")
    }

    /// Verhalten: Eule + Block-Completion < 40% → .notFulfilled
    func test_evaluateFulfillment_eule_notFulfilled_lowCompletion() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1"]
        )
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .eule, tasks: [], focusBlocks: [block]
        )
        XCTAssertEqual(result, .notFulfilled, "Eule with 25% block completion should be notFulfilled")
    }

    /// Verhalten: Eule + keine Blocks → .notFulfilled
    func test_evaluateFulfillment_eule_notFulfilled_noBlocks() {
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .eule, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Eule with no blocks should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: Feuer

    /// Verhalten: Feuer + importance-3 Task erledigt → .fulfilled
    func test_evaluateFulfillment_feuer_fulfilled() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .feuer, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Feuer with importance-3 task completed should be fulfilled")
    }

    /// Verhalten: Feuer + Tasks erledigt aber keiner mit importance=3 → .partial
    func test_evaluateFulfillment_feuer_partial() {
        let task = makeTask(importance: 2, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .feuer, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "Feuer with tasks but no importance-3 should be partial")
    }

    /// Verhalten: Feuer + keine Tasks erledigt → .notFulfilled
    func test_evaluateFulfillment_feuer_notFulfilled() {
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .feuer, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Feuer with no tasks should be notFulfilled")
    }

    // MARK: - evaluateFulfillment: Golem

    /// Verhalten: Golem + Tasks in >= 3 Kategorien → .fulfilled
    func test_evaluateFulfillment_golem_fulfilled() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
            makeTask(isCompleted: true, completedAt: today, taskType: "giving_back"),
        ]
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .golem, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Golem with 3 categories should be fulfilled")
    }

    /// Verhalten: Golem + Tasks in genau 2 Kategorien → .partial
    func test_evaluateFulfillment_golem_partial() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
        ]
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .golem, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "Golem with exactly 2 categories should be partial")
    }

    /// Verhalten: Golem + Tasks in <= 1 Kategorie → .notFulfilled
    func test_evaluateFulfillment_golem_notFulfilled() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
        ]
        let result = IntentionEvaluationService.evaluateFulfillment(
            coach: .golem, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled, "Golem with 1 category should be notFulfilled")
    }

    // MARK: - blockCompletionPercentage

    /// Verhalten: Alle Tasks in Blocks erledigt → 1.0 (100%)
    func test_blockCompletionPercentage_allCompleted() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3"],
            completedTaskIDs: ["t1", "t2", "t3"]
        )
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: [block]
        )
        XCTAssertEqual(result, 1.0, accuracy: 0.01, "All tasks completed should be 100%")
    }

    /// Verhalten: Teilweise erledigt → korrekte Ratio
    func test_blockCompletionPercentage_partial() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1", "t2"]
        )
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: [block]
        )
        XCTAssertEqual(result, 0.5, accuracy: 0.01, "2 of 4 should be 50%")
    }

    /// Verhalten: Keine Blocks → 0.0
    func test_blockCompletionPercentage_noBlocks() {
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: []
        )
        XCTAssertEqual(result, 0.0, accuracy: 0.01, "No blocks should be 0%")
    }

    /// Verhalten: Blocks ohne Tasks → 0.0
    func test_blockCompletionPercentage_emptyBlocks() {
        let block = makeBlock(taskIDs: [], completedTaskIDs: [])
        let result = IntentionEvaluationService.blockCompletionPercentage(
            focusBlocks: [block]
        )
        XCTAssertEqual(result, 0.0, accuracy: 0.01, "Blocks with no tasks should be 0%")
    }

    // MARK: - Fallback Templates

    /// Verhalten: Jeder Coach + fulfilled hat einen nicht-leeren Template-Text.
    func test_fallbackTemplate_allCoaches_fulfilled() {
        for coach in CoachType.allCases {
            let text = IntentionEvaluationService.fallbackTemplate(
                coach: coach, level: .fulfilled
            )
            XCTAssertFalse(text.isEmpty, "\(coach) fulfilled should have a template")
        }
    }

    /// Verhalten: Jeder Coach + notFulfilled hat einen nicht-leeren Template-Text.
    func test_fallbackTemplate_allCoaches_notFulfilled() {
        for coach in CoachType.allCases {
            let text = IntentionEvaluationService.fallbackTemplate(
                coach: coach, level: .notFulfilled
            )
            XCTAssertFalse(text.isEmpty, "\(coach) notFulfilled should have a template")
        }
    }

    /// Verhalten: Jeder Coach hat einen nicht-leeren partial Template-Text.
    func test_fallbackTemplate_allCoaches_partial() {
        for coach in CoachType.allCases {
            let text = IntentionEvaluationService.fallbackTemplate(
                coach: coach, level: .partial
            )
            XCTAssertFalse(text.isEmpty, "\(coach) partial should have a template")
        }
    }

    // MARK: - completedThisWeek

    /// Verhalten: Filtert Tasks auf diese Woche erledigte (Mo-So).
    func test_completedThisWeek_filtersByWeekBoundary() {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start

        let thisWeekTask = makeTask(isCompleted: true, completedAt: weekStart.addingTimeInterval(3600))
        let lastWeekTask = makeTask(isCompleted: true, completedAt: weekStart.addingTimeInterval(-3600))
        let incompleteTask = makeTask(isCompleted: false)

        let result = IntentionEvaluationService.completedThisWeek(
            [thisWeekTask, lastWeekTask, incompleteTask], now: now
        )
        XCTAssertEqual(result.count, 1, "Only this week's completed task should be returned")
    }

    /// Verhalten: completedThisWeek gibt leeres Array fuer leere Eingabe.
    func test_completedThisWeek_emptyInput_returnsEmpty() {
        let result = IntentionEvaluationService.completedThisWeek([], now: Date())
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - focusBlocksThisWeek

    /// Verhalten: Filtert Focus-Blocks auf diese Woche.
    func test_focusBlocksThisWeek_filtersByWeekBoundary() {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start

        let thisWeekBlock = makeBlock(
            id: "this-week",
            startDate: weekStart.addingTimeInterval(3600),
            endDate: weekStart.addingTimeInterval(7200)
        )
        let lastWeekBlock = makeBlock(
            id: "last-week",
            startDate: weekStart.addingTimeInterval(-86400),
            endDate: weekStart.addingTimeInterval(-82800)
        )

        let result = IntentionEvaluationService.focusBlocksThisWeek(
            [thisWeekBlock, lastWeekBlock], now: now
        )
        XCTAssertEqual(result.count, 1, "Only this week's block should be returned")
        XCTAssertEqual(result.first?.id, "this-week")
    }

    // MARK: - evaluateWeeklyFulfillment: Troll

    /// Verhalten: Troll + 3 aufgeschobene Tasks diese Woche → .fulfilled
    func test_evaluateWeeklyFulfillment_troll_fulfilled() {
        let tasks = (1...3).map { _ in
            makeTask(isCompleted: true, completedAt: today, rescheduleCount: 3)
        }
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .troll, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Troll with 3+ procrastinated tasks this week should be fulfilled")
    }

    /// Verhalten: Troll + 1-2 aufgeschobene Tasks → .partial
    func test_evaluateWeeklyFulfillment_troll_partial() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, rescheduleCount: 3),
            makeTask(isCompleted: true, completedAt: today, rescheduleCount: 0),
        ]
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .troll, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "Troll with 1-2 procrastinated tasks should be partial")
    }

    /// Verhalten: Troll + keine aufgeschobenen Tasks → .notFulfilled
    func test_evaluateWeeklyFulfillment_troll_notFulfilled() {
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .troll, tasks: [], focusBlocks: []
        )
        XCTAssertEqual(result, .notFulfilled)
    }

    // MARK: - evaluateWeeklyFulfillment: Feuer

    /// Verhalten: Feuer + 3 wichtige Tasks → .fulfilled
    func test_evaluateWeeklyFulfillment_feuer_fulfilled() {
        let tasks = (1...3).map { _ in
            makeTask(importance: 3, isCompleted: true, completedAt: today)
        }
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .feuer, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Feuer with 3+ importance-3 tasks should be fulfilled")
    }

    /// Verhalten: Feuer + 1-2 wichtige Tasks → .partial
    func test_evaluateWeeklyFulfillment_feuer_partial() {
        let task = makeTask(importance: 3, isCompleted: true, completedAt: today)
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .feuer, tasks: [task], focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "Feuer with 1-2 importance-3 tasks should be partial")
    }

    // MARK: - evaluateWeeklyFulfillment: Eule

    /// Verhalten: Eule + 70%+ Wochen-Block-Completion → .fulfilled
    func test_evaluateWeeklyFulfillment_eule_fulfilled() {
        let block = makeBlock(
            taskIDs: ["t1", "t2", "t3", "t4"],
            completedTaskIDs: ["t1", "t2", "t3"]
        )
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .eule, tasks: [], focusBlocks: [block]
        )
        XCTAssertEqual(result, .fulfilled, "Eule with 75% weekly block completion should be fulfilled")
    }

    // MARK: - evaluateWeeklyFulfillment: Golem

    /// Verhalten: Golem + 4+ Kategorien diese Woche → .fulfilled
    func test_evaluateWeeklyFulfillment_golem_fulfilled() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
            makeTask(isCompleted: true, completedAt: today, taskType: "giving_back"),
            makeTask(isCompleted: true, completedAt: today, taskType: "maintenance"),
        ]
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .golem, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .fulfilled, "Golem with 4+ categories this week should be fulfilled")
    }

    /// Verhalten: Golem + 2-3 Kategorien → .partial
    func test_evaluateWeeklyFulfillment_golem_partial() {
        let tasks = [
            makeTask(isCompleted: true, completedAt: today, taskType: "income"),
            makeTask(isCompleted: true, completedAt: today, taskType: "learning"),
        ]
        let result = IntentionEvaluationService.evaluateWeeklyFulfillment(
            coach: .golem, tasks: tasks, focusBlocks: []
        )
        XCTAssertEqual(result, .partial, "Golem with 2-3 categories should be partial")
    }

    // MARK: - weeklyFallbackTemplate

    /// Verhalten: Jeder Coach + fulfilled hat einen nicht-leeren WOCHEN-Template-Text.
    func test_weeklyFallbackTemplate_allCoaches_fulfilled() {
        for coach in CoachType.allCases {
            let text = IntentionEvaluationService.weeklyFallbackTemplate(
                coach: coach, level: .fulfilled
            )
            XCTAssertFalse(text.isEmpty, "\(coach) weekly fulfilled should have a template")
        }
    }

    /// Verhalten: Jeder Coach + notFulfilled hat einen nicht-leeren WOCHEN-Template-Text.
    func test_weeklyFallbackTemplate_allCoaches_notFulfilled() {
        for coach in CoachType.allCases {
            let text = IntentionEvaluationService.weeklyFallbackTemplate(
                coach: coach, level: .notFulfilled
            )
            XCTAssertFalse(text.isEmpty, "\(coach) weekly notFulfilled should have a template")
        }
    }

    /// Verhalten: Wochen-Templates unterscheiden sich von Tages-Templates.
    func test_weeklyFallbackTemplate_differFromDailyTemplates() {
        for coach in CoachType.allCases {
            let daily = IntentionEvaluationService.fallbackTemplate(
                coach: coach, level: .fulfilled
            )
            let weekly = IntentionEvaluationService.weeklyFallbackTemplate(
                coach: coach, level: .fulfilled
            )
            XCTAssertNotEqual(daily, weekly, "\(coach) weekly template should differ from daily")
        }
    }
}
