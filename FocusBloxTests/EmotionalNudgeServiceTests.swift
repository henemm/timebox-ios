import XCTest
@testable import FocusBlox

/// TDD RED: Tests fuer EmotionalNudgeService.
///
/// Der Service prueft ob ein Nudge fuer einen chronisch verschobenen Task
/// angezeigt werden darf (Daily-Limits), generiert rotierende Motivationstexte,
/// und trackt welche Tasks heute schon genudget wurden.
///
/// Diese Tests muessen FEHLSCHLAGEN weil EmotionalNudgeService noch nicht existiert.
@MainActor
final class EmotionalNudgeServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset Nudge-Tracking in AppSettings vor jedem Test
        let settings = AppSettings.shared
        settings.nudgeDailyCount = 0
        settings.nudgeLastDate = ""
        settings.nudgeTaskIDs = ""
    }

    // MARK: - Test 1: canShowNudge gibt true wenn Limits nicht erreicht

    /// GIVEN: Kein Nudge heute gezeigt, Daily-Count = 0
    /// WHEN: canShowNudge(for: "task-abc") aufgerufen
    /// THEN: true — Task darf genudget werden
    ///
    /// Bricht wenn: EmotionalNudgeService.canShowNudge() nicht existiert (Compiler-Fehler)
    /// oder guard-Bedingung falsch ist (z.B. < 0 statt < 3)
    func test_canShowNudge_noLimitsReached_returnsTrue() {
        let result = EmotionalNudgeService.canShowNudge(for: "task-abc")
        XCTAssertTrue(result, "Nudge sollte erlaubt sein wenn kein Limit erreicht")
    }

    // MARK: - Test 2: canShowNudge gibt false bei Daily-Limit

    /// GIVEN: Heute schon 3 Nudges gezeigt (= Maximum)
    /// WHEN: canShowNudge(for: "task-new") aufgerufen
    /// THEN: false — Tageslimit erreicht
    ///
    /// Bricht wenn: guard settings.nudgeDailyCount < 3 fehlt oder Schwelle falsch
    func test_canShowNudge_dailyLimitReached_returnsFalse() {
        let settings = AppSettings.shared
        settings.nudgeDailyCount = 3
        settings.nudgeLastDate = isoToday()

        let result = EmotionalNudgeService.canShowNudge(for: "task-new")
        XCTAssertFalse(result, "Nudge sollte bei 3 Nudges/Tag gesperrt sein")
    }

    // MARK: - Test 3: canShowNudge gibt false wenn Task heute schon genudget

    /// GIVEN: Task "task-abc" wurde heute schon genudget
    /// WHEN: canShowNudge(for: "task-abc") aufgerufen
    /// THEN: false — max 1 Nudge pro Task pro Tag
    ///
    /// Bricht wenn: .contains(taskID) Check fehlt oder nudgeTaskIDs nicht geprueft wird
    func test_canShowNudge_taskAlreadyNudgedToday_returnsFalse() {
        let settings = AppSettings.shared
        settings.nudgeDailyCount = 1
        settings.nudgeLastDate = isoToday()
        settings.nudgeTaskIDs = "task-abc"

        let result = EmotionalNudgeService.canShowNudge(for: "task-abc")
        XCTAssertFalse(result, "Task darf nur 1x pro Tag genudget werden")
    }

    // MARK: - Test 4: canShowNudge erlaubt anderen Task auch wenn einer schon genudget

    /// GIVEN: Task "task-abc" genudget, aber "task-xyz" noch nicht
    /// WHEN: canShowNudge(for: "task-xyz") aufgerufen
    /// THEN: true — anderer Task, noch nicht genudget
    ///
    /// Bricht wenn: contains-Check alle Tasks sperrt statt nur den genudgeten
    func test_canShowNudge_differentTask_returnsTrue() {
        let settings = AppSettings.shared
        settings.nudgeDailyCount = 1
        settings.nudgeLastDate = isoToday()
        settings.nudgeTaskIDs = "task-abc"

        let result = EmotionalNudgeService.canShowNudge(for: "task-xyz")
        XCTAssertTrue(result, "Anderer Task sollte noch genudget werden duerfen")
    }

    // MARK: - Test 5: recordNudge zaehlt Daily-Count hoch und merkt Task-ID

    /// GIVEN: Keine Nudges heute
    /// WHEN: recordNudge(for: "task-abc") aufgerufen
    /// THEN: nudgeDailyCount == 1, nudgeTaskIDs enthaelt "task-abc"
    ///
    /// Bricht wenn: recordNudge() nudgeDailyCount nicht inkrementiert
    /// oder Task-ID nicht zu nudgeTaskIDs hinzufuegt
    func test_recordNudge_incrementsCountAndAddsTaskID() {
        let settings = AppSettings.shared
        settings.nudgeLastDate = isoToday()

        EmotionalNudgeService.recordNudge(for: "task-abc")

        XCTAssertEqual(settings.nudgeDailyCount, 1, "Count sollte um 1 gestiegen sein")
        XCTAssertTrue(
            settings.nudgeTaskIDs.contains("task-abc"),
            "Task-ID sollte in der Nudge-Liste stehen"
        )
    }

    // MARK: - Test 6: resetIfNewDay setzt Counter zurueck

    /// GIVEN: nudgeLastDate ist gestern, Count = 3, TaskIDs gefuellt
    /// WHEN: resetIfNewDay() aufgerufen (implizit durch canShowNudge)
    /// THEN: Count = 0, TaskIDs leer, LastDate = heute
    ///
    /// Bricht wenn: Datums-Vergleich in resetIfNewDay() fehlt oder Logik invertiert
    func test_resetIfNewDay_resetsCountersOnNewDay() {
        let settings = AppSettings.shared
        settings.nudgeDailyCount = 3
        settings.nudgeTaskIDs = "task-1,task-2,task-3"
        settings.nudgeLastDate = "2020-01-01" // definitiv nicht heute

        // canShowNudge ruft intern resetIfNewDay() auf
        let result = EmotionalNudgeService.canShowNudge(for: "task-new")

        XCTAssertTrue(result, "Nach Reset sollte Nudge wieder erlaubt sein")
        XCTAssertEqual(settings.nudgeDailyCount, 0, "Count sollte zurueckgesetzt sein")
        XCTAssertEqual(settings.nudgeTaskIDs, "", "TaskIDs sollten leer sein")
    }

    // MARK: - Test 7: nudgeText rotiert durch verschiedene Varianten

    /// GIVEN: nudgeDailyCount variiert (0, 1, 2)
    /// WHEN: nudgeText() aufgerufen
    /// THEN: Verschiedene Texte zurueckgegeben (nicht immer derselbe)
    ///
    /// Bricht wenn: nudgeDailyCount % nudgeTexts.count nicht als Index genutzt wird
    func test_nudgeText_rotatesDifferentTexts() {
        let settings = AppSettings.shared
        settings.nudgeLastDate = isoToday()

        settings.nudgeDailyCount = 0
        let text0 = EmotionalNudgeService.nudgeText()

        settings.nudgeDailyCount = 1
        let text1 = EmotionalNudgeService.nudgeText()

        settings.nudgeDailyCount = 2
        let text2 = EmotionalNudgeService.nudgeText()

        // Mindestens 2 verschiedene Texte bei 3 verschiedenen Counts
        let uniqueTexts = Set([text0, text1, text2])
        XCTAssertGreaterThanOrEqual(
            uniqueTexts.count, 2,
            "Verschiedene Counts sollten verschiedene Nudge-Texte liefern"
        )
    }

    // MARK: - Helpers

    private func isoToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
