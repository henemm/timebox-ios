import XCTest
import SwiftData
@testable import FocusBlox

/// Unit Tests for LocalTask.isVisibleInBacklog — the shared filter that hides
/// future-dated recurring task instances from the backlog.
///
/// EXPECTED TO FAIL: isVisibleInBacklog does not exist on LocalTask yet.
///
/// These tests verify the core business logic that both iOS (LocalTaskSource)
/// and macOS (ContentView.filteredTasks) will use.
final class RecurringVisibilityFilterTests: XCTestCase {

    // MARK: - isVisibleInBacklog Tests

    /// Non-recurring task with future dueDate should be visible (filter only affects recurring)
    /// Bricht wenn: LocalTask.isVisibleInBacklog guard fuer recurrencePattern entfernt wird
    func test_isVisibleInBacklog_nonRecurring_futureDate_returnsTrue() {
        let task = LocalTask(
            title: "Einmal-Task morgen",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            recurrencePattern: "none"
        )
        XCTAssertTrue(task.isVisibleInBacklog, "Non-recurring tasks must always be visible regardless of dueDate")
    }

    /// Recurring task without dueDate should be visible (no date to filter on)
    /// Bricht wenn: LocalTask.isVisibleInBacklog guard fuer dueDate==nil entfernt wird
    func test_isVisibleInBacklog_recurring_noDueDate_returnsTrue() {
        let task = LocalTask(
            title: "Wiederkehrend ohne Datum",
            recurrencePattern: "daily"
        )
        XCTAssertTrue(task.isVisibleInBacklog, "Recurring tasks without dueDate must always be visible")
    }

    /// Recurring task due today should be visible
    /// Bricht wenn: Vergleich dueDate < startOfTomorrow zu dueDate < startOfToday geaendert wird
    func test_isVisibleInBacklog_recurring_dueToday_returnsTrue() {
        let today = Calendar.current.startOfDay(for: Date())
        let task = LocalTask(
            title: "Heute faellig",
            dueDate: today,
            recurrencePattern: "daily"
        )
        XCTAssertTrue(task.isVisibleInBacklog, "Recurring tasks due today must be visible")
    }

    /// Recurring task due tomorrow should be HIDDEN
    /// Bricht wenn: LocalTask.isVisibleInBacklog Vergleichslogik entfernt oder invertiert wird
    func test_isVisibleInBacklog_recurring_dueTomorrow_returnsFalse() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = LocalTask(
            title: "Morgen faellig",
            dueDate: tomorrow,
            recurrencePattern: "weekly"
        )
        XCTAssertFalse(task.isVisibleInBacklog, "Recurring tasks with future dueDate must be hidden")
    }

    /// Recurring task overdue (yesterday) should be visible
    /// Bricht wenn: Filter auch vergangene Daten ausschliesst
    func test_isVisibleInBacklog_recurring_dueYesterday_returnsTrue() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = LocalTask(
            title: "Gestern faellig",
            dueDate: yesterday,
            recurrencePattern: "daily"
        )
        XCTAssertTrue(task.isVisibleInBacklog, "Overdue recurring tasks must be visible")
    }

    /// Recurring task due far in the future (next month) should be HIDDEN
    /// Bricht wenn: Filter nur 1 Tag voraus prueft statt generell Zukunft
    func test_isVisibleInBacklog_recurring_dueNextMonth_returnsFalse() {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        let task = LocalTask(
            title: "Naechsten Monat faellig",
            dueDate: nextMonth,
            recurrencePattern: "monthly"
        )
        XCTAssertFalse(task.isVisibleInBacklog, "Recurring tasks due next month must be hidden")
    }

    /// Different recurrence patterns should all be filtered the same way
    /// Bricht wenn: Filter nur fuer bestimmte Patterns gilt (z.B. nur "daily")
    func test_isVisibleInBacklog_allPatterns_futureDateHidden() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let patterns = ["daily", "weekly", "biweekly", "monthly"]

        for pattern in patterns {
            let task = LocalTask(
                title: "Task \(pattern)",
                dueDate: tomorrow,
                recurrencePattern: pattern
            )
            XCTAssertFalse(task.isVisibleInBacklog, "\(pattern) recurring task with future date must be hidden")
        }
    }
}
