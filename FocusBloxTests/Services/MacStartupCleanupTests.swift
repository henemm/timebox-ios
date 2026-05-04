import XCTest
import SwiftData
@testable import FocusBlox

/// Bug `bug-mac-duplicate-tasks`: macOS-Startup ruft `cleanupUUIDDuplicates()` und
/// `cleanupRemindersDuplicates()` nicht auf — auf iOS schon. Dadurch sammeln sich
/// CloudKit-Sync-Duplikate im Mac-Store an und werden in der Backlog-Liste mehrfach
/// angezeigt.
///
/// Diese Tests sind **Architektur-Tests** auf Source-Code-Ebene. Sie pruefen, dass
/// die Mac-App-Startup-Sequenz die Cleanup-Aufrufe enthaelt — analog zu iOS.
/// Funktionale Tests von `cleanupUUIDDuplicates`/`cleanupRemindersDuplicates`
/// existieren bereits in `DedupCleanupTests.swift`.
@MainActor
final class MacStartupCleanupTests: XCTestCase {

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FocusBloxTests/Services/
            .deletingLastPathComponent()   // FocusBloxTests/
            .deletingLastPathComponent()   // project root
    }

    private var macAppSourceURL: URL {
        projectRoot.appendingPathComponent("FocusBloxMac/FocusBloxMacApp.swift")
    }

    private var iOSAppSourceURL: URL {
        projectRoot.appendingPathComponent("Sources/FocusBloxApp.swift")
    }

    // MARK: - Sanity: iOS hat den Aufruf bereits (Referenz-Anker)

    /// Verhalten: iOS-App-Startup ruft `cleanupUUIDDuplicates` auf (Bug 255 Referenz).
    /// Bricht wenn: Die iOS-Referenz weg ist — dann ist die ganze Paritaets-Annahme
    /// ungueltig und der Bug muss neu analysiert werden.
    func testIOSStartup_invokesUUIDDuplicatesCleanup_referenceAnchor() throws {
        let source = try String(contentsOf: iOSAppSourceURL, encoding: .utf8)
        XCTAssertTrue(
            source.contains("cleanupUUIDDuplicates"),
            "iOS-Referenz fehlt: Sources/FocusBloxApp.swift muss cleanupUUIDDuplicates aufrufen — sonst gibt es nichts wofuer macOS Paritaet erreichen sollte."
        )
    }

    // MARK: - RED → GREEN Tests

    /// Verhalten: macOS-App-Startup ruft `cleanupUUIDDuplicates` auf (Paritaet zu iOS).
    /// Bricht wenn: FocusBloxMac/FocusBloxMacApp.swift den Aufruf nicht enthaelt.
    /// Dann sammeln sich CloudKit-UUID-Duplikate im Mac-Store und werden mehrfach
    /// angezeigt (siehe Bug-Screenshot 2026-05-04: 147 Tasks gesamt, 116 unique UUIDs).
    func testMacAppStartup_invokesUUIDDuplicatesCleanup() throws {
        let source = try String(contentsOf: macAppSourceURL, encoding: .utf8)
        XCTAssertTrue(
            source.contains("cleanupUUIDDuplicates"),
            "FocusBloxMac/FocusBloxMacApp.swift muss cleanupUUIDDuplicates aufrufen — analog zu iOS (Sources/FocusBloxApp.swift). Ohne diesen Aufruf bleiben CloudKit-Sync-Duplikate im Store und werden in der Backlog-Liste doppelt angezeigt."
        )
    }

    /// Verhalten: macOS-App-Startup ruft `cleanupRemindersDuplicates` auf (Paritaet zu iOS).
    /// Bricht wenn: FocusBloxMac/FocusBloxMacApp.swift den Aufruf nicht enthaelt.
    /// Dann koennen Reminders-Import-Duplikate (gleiche externalID) im Mac-Store bestehen bleiben.
    func testMacAppStartup_invokesRemindersDuplicatesCleanup() throws {
        let source = try String(contentsOf: macAppSourceURL, encoding: .utf8)
        XCTAssertTrue(
            source.contains("cleanupRemindersDuplicates"),
            "FocusBloxMac/FocusBloxMacApp.swift muss cleanupRemindersDuplicates aufrufen — analog zu iOS. Ohne diesen Aufruf koennen Reminders-Import-Duplikate (gleiche externalID) bestehen bleiben."
        )
    }

    /// Verhalten: Cleanup laeuft VOR `migrateRemindersToLocal` und `migrateToTemplateModel`,
    /// damit nachfolgende Migrationen auf einem sauberen Datenbestand arbeiten.
    /// Bricht wenn: Cleanup-Aufrufe in der falschen Reihenfolge stehen.
    func testMacAppStartup_cleanupRunsBeforeReminderImport() throws {
        let source = try String(contentsOf: macAppSourceURL, encoding: .utf8)

        let uuidCleanupRange = try XCTUnwrap(
            source.range(of: "cleanupUUIDDuplicates"),
            "cleanupUUIDDuplicates muss in FocusBloxMacApp.swift aufgerufen werden (siehe vorheriger Test)"
        )
        let migrateRange = try XCTUnwrap(
            source.range(of: "migrateRemindersToLocal"),
            "migrateRemindersToLocal-Aufruf fehlt — strukturelle Annahme der Reihenfolge ist gebrochen"
        )

        XCTAssertLessThan(
            uuidCleanupRange.lowerBound,
            migrateRange.lowerBound,
            "cleanupUUIDDuplicates MUSS vor migrateRemindersToLocal aufgerufen werden — sonst arbeitet die Reminders-Migration auf duplizierten Daten und kann den Zustand verschlimmern."
        )
    }

    /// Verhalten: Reminders-Cleanup laeuft VOR der Recurrence-Migration.
    /// Bricht wenn: Reihenfolge falsch — Recurrence wuerde auf Duplikat-Daten arbeiten.
    func testMacAppStartup_remindersCleanupRunsBeforeRecurrenceMigration() throws {
        let source = try String(contentsOf: macAppSourceURL, encoding: .utf8)

        let remindersCleanupRange = try XCTUnwrap(
            source.range(of: "cleanupRemindersDuplicates"),
            "cleanupRemindersDuplicates muss in FocusBloxMacApp.swift aufgerufen werden (siehe vorheriger Test)"
        )
        let migrateRange = try XCTUnwrap(
            source.range(of: "migrateToTemplateModel"),
            "migrateToTemplateModel-Aufruf fehlt — strukturelle Annahme der Reihenfolge ist gebrochen"
        )

        XCTAssertLessThan(
            remindersCleanupRange.lowerBound,
            migrateRange.lowerBound,
            "cleanupRemindersDuplicates MUSS vor migrateToTemplateModel laufen — sonst basiert Recurrence-Migration auf duplizierten Tasks."
        )
    }

    // MARK: - End-to-End Behavior (Dokumentation des erwarteten Effekts)

    /// Verhalten: Wenn die Cleanup-Sequenz auf einem Store mit drei UUID-Duplikaten
    /// ausgefuehrt wird, bleibt genau eine Kopie pro UUID uebrig.
    /// Spiegelt den realen Bug-Zustand vom 2026-05-04 wieder: 147 Tasks, 116 unique UUIDs,
    /// einzelne Tasks sogar 3-fach in der DB.
    /// Bricht wenn: cleanupUUIDDuplicates nicht alle Duplikate entfernt.
    func testCleanupSequence_threefoldDuplicates_keepsExactlyOnePerUUID() throws {
        let schema = Schema([LocalTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let sharedUUID = UUID()
        for i in 0..<3 {
            let task = LocalTask(title: "PV-Anlage von Hecke frei schneiden")
            task.uuid = sharedUUID
            task.importance = i  // verschiedene attributeScores, damit "reichhaltigste" gewinnt
            context.insert(task)
        }
        try context.save()

        let beforeCount = try context.fetch(FetchDescriptor<LocalTask>()).count
        XCTAssertEqual(beforeCount, 3, "Setup: drei Duplikate eingefuegt")

        let deleted = FocusBloxApp.cleanupUUIDDuplicates(in: context)

        let after = try context.fetch(FetchDescriptor<LocalTask>())
        XCTAssertEqual(deleted, 2, "Cleanup muss zwei der drei Duplikate loeschen")
        XCTAssertEqual(after.count, 1, "Genau eine Task pro UUID bleibt uebrig")
        let kept = try XCTUnwrap(after.first, "Genau eine Task muss uebrig sein")
        XCTAssertEqual(kept.uuid, sharedUUID, "Die uebrige Task muss die ursprungliche UUID behalten")
    }
}
