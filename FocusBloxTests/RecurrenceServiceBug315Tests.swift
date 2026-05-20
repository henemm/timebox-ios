import XCTest
import SwiftData
@testable import FocusBlox

/// TDD-RED Tests für Bug #315 — Wiederkehrende Tasks sterben nach dem Abhaken (3. Auftreten).
///
/// Drei Root Causes:
///   RC-1: createNextInstance bricht bei dueDate==nil still ab (kein Fallback auf Date())
///   RC-2: repairOrphanedRecurringSeries überspringt Serien ohne Template
///   RC-3: Regression durch Commit 15aec1dc — Fallback-Loop entfernt
///
/// Alle Tests prüfen das GEWÜNSCHTE Verhalten nach dem Fix.
/// AC-1, AC-3, AC-5 schlagen RED bis der Fix implementiert ist.
@MainActor
final class RecurrenceServiceBug315Tests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: LocalTask.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Helpers

    private func makeCompletedTask(
        title: String = "Tägliche Aufgabe",
        pattern: String = "daily",
        dueDate: Date?,
        groupID: String
    ) -> LocalTask {
        let task = LocalTask(title: title, recurrencePattern: pattern, recurrenceGroupID: groupID)
        task.dueDate = dueDate
        task.isCompleted = true
        task.completedAt = Date()
        context.insert(task)
        return task
    }

    private func makeTemplate(
        title: String = "Tägliche Aufgabe",
        pattern: String = "daily",
        groupID: String
    ) -> LocalTask {
        let template = LocalTask(title: title, recurrencePattern: pattern, recurrenceGroupID: groupID)
        template.isTemplate = true
        context.insert(template)
        return template
    }

    private func openInstances(groupID: String) throws -> [LocalTask] {
        let descriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> {
                $0.recurrenceGroupID == groupID && !$0.isCompleted && !$0.isTemplate
            }
        )
        return try context.fetch(descriptor)
    }

    // MARK: - AC-1: Task OHNE dueDate abhaken → neue Instanz mit Datum ab heute

    /// Verhalten: Wenn ein recurring Task kein dueDate hat und abgehakt wird,
    ///            muss ensureNextInstance eine neue Instanz mit dueDate = nächster Zyklus ab heute erzeugen.
    /// Bricht wenn: ensureNextInstance nicht existiert ODER dueDate-nil-Fallback auf Date() entfernt wird.
    func test_AC1_ensureNextInstance_withNilDueDate_createsInstanceFromToday() throws {
        let groupID = UUID().uuidString
        let task = makeCompletedTask(dueDate: nil, groupID: groupID)
        _ = makeTemplate(groupID: groupID)
        try context.save()

        let instance = try XCTUnwrap(
            RecurrenceService.ensureNextInstance(for: task, in: context),
            "AC-1: ensureNextInstance muss eine Instanz zurückgeben, auch wenn dueDate nil ist"
        )

        let instanceDueDate = try XCTUnwrap(
            instance.dueDate,
            "AC-1: Die neue Instanz muss ein dueDate haben (nächster Zyklus ab heute)"
        )

        // Datum muss in der Zukunft liegen (ab morgen, da "daily" +1 Tag ab today)
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        XCTAssertGreaterThanOrEqual(
            Calendar.current.startOfDay(for: instanceDueDate),
            tomorrow,
            "AC-1: dueDate der neuen Instanz muss >= morgen sein (nächster Zyklus ab heute)"
        )
    }

    /// Verhalten: Die neue Instanz gehört zur selben Serie (gleiche groupID).
    /// Bricht wenn: ensureNextInstance die groupID nicht korrekt überträgt.
    func test_AC1_ensureNextInstance_withNilDueDate_copiesGroupID() throws {
        let groupID = UUID().uuidString
        let task = makeCompletedTask(dueDate: nil, groupID: groupID)
        _ = makeTemplate(groupID: groupID)
        try context.save()

        let instance = try XCTUnwrap(
            RecurrenceService.ensureNextInstance(for: task, in: context),
            "AC-1: ensureNextInstance muss eine Instanz zurückgeben"
        )

        XCTAssertEqual(
            instance.recurrenceGroupID,
            groupID,
            "AC-1: Neue Instanz muss die groupID der abgehakten Aufgabe erben"
        )
    }

    // MARK: - AC-2: Task MIT dueDate abhaken → korrekt berechnetes nächstes Datum

    /// Verhalten: Wenn ein recurring Task mit gesetztem dueDate abgehakt wird,
    ///            erzeugt ensureNextInstance die nächste Instanz mit korrekt berechnetem Datum.
    /// Bricht wenn: ensureNextInstance nicht das richtige Datum berechnet.
    func test_AC2_ensureNextInstance_withDueDate_createsInstanceWithNextDate() throws {
        let groupID = UUID().uuidString
        let baseDate = makeDate(2026, 5, 20) // Mittwoch
        let task = makeCompletedTask(dueDate: baseDate, groupID: groupID)
        _ = makeTemplate(groupID: groupID)
        try context.save()

        let instance = try XCTUnwrap(
            RecurrenceService.ensureNextInstance(for: task, in: context),
            "AC-2: ensureNextInstance muss eine Instanz für Task mit dueDate erzeugen"
        )

        let instanceDueDate = try XCTUnwrap(
            instance.dueDate,
            "AC-2: Neue Instanz muss ein dueDate haben"
        )

        // daily pattern: baseDate + 1 Tag = 2026-05-21
        XCTAssertEqual(
            Calendar.current.component(.day, from: instanceDueDate),
            21,
            "AC-2: Daily pattern muss baseDate + 1 Tag ergeben"
        )
        XCTAssertEqual(
            Calendar.current.component(.month, from: instanceDueDate),
            5,
            "AC-2: Monat muss gleich bleiben"
        )
    }

    /// Verhalten: Weekly pattern mit gesetztem dueDate berechnet 7 Tage weiter.
    /// Bricht wenn: ensureNextInstance das pattern nicht korrekt auswertet.
    func test_AC2_ensureNextInstance_weeklyPattern_calculatesNextWeek() throws {
        let groupID = UUID().uuidString
        let baseDate = makeDate(2026, 5, 20) // Mittwoch
        let task = makeCompletedTask(pattern: "weekly", dueDate: baseDate, groupID: groupID)
        _ = makeTemplate(title: "Tägliche Aufgabe", pattern: "weekly", groupID: groupID)
        try context.save()

        let instance = try XCTUnwrap(
            RecurrenceService.ensureNextInstance(for: task, in: context),
            "AC-2: ensureNextInstance muss Instanz für weekly Task erzeugen"
        )

        let instanceDueDate = try XCTUnwrap(instance.dueDate)
        // weekly ohne weekdays: +7 Tage = 2026-05-27
        XCTAssertEqual(
            Calendar.current.component(.day, from: instanceDueDate),
            27,
            "AC-2: Weekly pattern muss baseDate + 7 Tage ergeben"
        )
    }

    // MARK: - AC-3: repairOrphanedRecurringSeries mit fehlendem Template → lazy erstellen + Instanz

    /// Verhalten: Wenn eine Serie kein Template hat (Datenfehler, kein User-Intent),
    ///            muss repairOrphanedRecurringSeries ein lazy Template erstellen und eine neue Instanz erzeugen.
    /// Bricht wenn: Guard auf findTemplate noch aktiv ist (aktueller Bug — Zeile 465 in RecurrenceService.swift).
    func test_AC3_repairOrphaned_withNoTemplate_createsLazyTemplateAndInstance() throws {
        let groupID = UUID().uuidString

        // Completed recurring task OHNE Template (kein isTemplate=true für diese Serie)
        let completed = makeCompletedTask(
            dueDate: Calendar.current.startOfDay(for: Date()),
            groupID: groupID
        )
        // KEIN Template wird eingefügt — das ist der Bug-Zustand
        try context.save()

        // Precondition: kein Template vorhanden
        let templateBefore = RecurrenceService.findTemplate(groupID: groupID, in: context)
        XCTAssertNil(templateBefore, "Precondition: Es darf kein Template existieren")

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        XCTAssertGreaterThan(
            repaired,
            0,
            "AC-3: repairOrphanedRecurringSeries muss Serie ohne Template reparieren (lazy Template erstellen)"
        )

        let openAfter = try openInstances(groupID: groupID)
        XCTAssertEqual(
            openAfter.count,
            1,
            "AC-3: Nach Repair muss genau eine offene Instanz existieren"
        )

        _ = completed // suppress unused warning
    }

    /// Verhalten: Lazy erstelltes Template muss korrekte Attribute des completed Tasks übernehmen.
    /// Bricht wenn: lazyCreateTemplate Attribute nicht korrekt kopiert.
    func test_AC3_repairOrphaned_withNoTemplate_lazyTemplateHasCorrectAttributes() throws {
        let groupID = UUID().uuidString
        let completed = LocalTask(
            title: "Yoga",
            importance: 2,
            recurrencePattern: "weekly",
            recurrenceGroupID: groupID
        )
        completed.isCompleted = true
        completed.completedAt = Date()
        completed.dueDate = Calendar.current.startOfDay(for: Date())
        completed.urgency = "not_urgent"
        context.insert(completed)
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)
        XCTAssertGreaterThan(repaired, 0, "AC-3: Repair muss erfolgen")

        let createdTemplate = try XCTUnwrap(
            RecurrenceService.findTemplate(groupID: groupID, in: context),
            "AC-3: Lazy Template muss nach Repair existieren"
        )

        XCTAssertEqual(createdTemplate.title, "Yoga", "AC-3: Template muss Titel übernehmen")
        XCTAssertEqual(createdTemplate.recurrencePattern, "weekly", "AC-3: Template muss Pattern übernehmen")
        XCTAssertTrue(createdTemplate.isTemplate, "AC-3: Template muss isTemplate=true haben")
        XCTAssertEqual(createdTemplate.recurrenceGroupID, groupID, "AC-3: Template muss groupID übernehmen")
    }

    // MARK: - AC-4: Absichtlich beendete Serie wird NICHT repariert

    /// Verhalten: Eine Serie mit recurrencePattern=="none" auf abgeschlossenen Tasks wird als
    ///            absichtlich beendet erkannt und nicht repariert.
    /// Bricht wenn: ensureNextInstance / repairOrphanedRecurringSeries den "none"-Check entfernt.
    func test_AC4_intentionallyEndedSeries_noSuccessorCreated() throws {
        let groupID = UUID().uuidString

        // Completed Task MIT pattern="none" (deleteRecurringTemplate setzt dieses Signal)
        let completed = LocalTask(
            title: "Beendete Aufgabe",
            recurrencePattern: "none",
            recurrenceGroupID: groupID
        )
        completed.isCompleted = true
        completed.completedAt = Date()
        completed.dueDate = Calendar.current.startOfDay(for: Date())
        context.insert(completed)
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        XCTAssertEqual(
            repaired,
            0,
            "AC-4: Serie mit recurrencePattern=='none' darf NICHT repariert werden"
        )

        let openAfter = try openInstances(groupID: groupID)
        XCTAssertEqual(
            openAfter.count,
            0,
            "AC-4: Kein Nachfolger darf für beendete Serie erscheinen"
        )
    }

    /// Verhalten: ensureNextInstance gibt nil zurück wenn pattern=="none".
    /// Bricht wenn: Guard auf recurrencePattern entfernt wird.
    func test_AC4_ensureNextInstance_withNonePattern_returnsNil() throws {
        let groupID = UUID().uuidString
        let task = makeCompletedTask(pattern: "none", dueDate: Date(), groupID: groupID)
        try context.save()

        let instance = RecurrenceService.ensureNextInstance(for: task, in: context)

        XCTAssertNil(
            instance,
            "AC-4: ensureNextInstance muss nil zurückgeben wenn pattern=='none'"
        )
    }

    // MARK: - AC-5: Regressions-Test — ensureNextInstance mit dueDate=nil gibt Instanz zurück

    /// Verhalten: Nach dem Fix muss ensureNextInstance bei dueDate==nil eine Instanz zurückgeben
    ///            (Fallback auf Date()). Dieser Test ist der Regressions-Schutz:
    ///            Er wird RED wenn jemand den Date()-Fallback in ensureNextInstance entfernt.
    /// Bricht wenn: ensureNextInstance den dueDate==nil-Fallback nicht implementiert.
    ///
    /// HINWEIS: Der bestehende Test `test_createNextInstance_returnsNil_whenNoDueDate` in
    ///          RecurrenceServiceTests.swift testet das alte Verhalten von createNextInstance.
    ///          Dieser Test testet das NEUE Verhalten über die neue ensureNextInstance Funktion.
    func test_AC5_ensureNextInstance_nilDueDate_returnsInstance() throws {
        let groupID = UUID().uuidString
        let task = LocalTask(
            title: "Kein Datum Task",
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        // dueDate absichtlich nil — das ist RC-1
        XCTAssertNil(task.dueDate, "Precondition: dueDate muss nil sein")
        task.isCompleted = true
        task.completedAt = Date()
        context.insert(task)
        _ = makeTemplate(title: "Kein Datum Task", groupID: groupID)
        try context.save()

        let instance = RecurrenceService.ensureNextInstance(for: task, in: context)

        XCTAssertNotNil(
            instance,
            "AC-5 (Regressions-Test): ensureNextInstance darf bei dueDate==nil NICHT nil zurückgeben. " +
            "Fix: Fallback auf Date() wenn dueDate==nil (RC-1). " +
            "Dieser Test ist RED bis ensureNextInstance implementiert ist."
        )

        // Sicherstellung: dueDate ist tatsächlich gesetzt (nicht nil)
        let newDueDate = try XCTUnwrap(
            instance?.dueDate,
            "AC-5: Die erzeugte Instanz muss ein dueDate haben (Fallback ab heute)"
        )

        // Datum muss in der Zukunft liegen (ab morgen)
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        XCTAssertGreaterThanOrEqual(
            Calendar.current.startOfDay(for: newDueDate),
            tomorrow,
            "AC-5: Neue Instanz muss dueDate >= morgen haben (nächster Zyklus ab heute)"
        )
    }

    /// Verhalten: ensureNextInstance verwendet Date() als Fallback wenn dueDate==nil —
    ///            das Datum ist konsistent mit nextDueDate(from: Date()).
    /// Bricht wenn: Fallback-Datum nicht konsistent mit nextDueDate(from: Date()) ist.
    func test_AC5_ensureNextInstance_nilDueDate_basedOnTodayFallback() throws {
        let groupID = UUID().uuidString
        let task = LocalTask(
            title: "Fallback-Datum Test",
            recurrencePattern: "daily",
            recurrenceGroupID: groupID
        )
        task.isCompleted = true
        task.completedAt = Date()
        // dueDate bewusst nil
        context.insert(task)
        _ = makeTemplate(title: "Fallback-Datum Test", groupID: groupID)
        try context.save()

        let instance = try XCTUnwrap(
            RecurrenceService.ensureNextInstance(for: task, in: context),
            "AC-5: ensureNextInstance muss Instanz zurückgeben trotz nil dueDate"
        )

        let instanceDueDate = try XCTUnwrap(
            instance.dueDate,
            "AC-5: Instanz muss dueDate haben"
        )

        // Das erwartete Datum: daily ab today = morgen
        let expectedBase = Date()
        let expectedNext = try XCTUnwrap(
            RecurrenceService.nextDueDate(pattern: "daily", weekdays: nil, monthDay: nil, from: expectedBase),
            "nextDueDate darf nicht nil sein"
        )

        // Toleranz: gleicher Kalendertag (Date()-Aufrufe können minimal abweichen)
        let cal = Calendar.current
        XCTAssertEqual(
            cal.startOfDay(for: instanceDueDate),
            cal.startOfDay(for: expectedNext),
            "AC-5: Fallback-Datum muss nextDueDate(from: Date()) entsprechen"
        )
    }

    // MARK: - AC-6: Legacy-Tasks ohne recurrenceGroupID erzeugen KEINE Duplikate

    /// Verhalten: repairOrphanedRecurringSeries darf für Tasks ohne recurrenceGroupID
    ///            KEINE neuen Instanzen erstellen — sonst entstehen N Duplikate
    ///            (Bug: 10× "Zehnagel" nach 10 abgeschlossenen legacy Tasks).
    ///
    /// Bricht wenn: `task.recurrenceGroupID ?? task.id` statt `guard let groupID` verwendet wird.
    func test_AC6_repairOrphaned_legacyTasksWithoutGroupID_createNoDuplicates() throws {
        // 10 abgeschlossene Tasks OHNE recurrenceGroupID (Legacy-Daten)
        for i in 0..<10 {
            let task = LocalTask(title: "Zehnagel", recurrencePattern: "daily")
            task.recurrenceGroupID = nil
            task.isCompleted = true
            task.completedAt = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            context.insert(task)
        }
        try context.save()

        let repaired = RecurrenceService.repairOrphanedRecurringSeries(in: context)

        XCTAssertEqual(
            repaired,
            0,
            "AC-6: Legacy Tasks ohne recurrenceGroupID dürfen NICHT repariert werden — sonst entstehen Duplikate"
        )

        // Keine neuen offenen Instanzen entstanden
        let openDescriptor = FetchDescriptor<LocalTask>(
            predicate: #Predicate<LocalTask> { !$0.isCompleted && !$0.isTemplate }
        )
        let openTasks = try context.fetch(openDescriptor)
        XCTAssertEqual(
            openTasks.count,
            0,
            "AC-6: Kein offener Task darf durch Repair für Legacy-Daten entstanden sein"
        )
    }

    // MARK: - Hilfsmethoden

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 9
        return Calendar.current.date(from: components)!
    }
}
