import XCTest
@testable import FocusBlox

final class SuccessStoryServiceTests: XCTestCase {

    // MARK: - Fallback Templates

    /// Verhalten: Bei 0 erledigten Tasks gibt fallback einen ermutigenden Text zurueck (kein negativer Text).
    /// Bricht wenn: SuccessStoryService.fallback() bei leerer completedTasks-Liste keinen ermutigenden Text liefert.
    func test_fallback_zeroTasks_returnsEncouragement() {
        let story = SuccessStoryService.fallback(completedTasks: [], focusBlocks: [])

        XCTAssertFalse(story.isEmpty, "Fallback bei 0 Tasks darf nicht leer sein")
        XCTAssertTrue(
            story.contains("Morgen") || story.contains("neuer") || story.contains("ruhiger"),
            "Fallback bei 0 Tasks soll ermutigend sein, nicht negativ. Erhalten: '\(story)'"
        )
    }

    /// Verhalten: Bei >0 erledigten Tasks enthaelt der Fallback die Task-Anzahl.
    /// Bricht wenn: SuccessStoryService.fallback() die Anzahl nicht in den Text einbaut.
    func test_fallback_withTasks_includesTaskCount() {
        let tasks = makePlanItems(count: 3)
        let story = SuccessStoryService.fallback(completedTasks: tasks, focusBlocks: [])

        XCTAssertTrue(
            story.contains("3"),
            "Fallback soll die Anzahl erledigter Tasks enthalten. Erhalten: '\(story)'"
        )
    }

    /// Verhalten: Bei vorhandenen FocusBlocks enthaelt der Fallback die Focus-Minuten.
    /// Bricht wenn: SuccessStoryService.totalFocusMinutes() nicht berechnet oder nicht eingebaut wird.
    func test_fallback_withFocusBlocks_includesFocusMinutes() {
        let tasks = makePlanItems(count: 2)
        let blocks = makeFocusBlocks(durations: [30, 45]) // 75 Minuten gesamt
        let story = SuccessStoryService.fallback(completedTasks: tasks, focusBlocks: blocks)

        XCTAssertTrue(
            story.contains("75"),
            "Fallback soll Focus-Minuten enthalten (75 Min). Erhalten: '\(story)'"
        )
    }

    /// Verhalten: Bei FocusBlocks mit 0 Minuten werden keine Focus-Minuten im Text erwaehnt.
    /// Bricht wenn: SuccessStoryService.fallback() auch bei 0 Minuten Focus-Text einbaut.
    func test_fallback_zeroFocusMinutes_omitsFocusText() {
        let tasks = makePlanItems(count: 1)
        let story = SuccessStoryService.fallback(completedTasks: tasks, focusBlocks: [])

        XCTAssertFalse(
            story.contains("Minuten fokussiert"),
            "Fallback ohne FocusBlocks soll keine Focus-Zeit erwaehnen. Erhalten: '\(story)'"
        )
    }

    // MARK: - Focus Minutes Calculation

    /// Verhalten: totalFocusMinutes berechnet die Summe aller FocusBlock-Dauern.
    /// Bricht wenn: SuccessStoryService.totalFocusMinutes() die Summe falsch berechnet.
    func test_totalFocusMinutes_sumsAllBlocks() {
        let blocks = makeFocusBlocks(durations: [15, 30, 45])
        let minutes = SuccessStoryService.totalFocusMinutes(from: blocks)

        XCTAssertEqual(minutes, 90, "15 + 30 + 45 = 90 Minuten")
    }

    /// Verhalten: totalFocusMinutes gibt 0 bei leerer Liste.
    /// Bricht wenn: SuccessStoryService.totalFocusMinutes() bei leerer Liste nicht 0 liefert.
    func test_totalFocusMinutes_emptyBlocks_returnsZero() {
        let minutes = SuccessStoryService.totalFocusMinutes(from: [])

        XCTAssertEqual(minutes, 0)
    }

    // MARK: - ISO Date

    /// Verhalten: isoDate gibt das Datum im Format yyyy-MM-dd zurueck.
    /// Bricht wenn: SuccessStoryService.isoDate() das falsche Format nutzt.
    func test_isoDate_formatsCorrectly() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 26))!
        let result = SuccessStoryService.isoDate(date)

        XCTAssertEqual(result, "2026-03-26", "ISO-Datum soll yyyy-MM-dd Format haben")
    }

    // MARK: - Prompt Building

    /// Verhalten: buildPrompt enthaelt Task-Titel und Kategorien (max 10 Tasks).
    /// Bricht wenn: SuccessStoryService.buildPrompt() die Tasks nicht korrekt formatiert.
    func test_buildPrompt_includesTaskTitlesAndCategories() {
        let tasks = [
            makePlanItem(title: "Bericht schreiben", taskType: "income"),
            makePlanItem(title: "E-Mails beantworten", taskType: "maintenance"),
        ]
        let prompt = SuccessStoryService.buildPrompt(completedTasks: tasks, focusBlocks: [])

        XCTAssertTrue(prompt.contains("Bericht schreiben"), "Prompt soll Task-Titel enthalten")
        XCTAssertTrue(prompt.contains("income"), "Prompt soll Kategorie enthalten")
    }

    /// Verhalten: buildPrompt begrenzt auf max 10 Tasks.
    /// Bricht wenn: SuccessStoryService.buildPrompt() mehr als 10 Tasks in den Prompt schreibt.
    func test_buildPrompt_limitsTo10Tasks() {
        let tasks = makePlanItems(count: 15)
        let prompt = SuccessStoryService.buildPrompt(completedTasks: tasks, focusBlocks: [])

        // Zaehle "Task" Vorkommen im Erledigte-Tasks-Bereich — maximal 10
        let taskLines = prompt.components(separatedBy: "\n").filter { $0.contains("Task ") }
        XCTAssertLessThanOrEqual(
            taskLines.count, 10,
            "Prompt soll maximal 10 Tasks enthalten, hat \(taskLines.count)"
        )
    }

    /// Verhalten: buildPrompt listet ueberwundene Blockaden (rescheduleCount > 0).
    /// Bricht wenn: SuccessStoryService.buildPrompt() rescheduleCount nicht beruecksichtigt.
    func test_buildPrompt_includesOvercomeBlockades() {
        let tasks = [
            makePlanItem(title: "Schwieriger Task", rescheduleCount: 3),
            makePlanItem(title: "Einfacher Task", rescheduleCount: 0),
        ]
        let prompt = SuccessStoryService.buildPrompt(completedTasks: tasks, focusBlocks: [])

        XCTAssertTrue(
            prompt.contains("Schwieriger Task"),
            "Prompt soll ueberwundene Blockaden enthalten"
        )
        // "Einfacher Task" darf im Blockaden-Bereich NICHT erscheinen
        let blockadeSection = prompt.components(separatedBy: "Blockaden").last ?? ""
        XCTAssertFalse(
            blockadeSection.contains("Einfacher Task"),
            "Tasks ohne Reschedule sollen nicht in Blockaden-Sektion"
        )
    }

    // MARK: - Helpers

    private func makePlanItem(
        title: String = "Test Task",
        taskType: String = "",
        rescheduleCount: Int = 0
    ) -> PlanItem {
        PlanItem(localTask: makeLocalTask(
            title: title,
            taskType: taskType,
            rescheduleCount: rescheduleCount
        ))
    }

    private func makePlanItems(count: Int) -> [PlanItem] {
        (0..<count).map { i in
            makePlanItem(title: "Task \(i + 1)")
        }
    }

    private func makeLocalTask(
        title: String,
        taskType: String = "",
        rescheduleCount: Int = 0
    ) -> LocalTask {
        let task = LocalTask(title: title)
        task.taskType = taskType
        task.rescheduleCount = rescheduleCount
        task.isCompleted = true
        task.completedAt = Date()
        return task
    }

    private func makeFocusBlocks(durations: [Int]) -> [FocusBlock] {
        durations.enumerated().map { (i, minutes) in
            let start = Date()
            let end = start.addingTimeInterval(Double(minutes) * 60)
            return FocusBlock(
                id: "block-\(i)",
                title: "Focus \(i)",
                startDate: start,
                endDate: end
            )
        }
    }
}
