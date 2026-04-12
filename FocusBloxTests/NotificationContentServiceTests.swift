import XCTest
@testable import FocusBlox

/// TDD RED Tests for #173: KI-gestützte Notification-Inhalte
/// Tests MÜSSEN FEHLSCHLAGEN bis NotificationContentService implementiert ist.
@MainActor
final class NotificationContentServiceTests: XCTestCase {

    // MARK: - Morning Content

    /// Bricht wenn: NotificationContentService nicht existiert (Compile Error)
    /// oder morningContent den Task-Namen nicht enthält.
    func test_morningFallback_mentionsTaskByName() {
        let taskTitle = "Steuererklärung abgeben"
        let result = NotificationContentService.morningFallback(
            topTaskTitle: taskTitle,
            daysSinceCreated: 21,
            freeMinutes: 90
        )

        XCTAssertTrue(result.body.contains("Steuererklärung"),
                       "Morning fallback must mention task by name. Got: \(result.body)")
    }

    /// Bricht wenn: Morning-Fallback keine Zeitangabe enthält.
    func test_morningFallback_mentionsFreeTime() {
        let result = NotificationContentService.morningFallback(
            topTaskTitle: "Projekt X",
            daysSinceCreated: 5,
            freeMinutes: 120
        )

        XCTAssertTrue(result.body.contains("120") || result.body.contains("2 Std"),
                       "Morning fallback must mention free time. Got: \(result.body)")
    }

    /// Bricht wenn: suggestedTaskID im Morning-Content fehlt.
    func test_morningFallback_includesSuggestedTaskID() {
        let result = NotificationContentService.morningFallback(
            topTaskTitle: "Projekt X",
            daysSinceCreated: 3,
            freeMinutes: 60,
            suggestedTaskID: "test-uuid-123"
        )

        XCTAssertEqual(result.suggestedTaskID, "test-uuid-123",
                        "Morning content must include suggestedTaskID")
    }

    // MARK: - Evening Content

    /// Bricht wenn: Evening-Fallback den erledigten Task nicht beim Namen nennt.
    func test_eveningFallback_mentionsCompletedTask() {
        let result = NotificationContentService.eveningFallback(
            completedTaskTitles: ["Steuererklärung abgeben", "E-Mails beantworten"],
            focusMinutes: 120,
            hardestTaskTitle: "Steuererklärung abgeben",
            hardestTaskDaysOpen: 21
        )

        XCTAssertTrue(result.body.contains("Steuererklärung"),
                       "Evening fallback must mention completed task. Got: \(result.body)")
    }

    /// Bricht wenn: Evening-Content unerledigte Tasks erwähnt (Guilt-Tripping).
    func test_eveningFallback_neverMentionsUnfinished() {
        let result = NotificationContentService.eveningFallback(
            completedTaskTitles: ["Kleine Aufgabe"],
            focusMinutes: 30,
            hardestTaskTitle: nil,
            hardestTaskDaysOpen: 0
        )

        let forbidden = ["nicht geschafft", "nicht erledigt", "offen geblieben", "versäumt", "verpasst"]
        for word in forbidden {
            XCTAssertFalse(result.body.lowercased().contains(word),
                           "Evening content must NEVER mention unfinished tasks. Found '\(word)' in: \(result.body)")
        }
    }

    /// Bricht wenn: Evening-Fallback bei leerem Tag vorwurfsvoll ist.
    func test_eveningFallback_emptyDay_isCompassionate() {
        let result = NotificationContentService.eveningFallback(
            completedTaskTitles: [],
            focusMinutes: 0,
            hardestTaskTitle: nil,
            hardestTaskDaysOpen: 0
        )

        XCTAssertFalse(result.body.isEmpty, "Even empty day should have a message")
        let forbidden = ["nichts", "gar nicht", "0 Tasks", "kein einziger"]
        for word in forbidden {
            XCTAssertFalse(result.body.lowercased().contains(word),
                           "Empty day message must be compassionate, not guilt-tripping. Found '\(word)' in: \(result.body)")
        }
    }

    // MARK: - Notification Category

    /// Bricht wenn: Die DAILY_COMPANION Kategorie nicht registriert wird.
    func test_dailyCompanionCategory_isRegistered() {
        // NotificationService muss die Kategorie kennen
        let categoryID = NotificationContentService.dailyCompanionCategoryID
        XCTAssertEqual(categoryID, "DAILY_COMPANION",
                       "Category ID must be DAILY_COMPANION")
    }

    // MARK: - Prompt Building

    /// Bricht wenn: Morning-Prompt den Task-Namen nicht enthält.
    func test_buildMorningPrompt_containsTaskName() {
        let prompt = NotificationContentService.buildMorningPrompt(
            topTaskTitle: "Steuererklärung",
            daysSinceCreated: 21,
            freeMinutes: 90,
            meetingCount: 2
        )

        XCTAssertTrue(prompt.contains("Steuererklärung"),
                       "Morning prompt must contain task name")
        XCTAssertTrue(prompt.contains("21"),
                       "Morning prompt must contain days since created")
        XCTAssertTrue(prompt.contains("90"),
                       "Morning prompt must contain free minutes")
    }

    /// Bricht wenn: Evening-Prompt den erledigten Task nicht enthält.
    func test_buildEveningPrompt_containsCompletedTasks() {
        let prompt = NotificationContentService.buildEveningPrompt(
            completedTaskTitles: ["Steuererklärung", "E-Mails"],
            focusMinutes: 120,
            hardestTaskTitle: "Steuererklärung",
            hardestTaskDaysOpen: 21
        )

        XCTAssertTrue(prompt.contains("Steuererklärung"),
                       "Evening prompt must contain completed task name")
    }
}
