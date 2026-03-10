import XCTest
@testable import FocusBlox

final class MenuBarIconStateTests: XCTestCase {

    // MARK: - Idle State Tests

    /// Verhalten: Kein aktiver Block → idle (cube.fill)
    /// Bricht wenn: MenuBarIconState.from() nil-Block-Handling falsch
    func test_iconState_noBlock_returnsIdle() {
        let state = MenuBarIconState.from(block: nil, now: Date())
        XCTAssertEqual(state, .idle)
    }

    /// Verhalten: Abgelaufener Block → idle
    /// Bricht wenn: MenuBarIconState.from() isActive-Check fehlt
    func test_iconState_pastBlock_returnsIdle() {
        let now = Date()
        let block = FocusBlock(
            id: "past",
            title: "Past Block",
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            taskIDs: ["t1"],
            completedTaskIDs: []
        )

        let state = MenuBarIconState.from(block: block, now: now)
        XCTAssertEqual(state, .idle)
    }

    // MARK: - Active State Tests

    /// Verhalten: Aktiver Block mit verbleibender Zeit → .active("10:00")
    /// Bricht wenn: MenuBarIconState.from() active-Branch fehlt oder Timer-Format falsch
    func test_iconState_activeBlock_returnsActiveWithTimer() {
        let now = Date()
        let block = FocusBlock(
            id: "active",
            title: "Test Block",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600),
            taskIDs: ["t1", "t2"],
            completedTaskIDs: ["t1"]
        )

        let state = MenuBarIconState.from(block: block, now: now)
        if case .active(let text) = state {
            XCTAssertEqual(text, "10:00", "Should show remaining 10 minutes")
        } else {
            XCTFail("Expected .active state, got \(state)")
        }
    }

    /// Verhalten: Block mit 63 Sekunden verbleibend → .active("1:03")
    /// Bricht wenn: Sekunden-Formatierung (leading zero) falsch
    func test_iconState_activeBlock_formatsSecondsCorrectly() {
        let now = Date()
        let block = FocusBlock(
            id: "active-secs",
            title: "Short Block",
            startDate: now.addingTimeInterval(-300),
            endDate: now.addingTimeInterval(63),
            taskIDs: ["t1"],
            completedTaskIDs: []
        )

        let state = MenuBarIconState.from(block: block, now: now)
        if case .active(let text) = state {
            XCTAssertEqual(text, "1:03")
        } else {
            XCTFail("Expected .active state, got \(state)")
        }
    }

    // MARK: - All Done State Tests

    /// Verhalten: Alle Tasks erledigt im aktiven Block → .allDone
    /// Bricht wenn: MenuBarIconState.from() allDone-Branch fehlt
    func test_iconState_allTasksCompleted_returnsAllDone() {
        let now = Date()
        let block = FocusBlock(
            id: "done",
            title: "Done Block",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600),
            taskIDs: ["t1", "t2"],
            completedTaskIDs: ["t1", "t2"]
        )

        let state = MenuBarIconState.from(block: block, now: now)
        XCTAssertEqual(state, .allDone)
    }

    /// Verhalten: Block ohne Tasks (edge case) → .active (nicht allDone)
    /// Bricht wenn: Division by zero oder leere taskIDs triggert allDone
    func test_iconState_emptyTaskIDs_returnsActive_notAllDone() {
        let now = Date()
        let block = FocusBlock(
            id: "empty",
            title: "Empty Block",
            startDate: now.addingTimeInterval(-60),
            endDate: now.addingTimeInterval(60),
            taskIDs: [],
            completedTaskIDs: []
        )

        let state = MenuBarIconState.from(block: block, now: now)
        if case .active = state {
            // OK — empty block should show timer, not allDone
        } else if state == .allDone {
            XCTFail("Empty taskIDs should not trigger allDone")
        }
    }

    // MARK: - Task End Date Tests (Bug: MenuBar shows block time instead of task time)

    /// Verhalten: taskEndDate angegeben → Timer zeigt Task-Restzeit, nicht Block-Restzeit
    /// Bricht wenn: MenuBarIconState.from() den taskEndDate-Parameter ignoriert
    func test_iconState_withTaskEndDate_showsTaskRemainingTime() {
        let now = Date()
        let block = FocusBlock(
            id: "multi-task",
            title: "Multi Task Block",
            startDate: now.addingTimeInterval(-600),  // started 10 min ago
            endDate: now.addingTimeInterval(2400),     // ends in 40 min
            taskIDs: ["t1", "t2", "t3"],
            completedTaskIDs: []
        )
        // Task ends in 5 minutes (not 40 like the block)
        let taskEndDate = now.addingTimeInterval(300)

        let state = MenuBarIconState.from(block: block, now: now, taskEndDate: taskEndDate)
        if case .active(let text) = state {
            XCTAssertEqual(text, "5:00", "Should show task remaining (5 min), not block remaining (40 min)")
        } else {
            XCTFail("Expected .active state, got \(state)")
        }
    }

    /// Verhalten: taskEndDate nil → Fallback auf Block-Restzeit (Rueckwaertskompatibilitaet)
    /// Bricht wenn: nil-Handling fuer taskEndDate fehlt
    func test_iconState_withoutTaskEndDate_showsBlockRemainingTime() {
        let now = Date()
        let block = FocusBlock(
            id: "fallback",
            title: "Fallback Block",
            startDate: now.addingTimeInterval(-600),
            endDate: now.addingTimeInterval(600),
            taskIDs: ["t1"],
            completedTaskIDs: []
        )

        let state = MenuBarIconState.from(block: block, now: now, taskEndDate: nil)
        if case .active(let text) = state {
            XCTAssertEqual(text, "10:00", "Without taskEndDate, should fall back to block remaining (10 min)")
        } else {
            XCTFail("Expected .active state, got \(state)")
        }
    }

    /// Verhalten: taskEndDate in Vergangenheit → Timer zeigt 0:00 (Task ueberfaellig)
    /// Bricht wenn: Negative Werte nicht geclamped werden
    func test_iconState_withOverdueTaskEndDate_showsZero() {
        let now = Date()
        let block = FocusBlock(
            id: "overdue",
            title: "Overdue Block",
            startDate: now.addingTimeInterval(-1800),
            endDate: now.addingTimeInterval(600),
            taskIDs: ["t1", "t2"],
            completedTaskIDs: []
        )
        // Task end date is 2 min in the past (overdue)
        let taskEndDate = now.addingTimeInterval(-120)

        let state = MenuBarIconState.from(block: block, now: now, taskEndDate: taskEndDate)
        if case .active(let text) = state {
            XCTAssertEqual(text, "0:00", "Overdue task should show 0:00")
        } else {
            XCTFail("Expected .active state, got \(state)")
        }
    }

    // MARK: - Timer Formatter Tests

    /// Bricht wenn: formatTimer Logik aendert sich
    func test_formatTimer_standard() {
        XCTAssertEqual(MenuBarIconState.formatTimer(863), "14:23")
    }

    func test_formatTimer_zero() {
        XCTAssertEqual(MenuBarIconState.formatTimer(0), "0:00")
    }

    func test_formatTimer_negative_clampedToZero() {
        XCTAssertEqual(MenuBarIconState.formatTimer(-5), "0:00")
    }

    func test_formatTimer_exactMinute() {
        XCTAssertEqual(MenuBarIconState.formatTimer(300), "5:00")
    }
}
