import XCTest
import SwiftData
@testable import FocusBlox

/// TDD: Coach Morning Task-Vorschläge mit Begründung (#201).
@MainActor
final class CoachMorningSuggestionTests: XCTestCase {

    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: LocalTask.self, DayIntention.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    // MARK: - reasonText Tests

    /// Deadline morgen → "Deadline morgen"
    func test_reasonText_deadlineTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let item = makePlanItem(title: "Steuererklärung", dueDate: tomorrow)
        let reason = NextUpSuggestionService.reasonText(for: item)
        XCTAssertTrue(reason.lowercased().contains("deadline"),
            "Reason '\(reason)' sollte 'Deadline' enthalten bei Fälligkeit morgen")
    }

    /// Deadline in 5 Tagen → kein Deadline-Text
    func test_reasonText_deadlineFarAway_noDeadlineText() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let item = makePlanItem(title: "Irgendwann", dueDate: future)
        let reason = NextUpSuggestionService.reasonText(for: item)
        XCTAssertFalse(reason.lowercased().contains("deadline"),
            "Reason '\(reason)' sollte KEIN 'Deadline' enthalten bei 5 Tagen Abstand")
    }

    /// 3x verschoben → erwähnt Verschiebung
    func test_reasonText_rescheduled3x() {
        let item = makePlanItem(title: "Aufgeschobenes", rescheduleCount: 3)
        let reason = NextUpSuggestionService.reasonText(for: item)
        XCTAssertTrue(reason.contains("3") && reason.lowercased().contains("verschoben"),
            "Reason '\(reason)' sollte '3x verschoben' erwähnen")
    }

    /// Importance 3 → "Sehr wichtig"
    func test_reasonText_highImportance() {
        let item = makePlanItem(title: "Wichtiges", importance: 3)
        let reason = NextUpSuggestionService.reasonText(for: item)
        XCTAssertTrue(reason.lowercased().contains("wichtig"),
            "Reason '\(reason)' sollte 'wichtig' enthalten bei Importance 3")
    }

    /// Kein besonderer Grund → Fallback nicht leer
    func test_reasonText_fallback_notEmpty() {
        let item = makePlanItem(title: "Normaler Task")
        let reason = NextUpSuggestionService.reasonText(for: item)
        XCTAssertFalse(reason.isEmpty, "Reason darf nicht leer sein")
    }

    /// Reason ist kurz genug (max 80 Zeichen)
    func test_reasonText_isShortEnough() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let item = makePlanItem(title: "Viel", importance: 3, rescheduleCount: 5, dueDate: tomorrow)
        let reason = NextUpSuggestionService.reasonText(for: item)
        XCTAssertLessThanOrEqual(reason.count, 150,
            "Reason '\(reason)' ist zu lang (\(reason.count) Zeichen, max 150)")
    }

    // MARK: - Helpers

    private func makePlanItem(
        title: String,
        importance: Int = 2,
        rescheduleCount: Int = 0,
        dueDate: Date? = nil
    ) -> PlanItem {
        let task = LocalTask(title: title, importance: importance, estimatedDuration: 30, urgency: "not_urgent")
        task.rescheduleCount = rescheduleCount
        task.dueDate = dueDate
        context.insert(task)
        return PlanItem(localTask: task)
    }
}
