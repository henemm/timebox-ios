import XCTest
import SwiftData
@testable import FocusBlox

final class BehavioralProfileServiceTests: XCTestCase {

    // MARK: - Helpers

    private let calendar = Calendar.current

    /// Erstellt einen completed Task mit definierter completedAt-Uhrzeit und Kategorie.
    private func makeTask(
        title: String = "Test",
        category: String = "income",
        completedHour: Int,
        completedMinute: Int = 0,
        daysAgo: Int = 1,
        estimatedDuration: Int? = nil,
        now: Date = Date()
    ) -> LocalTask {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let completedAt = calendar.date(bySettingHour: completedHour, minute: completedMinute, second: 0, of: day)!

        let task = LocalTask(title: title, estimatedDuration: estimatedDuration, taskType: category)
        task.isCompleted = true
        task.completedAt = completedAt
        return task
    }

    /// Erstellt einen FocusBlock mit taskTimes fuer einen Task.
    private func makeBlock(taskID: String, seconds: Int) -> FocusBlock {
        FocusBlock(
            id: UUID().uuidString,
            title: "Block",
            startDate: Date(),
            endDate: Date(),
            taskIDs: [taskID],
            completedTaskIDs: [],
            taskTimes: [taskID: seconds]
        )
    }

    // MARK: - Komponente 1: Tageszeit-Affinitaet

    /// Verhalten: 10 Income-Tasks alle zwischen 08:00-09:00 → income.morning = 1.0
    /// Bricht wenn: dayPeriod() 08:00 nicht als .morning erkennt, oder Anteils-Division falsch.
    func test_timeAffinity_allMorningTasks_morningIs1() {
        let now = Date()
        let tasks = (0..<10).map { i in
            makeTask(category: "income", completedHour: 8, daysAgo: i + 1, now: now)
        }

        let result = BehavioralProfileService.computeTimeAffinity(from: tasks)

        XCTAssertNotNil(result, "Sollte ein Ergebnis liefern bei 10 Tasks")
        guard let income = result?[.income] else { return XCTFail("income fehlt im Ergebnis") }
        XCTAssertEqual(income[.morning] ?? -1, 1.0, accuracy: 0.001, "Alle Tasks morgens → morning = 1.0")
        XCTAssertEqual(income[.afternoon] ?? -1, 0.0, accuracy: 0.001, "Keine Tasks nachmittags → afternoon = 0.0")
        XCTAssertEqual(income[.evening] ?? -1, 0.0, accuracy: 0.001, "Keine Tasks abends → evening = 0.0")
    }

    /// Verhalten: 5 Tasks morning + 5 Tasks afternoon → morning = 0.5, afternoon = 0.5
    /// Bricht wenn: Anteile nicht korrekt auf 1.0 normalisiert werden.
    func test_timeAffinity_evenSplit_correctProportions() {
        let now = Date()
        var tasks: [LocalTask] = []
        for i in 0..<5 {
            tasks.append(makeTask(category: "income", completedHour: 9, daysAgo: i + 1, now: now))
        }
        for i in 0..<5 {
            tasks.append(makeTask(category: "income", completedHour: 14, daysAgo: i + 1, now: now))
        }

        let result = BehavioralProfileService.computeTimeAffinity(from: tasks)

        XCTAssertNotNil(result)
        guard let income = result?[.income] else { return XCTFail("income fehlt im Ergebnis") }
        XCTAssertEqual(income[.morning] ?? -1, 0.5, accuracy: 0.001, "50% morgens")
        XCTAssertEqual(income[.afternoon] ?? -1, 0.5, accuracy: 0.001, "50% nachmittags")
    }

    /// Verhalten: 9 Tasks (unter Schwelle 10) → nil
    /// Bricht wenn: Service trotzdem ein Ergebnis liefert statt nil.
    func test_timeAffinity_belowThreshold_returnsNil() {
        let now = Date()
        let tasks = (0..<9).map { i in
            makeTask(category: "income", completedHour: 8, daysAgo: i + 1, now: now)
        }

        let result = BehavioralProfileService.computeTimeAffinity(from: tasks)

        XCTAssertNil(result, "Unter Schwelle 10 → nil")
    }

    /// Verhalten: Grenzen der Tageszeit-Fenster: 05:59=evening, 06:00=morning, 11:59=morning,
    ///   12:00=afternoon, 17:59=afternoon, 18:00=evening
    /// Bricht wenn: Off-by-one in dayPeriod().
    func test_dayPeriod_boundaryHours_correct() {
        let base = calendar.startOfDay(for: Date())

        let at0559 = calendar.date(bySettingHour: 5, minute: 59, second: 0, of: base)!
        XCTAssertEqual(BehavioralProfileService.dayPeriod(for: at0559), .evening, "05:59 = evening")

        let at0600 = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: base)!
        XCTAssertEqual(BehavioralProfileService.dayPeriod(for: at0600), .morning, "06:00 = morning")

        let at1159 = calendar.date(bySettingHour: 11, minute: 59, second: 0, of: base)!
        XCTAssertEqual(BehavioralProfileService.dayPeriod(for: at1159), .morning, "11:59 = morning")

        let at1200 = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: base)!
        XCTAssertEqual(BehavioralProfileService.dayPeriod(for: at1200), .afternoon, "12:00 = afternoon")

        let at1759 = calendar.date(bySettingHour: 17, minute: 59, second: 0, of: base)!
        XCTAssertEqual(BehavioralProfileService.dayPeriod(for: at1759), .afternoon, "17:59 = afternoon")

        let at1800 = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: base)!
        XCTAssertEqual(BehavioralProfileService.dayPeriod(for: at1800), .evening, "18:00 = evening")
    }

    /// Verhalten: Tasks ohne Kategorie (taskType = "") werden ignoriert, zaehlen nicht zur Schwelle.
    /// Bricht wenn: Uncategorized Tasks die Affinitaets-Berechnung verfaelschen.
    func test_timeAffinity_uncategorizedTasksIgnored() {
        let now = Date()
        // 9 kategorisierte + 5 unkategorisierte = 14 total, aber nur 9 zaehlen → nil
        var tasks: [LocalTask] = (0..<9).map { i in
            makeTask(category: "income", completedHour: 8, daysAgo: i + 1, now: now)
        }
        for i in 0..<5 {
            tasks.append(makeTask(category: "", completedHour: 8, daysAgo: i + 1, now: now))
        }

        let result = BehavioralProfileService.computeTimeAffinity(from: tasks)

        XCTAssertNil(result, "Unkategorisierte Tasks zaehlen nicht zur Schwelle")
    }

    // MARK: - Komponente 2: Taegliche Kapazitaet

    /// Verhalten: 3+5+4+2+6 Tasks an 5 Tagen → avgTasksPerDay = 4.0
    /// Bricht wenn: Durchschnitt falsch berechnet oder Divisor != Anzahl aktiver Tage.
    func test_avgTasksPerDay_fiveDays_correctAverage() {
        let now = Date()
        let counts = [3, 5, 4, 2, 6]
        var tasks: [LocalTask] = []
        for (dayIndex, count) in counts.enumerated() {
            for _ in 0..<count {
                tasks.append(makeTask(completedHour: 10, daysAgo: dayIndex + 1, now: now))
            }
        }

        let result = BehavioralProfileService.computeAvgTasksPerDay(from: tasks)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 4.0, accuracy: 0.001, "20 Tasks / 5 Tage = 4.0")
    }

    /// Verhalten: 4 aktive Tage (unter Schwelle 5) → nil
    /// Bricht wenn: Service trotzdem einen Wert liefert.
    func test_avgTasksPerDay_belowThreshold_returnsNil() {
        let now = Date()
        var tasks: [LocalTask] = []
        for day in 0..<4 {
            tasks.append(makeTask(completedHour: 10, daysAgo: day + 1, now: now))
        }

        let result = BehavioralProfileService.computeAvgTasksPerDay(from: tasks)

        XCTAssertNil(result, "Unter Schwelle 5 aktive Tage → nil")
    }

    /// Verhalten: 28-Tage-Fenster, Tasks nur an 7 Tagen → Divisor = 7, nicht 28.
    /// Bricht wenn: Alle Tage im Fenster als Divisor verwendet werden.
    func test_avgTasksPerDay_onlyActiveDaysCount() {
        let now = Date()
        var tasks: [LocalTask] = []
        // 2 Tasks an jedem der 7 Tage (Tag 1,5,10,15,20,25,28)
        for day in [1, 5, 10, 15, 20, 25, 28] {
            tasks.append(makeTask(completedHour: 10, daysAgo: day, now: now))
            tasks.append(makeTask(completedHour: 14, daysAgo: day, now: now))
        }

        let result = BehavioralProfileService.computeAvgTasksPerDay(from: tasks)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 2.0, accuracy: 0.001, "14 Tasks / 7 aktive Tage = 2.0")
    }

    /// Verhalten: FocusBlock mit 3600s + 1800s fuer 2 Tasks an Tag 1 → avgMinutes fuer Tag = 90min.
    /// Bei 5 Tagen mit gleichen Werten → avgMinutesPerDay = 90.0
    /// Bricht wenn: Sekunden-zu-Minuten-Umrechnung falsch oder Task-Tag-Zuordnung fehlerhaft.
    func test_avgMinutesPerDay_correctConversion() {
        let now = Date()
        var tasks: [LocalTask] = []
        var blocks: [FocusBlock] = []

        for day in 0..<5 {
            let taskA = makeTask(title: "A-\(day)", completedHour: 10, daysAgo: day + 1, now: now)
            let taskB = makeTask(title: "B-\(day)", completedHour: 14, daysAgo: day + 1, now: now)
            tasks.append(contentsOf: [taskA, taskB])
            blocks.append(makeBlock(taskID: taskA.id, seconds: 3600))  // 60 min
            blocks.append(makeBlock(taskID: taskB.id, seconds: 1800))  // 30 min
        }

        let result = BehavioralProfileService.computeAvgMinutesPerDay(from: tasks, focusBlocks: blocks)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 90.0, accuracy: 0.001, "5400s pro Tag / 60 = 90 Minuten")
    }

    // MARK: - Komponente 3: Schaetz-Genauigkeit

    /// Verhalten: 10 Tasks je 60min geschaetzt, je 90min tatsaechlich (5400s) → factor = 1.5
    /// Bricht wenn: Faktor-Berechnung oder Einheiten-Umrechnung (Min→Sek) fehlerhaft.
    func test_estimationFactor_50percentOver_returns1point5() {
        let now = Date()
        var tasks: [LocalTask] = []
        var blocks: [FocusBlock] = []

        for i in 0..<10 {
            let task = makeTask(completedHour: 10, daysAgo: i + 1, estimatedDuration: 60, now: now)
            tasks.append(task)
            blocks.append(makeBlock(taskID: task.id, seconds: 5400)) // 90 min = 5400s
        }

        let result = BehavioralProfileService.computeEstimationFactor(from: tasks, focusBlocks: blocks)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1.5, accuracy: 0.001, "90min actual / 60min estimated = 1.5")
    }

    /// Verhalten: 10 Tasks perfekt geschaetzt → factor = 1.0
    /// Bricht wenn: Perfekte Schaetzung nicht als 1.0 zurueckgegeben wird.
    func test_estimationFactor_perfectEstimation_returns1point0() {
        let now = Date()
        var tasks: [LocalTask] = []
        var blocks: [FocusBlock] = []

        for i in 0..<10 {
            let task = makeTask(completedHour: 10, daysAgo: i + 1, estimatedDuration: 30, now: now)
            tasks.append(task)
            blocks.append(makeBlock(taskID: task.id, seconds: 1800)) // 30 min = 1800s
        }

        let result = BehavioralProfileService.computeEstimationFactor(from: tasks, focusBlocks: blocks)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1.0, accuracy: 0.001, "Perfekte Schaetzung = 1.0")
    }

    /// Verhalten: 9 Tasks mit beiden Werten (unter Schwelle 10) → nil
    /// Bricht wenn: Service trotzdem einen Wert liefert.
    func test_estimationFactor_belowThreshold_returnsNil() {
        let now = Date()
        var tasks: [LocalTask] = []
        var blocks: [FocusBlock] = []

        for i in 0..<9 {
            let task = makeTask(completedHour: 10, daysAgo: i + 1, estimatedDuration: 60, now: now)
            tasks.append(task)
            blocks.append(makeBlock(taskID: task.id, seconds: 3600))
        }

        let result = BehavioralProfileService.computeEstimationFactor(from: tasks, focusBlocks: blocks)

        XCTAssertNil(result, "Unter Schwelle 10 → nil")
    }

    /// Verhalten: Task in 2 FocusBlocks → taskTimes werden summiert (1800s + 900s = 2700s = 45min)
    /// Bei 60min geschaetzt → factor = 0.75
    /// Bricht wenn: Nur der erste/letzte Block-Eintrag verwendet wird statt Summe.
    func test_estimationFactor_taskInMultipleBlocks_timeSummed() {
        let now = Date()
        var tasks: [LocalTask] = []
        var blocks: [FocusBlock] = []

        // 10 Tasks, jeder in 2 Bloecken
        for i in 0..<10 {
            let task = makeTask(completedHour: 10, daysAgo: i + 1, estimatedDuration: 60, now: now)
            tasks.append(task)
            blocks.append(makeBlock(taskID: task.id, seconds: 1800)) // 30 min
            blocks.append(makeBlock(taskID: task.id, seconds: 900))  // 15 min
        }

        let result = BehavioralProfileService.computeEstimationFactor(from: tasks, focusBlocks: blocks)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.75, accuracy: 0.001, "45min actual / 60min estimated = 0.75")
    }

    // MARK: - 28-Tage-Fenster

    /// Verhalten: Task von vor 29 Tagen wird nicht gezaehlt.
    /// Bricht wenn: Rolling Window groesser als 28 Tage ist.
    func test_rollingWindow_taskOutsideWindow_excluded() {
        let now = Date()
        // 4 Tasks innerhalb + 1 Task ausserhalb des Fensters = 4 aktive Tage → unter Schwelle
        var tasks: [LocalTask] = []
        for day in [1, 2, 3, 4] {
            tasks.append(makeTask(completedHour: 10, daysAgo: day, now: now))
        }
        tasks.append(makeTask(completedHour: 10, daysAgo: 29, now: now))

        let result = BehavioralProfileService.compute(tasks: tasks, focusBlocks: [], now: now)

        XCTAssertNil(result.avgTasksPerDay, "Task von vor 29 Tagen zaehlt nicht → nur 4 Tage → nil")
    }

    /// Verhalten: Task von vor genau 28 Tagen (inklusive) wird gezaehlt.
    /// Bricht wenn: Grenztag des Fensters falsch behandelt wird (exclusive statt inclusive).
    func test_rollingWindow_taskAtWindowBoundary_included() {
        let now = Date()
        var tasks: [LocalTask] = []
        for day in [1, 2, 3, 4, 28] {
            tasks.append(makeTask(completedHour: 10, daysAgo: day, now: now))
        }

        let result = BehavioralProfileService.compute(tasks: tasks, focusBlocks: [], now: now)

        XCTAssertNotNil(result.avgTasksPerDay, "Task von vor 28 Tagen zaehlt → 5 Tage → nicht nil")
    }

    // MARK: - Cache

    /// Verhalten: Zweiter Aufruf am selben Tag liefert gecachtes Ergebnis (identisches Profil).
    /// Bricht wenn: Cache nicht gesetzt wird oder Calendar-Vergleich in profile() falsch ist.
    func test_cache_sameDay_returnsCached() {
        BehavioralProfileService.invalidateCache()

        let now = Date()
        let tasks = (0..<10).map { i in
            makeTask(category: "income", completedHour: 10, daysAgo: i + 1, now: now)
        }

        let first = BehavioralProfileService.profile(tasks: tasks, focusBlocks: [], now: now)
        // Zweiter Aufruf mit leerem Array — wenn Cache funktioniert, kommt trotzdem das erste Ergebnis
        let second = BehavioralProfileService.profile(tasks: [], focusBlocks: [], now: now)

        XCTAssertEqual(
            first.computedAt, second.computedAt,
            "Zweiter Aufruf am selben Tag sollte gecachtes Profil liefern"
        )
        XCTAssertNotNil(second.categoryTimeAffinity,
            "Gecachtes Profil hat Affinitaet vom ersten Aufruf (nicht nil wie bei leerem Input)")
    }

    /// Verhalten: Aufruf an anderem Kalendertag → Cache invalidiert, Neuberechnung.
    /// Bricht wenn: Calendar.startOfDay-Vergleich in profile() falsch ist.
    func test_cache_differentDay_recomputesProfile() {
        BehavioralProfileService.invalidateCache()

        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let tasks = (0..<10).map { i in
            makeTask(category: "income", completedHour: 10, daysAgo: i + 1, now: now)
        }

        // Cache von gestern
        let _ = BehavioralProfileService.profile(tasks: tasks, focusBlocks: [], now: yesterday)
        // Aufruf von heute mit leeren Tasks → muss neu berechnen
        let todayResult = BehavioralProfileService.profile(tasks: [], focusBlocks: [], now: now)

        XCTAssertNil(todayResult.categoryTimeAffinity,
            "Neuer Tag → Neuberechnung mit leeren Tasks → nil Affinitaet")
    }

    /// Verhalten: invalidateCache() → naechster profile()-Aufruf berechnet neu.
    /// Bricht wenn: invalidateCache() den Cache nicht tatsaechlich loescht.
    func test_invalidateCache_forcesRecompute() {
        let now = Date()
        let tasks = (0..<10).map { i in
            makeTask(category: "income", completedHour: 10, daysAgo: i + 1, now: now)
        }

        // Cache fuellen
        let _ = BehavioralProfileService.profile(tasks: tasks, focusBlocks: [], now: now)
        // Cache loeschen
        BehavioralProfileService.invalidateCache()
        // Neuer Aufruf mit leeren Tasks → muss neu berechnen (nicht Cache)
        let afterInvalidate = BehavioralProfileService.profile(tasks: [], focusBlocks: [], now: now)

        XCTAssertNil(afterInvalidate.categoryTimeAffinity,
            "Nach invalidateCache() → Neuberechnung mit leeren Tasks → nil")
    }

    // MARK: - Edge Cases

    /// Verhalten: Tasks ohne FocusBlock-Eintrag tragen 0 Minuten bei (kein Crash).
    /// Bricht wenn: Fehlende taskTimes-Eintraege zu Crash oder falschem Ergebnis fuehren.
    func test_avgMinutesPerDay_taskWithoutFocusBlock_contributesZero() {
        let now = Date()
        var tasks: [LocalTask] = []
        for day in 0..<5 {
            tasks.append(makeTask(completedHour: 10, daysAgo: day + 1, now: now))
        }
        // Keine FocusBlocks → keine Tage mit Sekunden → unter Schwelle → nil
        let result = BehavioralProfileService.computeAvgMinutesPerDay(from: tasks, focusBlocks: [])

        XCTAssertNil(result, "Ohne FocusBlocks gibt es keine Tage mit Arbeitszeit → nil")
    }

    /// Verhalten: Tasks ohne estimatedDuration werden bei estimationFactor ignoriert.
    /// Bricht wenn: Tasks ohne Schaetzung den Faktor verfaelschen oder Crash verursachen.
    func test_estimationFactor_tasksWithoutEstimate_excluded() {
        let now = Date()
        var tasks: [LocalTask] = []
        var blocks: [FocusBlock] = []

        // 10 Tasks MIT Schaetzung (60min geschaetzt, 90min tatsaechlich → 1.5)
        for i in 0..<10 {
            let task = makeTask(completedHour: 10, daysAgo: i + 1, estimatedDuration: 60, now: now)
            tasks.append(task)
            blocks.append(makeBlock(taskID: task.id, seconds: 5400))
        }
        // 5 Tasks OHNE Schaetzung (sollen ignoriert werden)
        for i in 0..<5 {
            let task = makeTask(completedHour: 14, daysAgo: i + 1, now: now)
            tasks.append(task)
            blocks.append(makeBlock(taskID: task.id, seconds: 3600))
        }

        let result = BehavioralProfileService.computeEstimationFactor(from: tasks, focusBlocks: blocks)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1.5, accuracy: 0.001,
            "Nur die 10 Tasks mit Schaetzung zaehlen → 1.5, Tasks ohne Schaetzung ignoriert")
    }
}
