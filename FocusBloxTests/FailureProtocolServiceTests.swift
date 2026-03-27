import XCTest
import SwiftData
@testable import FocusBlox

final class FailureProtocolServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([TaskFailureRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - save()

    /// Verhalten: save() erstellt genau einen TaskFailureRecord in der Datenbank
    /// Bricht wenn: FailureProtocolService.save() kein context.insert() ausfuehrt
    func test_save_createsOneRecord() throws {
        FailureProtocolService.save(
            taskID: "task-abc",
            reason: .noTime,
            context: context
        )

        let all = try context.fetch(FetchDescriptor<TaskFailureRecord>())
        XCTAssertEqual(all.count, 1, "save() sollte genau einen Record erstellen")
        XCTAssertEqual(all.first?.taskID, "task-abc")
        XCTAssertEqual(all.first?.reason, .noTime)
    }

    /// Verhalten: save() verhindert Duplikate — gleicher Task am gleichen Tag = kein zweiter Record
    /// Bricht wenn: Duplikat-Check (guard existing.isEmpty) in save() entfernt wird
    func test_save_preventsDuplicateSameDay() throws {
        let today = Date()

        FailureProtocolService.save(taskID: "task-abc", reason: .noTime, context: context, date: today)
        FailureProtocolService.save(taskID: "task-abc", reason: .tooTired, context: context, date: today)

        let all = try context.fetch(FetchDescriptor<TaskFailureRecord>())
        XCTAssertEqual(all.count, 1, "Gleicher Task am gleichen Tag darf nur einen Record haben")
        XCTAssertEqual(all.first?.reason, .noTime, "Erster Eintrag soll bestehen bleiben")
    }

    /// Verhalten: save() erlaubt Records fuer gleichen Task an verschiedenen Tagen
    /// Bricht wenn: Duplikat-Check nicht nach Datum filtert
    func test_save_allowsSameTaskDifferentDay() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        FailureProtocolService.save(taskID: "task-abc", reason: .noTime, context: context, date: today)
        FailureProtocolService.save(taskID: "task-abc", reason: .blocked, context: context, date: yesterday)

        let all = try context.fetch(FetchDescriptor<TaskFailureRecord>())
        XCTAssertEqual(all.count, 2, "Gleicher Task an verschiedenen Tagen = 2 Records erlaubt")
    }

    /// Verhalten: save() erlaubt verschiedene Tasks am gleichen Tag
    /// Bricht wenn: Duplikat-Check nur nach Datum filtert ohne taskID
    func test_save_allowsDifferentTasksSameDay() throws {
        let today = Date()

        FailureProtocolService.save(taskID: "task-abc", reason: .noTime, context: context, date: today)
        FailureProtocolService.save(taskID: "task-xyz", reason: .tooTired, context: context, date: today)

        let all = try context.fetch(FetchDescriptor<TaskFailureRecord>())
        XCTAssertEqual(all.count, 2, "Verschiedene Tasks am gleichen Tag = 2 Records erlaubt")
    }

    // MARK: - fetchForDate()

    /// Verhalten: fetchForDate() gibt nur Records des gewuenschten Tages zurueck
    /// Bricht wenn: Predicate in fetchForDate() falsch filtert (z.B. alle Records zurueckgibt)
    func test_fetchForDate_filtersCorrectly() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        FailureProtocolService.save(taskID: "task-today", reason: .noTime, context: context, date: today)
        FailureProtocolService.save(taskID: "task-yesterday", reason: .blocked, context: context, date: yesterday)

        let todayRecords = FailureProtocolService.fetchForDate(today, context: context)
        XCTAssertEqual(todayRecords.count, 1, "fetchForDate sollte nur Records von heute zurueckgeben")
        XCTAssertEqual(todayRecords.first?.taskID, "task-today")

        let yesterdayRecords = FailureProtocolService.fetchForDate(yesterday, context: context)
        XCTAssertEqual(yesterdayRecords.count, 1)
        XCTAssertEqual(yesterdayRecords.first?.taskID, "task-yesterday")
    }

    // MARK: - FailureReason enum

    /// Verhalten: FailureReason hat exakt 6 Cases wie in der Spec definiert
    /// Bricht wenn: Ein Case hinzugefuegt oder entfernt wird
    func test_failureReason_hasExactlySixCases() {
        XCTAssertEqual(FailureReason.allCases.count, 6,
            "FailureReason muss exakt 6 Cases haben: noTime, tooTired, blocked, notRelevant, forgotAboutIt, other")
    }

    /// Verhalten: FailureReason roundtrips korrekt ueber rawValue (CloudKit-Kompatibilitaet)
    /// Bricht wenn: rawValue-Encoding/Decoding in TaskFailureRecord.reasonRaw nicht funktioniert
    func test_failureReason_roundtripsViaRawValue() throws {
        for reason in FailureReason.allCases {
            FailureProtocolService.save(taskID: "task-\(reason.rawValue)", reason: reason, context: context)
        }

        let all = try context.fetch(FetchDescriptor<TaskFailureRecord>())
        let savedReasons = Set(all.map { $0.reason })
        let allReasons = Set(FailureReason.allCases)

        XCTAssertEqual(savedReasons, allReasons, "Alle FailureReasons muessen ueber SwiftData roundtrippen")
    }
}
