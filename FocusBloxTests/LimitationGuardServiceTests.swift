import XCTest
@testable import FocusBlox

final class LimitationGuardServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Erstellt ein BehavioralProfile mit nur avgTasksPerDay und avgMinutesPerDay.
    private func makeProfile(
        avgTasks: Double? = nil,
        avgMinutes: Double? = nil
    ) -> BehavioralProfile {
        BehavioralProfile(
            computedAt: Date(),
            categoryTimeAffinity: nil,
            avgTasksPerDay: avgTasks,
            avgMinutesPerDay: avgMinutes,
            estimationFactor: nil,
            capacityByMeetingLoad: nil,
            procrastinationPatterns: nil
        )
    }

    /// Erstellt N PlanItems mit gegebener Duration (Minuten).
    private func makeTasks(count: Int, duration: Int = 30) -> [PlanItem] {
        (0..<count).map { i in
            makePlanItem(title: "Task \(i)", effectiveDuration: duration)
        }
    }

    private func makePlanItem(title: String, effectiveDuration: Int = 30) -> PlanItem {
        let task = LocalTask(title: title)
        task.estimatedDuration = effectiveDuration
        task.isNextUp = true
        return PlanItem(localTask: task)
    }

    // MARK: - Nil Profile Tests

    /// Verhalten: Keine Warnung wenn beide Profil-Werte nil sind (zu wenig Daten).
    /// Bricht wenn: LimitationGuardService.evaluate() Guard-Clause fuer nil-Check entfernt wird.
    func test_noWarning_whenBothProfileValuesNil() {
        let profile = makeProfile(avgTasks: nil, avgMinutes: nil)
        let tasks = makeTasks(count: 10)

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNil(result, "Keine Warnung bei nil-Profildaten")
    }

    // MARK: - Below Threshold Tests

    /// Verhalten: Keine Warnung wenn Task-Anzahl unter 1.5x Durchschnitt.
    /// Bricht wenn: Schwellwert-Berechnung in evaluate() geaendert wird (z.B. 1.0x statt 1.5x).
    func test_noWarning_whenBelowThreshold() {
        let profile = makeProfile(avgTasks: 4.0, avgMinutes: 120.0)
        let tasks = makeTasks(count: 4, duration: 30) // 4 Tasks, 120 Min = exakt Durchschnitt

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNil(result, "Keine Warnung bei genau dem Durchschnitt")
    }

    /// Verhalten: Keine Warnung bei exakt 1.5x (Grenze ist >, nicht >=).
    /// Bricht wenn: > zu >= geaendert wird in der Threshold-Pruefung.
    func test_noWarning_atExactlyThreshold() {
        let profile = makeProfile(avgTasks: 4.0, avgMinutes: 120.0)
        // 6 Tasks = 1.5x von 4.0 = exakt Grenze → KEINE Warnung
        let tasks = makeTasks(count: 6, duration: 30) // 6 Tasks, 180 Min = 1.5x von 120

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNil(result, "Keine Warnung bei exakt 1.5x Schwellwert (> nicht >=)")
    }

    // MARK: - Warning Triggered Tests

    /// Verhalten: Warnung wenn Task-Anzahl > 1.5x Durchschnitt.
    /// Bricht wenn: Task-Count-Vergleich in evaluate() entfernt wird.
    func test_warning_whenTasksExceedThreshold() {
        let profile = makeProfile(avgTasks: 4.0, avgMinutes: nil)
        let tasks = makeTasks(count: 7, duration: 30) // 7 > 6 (1.5x von 4)

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNotNil(result, "Warnung bei 7 Tasks vs. Schnitt 4")
        XCTAssertEqual(result?.plannedTasks, 7)
        XCTAssertEqual(result?.avgTasks, 4.0)
    }

    /// Verhalten: Warnung wenn Minuten-Summe > 1.5x Durchschnitt.
    /// Bricht wenn: Minuten-Vergleich in evaluate() entfernt wird.
    func test_warning_whenMinutesExceedThreshold() {
        let profile = makeProfile(avgTasks: nil, avgMinutes: 120.0)
        // 5 Tasks a 50 Min = 250 Min > 180 (1.5x von 120)
        let tasks = makeTasks(count: 5, duration: 50)

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNotNil(result, "Warnung bei 250 Min vs. Schnitt 120")
        XCTAssertEqual(result?.plannedMinutes, 250)
        XCTAssertEqual(result?.avgMinutes, 120.0)
    }

    /// Verhalten: Warnung wenn nur Tasks ueberschreiten, nicht Minuten.
    /// Bricht wenn: Task-Check an Minuten-Check gekoppelt wird (AND statt OR).
    func test_warning_whenOnlyTasksExceed() {
        let profile = makeProfile(avgTasks: 4.0, avgMinutes: 300.0)
        // 7 Tasks > 6 (1.5x von 4), aber 210 Min < 450 (1.5x von 300)
        let tasks = makeTasks(count: 7, duration: 30)

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNotNil(result, "Warnung wenn nur Tasks ueberschreiten")
    }

    /// Verhalten: Warnung wenn nur Minuten ueberschreiten, nicht Tasks.
    /// Bricht wenn: Minuten-Check an Task-Check gekoppelt wird (AND statt OR).
    func test_warning_whenOnlyMinutesExceed() {
        let profile = makeProfile(avgTasks: 10.0, avgMinutes: 60.0)
        // 3 Tasks < 15 (1.5x von 10), aber 120 Min > 90 (1.5x von 60)
        let tasks = makeTasks(count: 3, duration: 40)

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNotNil(result, "Warnung wenn nur Minuten ueberschreiten")
    }

    // MARK: - Correct Values Tests

    /// Verhalten: Warning-Struct enthaelt korrekte Werte.
    /// Bricht wenn: Felder in LimitationWarning falsch befuellt werden.
    func test_warningContainsCorrectValues() {
        let profile = makeProfile(avgTasks: 3.0, avgMinutes: 90.0)
        let tasks = makeTasks(count: 6, duration: 30) // 6 > 4.5 (1.5x von 3), 180 > 135 (1.5x von 90)

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.plannedTasks, 6)
        XCTAssertEqual(result?.plannedMinutes, 180)
        XCTAssertEqual(result?.avgTasks, 3.0)
        XCTAssertEqual(result?.avgMinutes, 90.0)
    }

    // MARK: - Empty List Test

    /// Verhalten: Leere Task-Liste loest nie Warnung aus.
    /// Bricht wenn: evaluate() bei leerer Liste nicht nil zurueckgibt.
    func test_noWarning_whenTaskListEmpty() {
        let profile = makeProfile(avgTasks: 1.0, avgMinutes: 30.0)
        let tasks: [PlanItem] = []

        let result = LimitationGuardService.evaluate(tasks: tasks, profile: profile)

        XCTAssertNil(result, "Leere Task-Liste soll nie warnen")
    }
}
