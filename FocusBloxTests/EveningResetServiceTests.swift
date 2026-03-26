import XCTest
import SwiftData
@testable import FocusBlox

/// TDD RED Tests for EveningResetService (RW_4.1)
/// All tests MUST FAIL because EveningResetService does not exist yet.
@MainActor
final class EveningResetServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        // Reset lastResetDate so reset is eligible
        AppSettings.shared.lastResetDate = ""
    }

    override func tearDown() {
        // Clean up AppSettings state
        AppSettings.shared.lastResetDate = ""
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTask(
        title: String = "Test Task",
        isNextUp: Bool = false,
        isCompleted: Bool = false,
        scheduledDate: Date? = nil,
        rescheduleCount: Int = 0,
        assignedFocusBlockID: String? = nil
    ) -> LocalTask {
        let task = LocalTask(title: title, importance: 1)
        task.isNextUp = isNextUp
        task.isCompleted = isCompleted
        task.scheduledDate = scheduledDate
        task.rescheduleCount = rescheduleCount
        task.assignedFocusBlockID = assignedFocusBlockID
        task.nextUpSortOrder = isNextUp ? 1 : nil
        context.insert(task)
        try! context.save()
        return task
    }

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
    }

    private var todayAt14: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        return Calendar.current.date(from: components)!
    }

    // MARK: - Pass 1: Next-Up Clearing

    /// Verhalten: Reset setzt isNextUp=false, loescht nextUpSortOrder und assignedFocusBlockID
    /// Bricht wenn: EveningResetService.performResetIfNeeded() fehlt oder task.isNextUp=false Zeile fehlt
    func test_resetClearsNextUp() throws {
        let task = makeTask(isNextUp: true, assignedFocusBlockID: "block-123")

        let count = try EveningResetService.performResetIfNeeded(context: context)

        XCTAssertGreaterThan(count, 0, "Mindestens 1 Task sollte geaendert werden")
        XCTAssertFalse(task.isNextUp, "isNextUp sollte nach Reset false sein")
        XCTAssertNil(task.nextUpSortOrder, "nextUpSortOrder sollte nach Reset nil sein")
        XCTAssertNil(task.assignedFocusBlockID, "assignedFocusBlockID sollte nach Reset nil sein")
    }

    /// Verhalten: Reset erhoeht rescheduleCount um 1
    /// Bricht wenn: task.rescheduleCount += 1 Zeile fehlt
    func test_resetIncrementsRescheduleCount() throws {
        let task = makeTask(isNextUp: true, rescheduleCount: 3)

        try EveningResetService.performResetIfNeeded(context: context)

        XCTAssertEqual(task.rescheduleCount, 4, "rescheduleCount sollte von 3 auf 4 steigen")
    }

    // MARK: - Pass 2: Scheduled Date Clearing

    /// Verhalten: Reset loescht scheduledDate wenn es in der Vergangenheit liegt
    /// Bricht wenn: scheduledDate-nil-Setzung oder < startOfDay Filter fehlt
    func test_resetClearsExpiredScheduledDate() throws {
        let task = makeTask(scheduledDate: yesterday)
        task.scheduledDuration = 30
        try! context.save()

        try EveningResetService.performResetIfNeeded(context: context)

        XCTAssertNil(task.scheduledDate, "Vergangene scheduledDate sollte nil sein")
        XCTAssertNil(task.scheduledDuration, "scheduledDuration sollte mit scheduledDate gecleared werden")
    }

    /// Verhalten: Reset behaelt scheduledDate von heute bei
    /// Bricht wenn: Predicate-Filter < startOfDay fehlt (wuerde auch heutige Tasks loeschen)
    func test_resetPreservesTodayScheduledDate() throws {
        let task = makeTask(scheduledDate: todayAt14)
        let originalDate = task.scheduledDate

        try EveningResetService.performResetIfNeeded(context: context)

        XCTAssertEqual(task.scheduledDate, originalDate, "Heutige scheduledDate sollte erhalten bleiben")
    }

    // MARK: - Filtering

    /// Verhalten: Abgeschlossene Tasks werden NICHT zurueckgesetzt
    /// Bricht wenn: !isCompleted Filter in Predicate fehlt
    func test_resetSkipsCompletedTasks() throws {
        let task = makeTask(isNextUp: true, isCompleted: true)
        let originalRescheduleCount = task.rescheduleCount

        try EveningResetService.performResetIfNeeded(context: context)

        XCTAssertTrue(task.isNextUp, "Completed Task sollte isNextUp behalten")
        XCTAssertEqual(task.rescheduleCount, originalRescheduleCount, "Completed Task rescheduleCount unveraendert")
    }

    // MARK: - Idempotency

    /// Verhalten: Zweiter Aufruf am selben Tag aendert nichts
    /// Bricht wenn: lastResetDate Guard-Clause fehlt
    func test_resetIsIdempotent() throws {
        let task = makeTask(isNextUp: true)

        // Erster Aufruf: Reset passiert
        let firstCount = try EveningResetService.performResetIfNeeded(context: context)
        XCTAssertGreaterThan(firstCount, 0, "Erster Aufruf sollte Tasks aendern")

        // Zweiter Task einfuegen — wuerde ohne Idempotenz-Guard auch geresetet werden
        let task2 = makeTask(isNextUp: true)

        // Zweiter Aufruf: Nichts passiert
        let secondCount = try EveningResetService.performResetIfNeeded(context: context)
        XCTAssertEqual(secondCount, 0, "Zweiter Aufruf am selben Tag sollte 0 zurueckgeben")
        XCTAssertTrue(task2.isNextUp, "Task nach erstem Reset sollte von zweitem Aufruf nicht betroffen sein")
    }

    // MARK: - Side Effects

    /// Verhalten: modifiedAt wird auf allen geaenderten Tasks aktualisiert (CloudKit Sync)
    /// Bricht wenn: task.modifiedAt = now Zeile fehlt
    func test_resetUpdatesModifiedAt() throws {
        let task = makeTask(isNextUp: true)
        task.modifiedAt = nil
        try! context.save()

        let before = Date()
        try EveningResetService.performResetIfNeeded(context: context)

        XCTAssertNotNil(task.modifiedAt, "modifiedAt sollte nach Reset gesetzt sein")
        XCTAssertGreaterThanOrEqual(
            task.modifiedAt!.timeIntervalSince1970,
            before.timeIntervalSince1970 - 1,
            "modifiedAt sollte ungefaehr jetzt sein"
        )
    }

    /// Verhalten: lastResetDate wird auf heutiges ISO-Datum gesetzt
    /// Bricht wenn: settings.lastResetDate = today Zeile fehlt
    func test_resetUpdatesLastResetDate() throws {
        AppSettings.shared.lastResetDate = ""
        _ = makeTask(isNextUp: true)

        try EveningResetService.performResetIfNeeded(context: context)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = Calendar.current.timeZone
        let expectedToday = formatter.string(from: Calendar.current.startOfDay(for: Date()))

        XCTAssertEqual(
            AppSettings.shared.lastResetDate,
            expectedToday,
            "lastResetDate sollte heutiges ISO-Datum sein"
        )
    }
}
