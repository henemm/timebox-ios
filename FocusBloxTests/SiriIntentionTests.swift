import XCTest
@testable import FocusBlox

/// TDD RED Tests for Phase 3f: Siri Integration / App Intents
/// Tests for DailyIntention App Group migration, IntentionOptionEnum,
/// GetEveningSummaryIntent, and SetDailyIntentionIntent.
final class SiriIntentionTests: XCTestCase {

    private let appGroupID = "group.com.henning.focusblox"

    override func tearDown() {
        super.tearDown()
        // Clean up test keys from App Group UserDefaults
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.removeObject(forKey: "dailyIntention_test_siri_roundtrip")
            defaults.removeObject(forKey: "dailyIntention_test_siri_migration")
            defaults.synchronize()
        }
        // Clean up from .standard too (migration test)
        UserDefaults.standard.removeObject(forKey: "dailyIntention_test_siri_migration")
    }

    // MARK: - DailyIntention App Group Migration

    /// Verhalten: save()/load() muessen ueber App Group UserDefaults funktionieren,
    /// damit der Siri-Intent-Prozess die Intention lesen kann.
    /// Bricht wenn: DailyIntention.save() weiterhin UserDefaults.standard benutzt
    /// statt UserDefaults(suiteName: "group.com.henning.focusblox")
    func test_dailyIntention_savesAndLoadsFromAppGroup() throws {
        let testKey = "dailyIntention_test_siri_roundtrip"
        let intention = DailyIntention(date: "2026-03-13", selections: [.fokus, .bhag])
        intention.save(key: testKey)

        // Verify data is in App Group UserDefaults (not .standard)
        guard let appGroupDefaults = UserDefaults(suiteName: appGroupID) else {
            throw XCTSkip("App Group not available in test environment")
        }
        let appGroupData = appGroupDefaults.data(forKey: testKey)
        XCTAssertNotNil(appGroupData,
                        "DailyIntention must be saved to App Group UserDefaults, not .standard")

        // Verify load() reads from App Group
        let loaded = DailyIntention.load(key: testKey)
        XCTAssertEqual(loaded.selections, [.fokus, .bhag],
                       "load() must read from App Group UserDefaults")
    }

    /// Verhalten: Bestehende Daten in .standard werden einmalig nach App Group migriert.
    /// Bricht wenn: DailyIntention.load() keine Migration von .standard → App Group macht
    func test_dailyIntention_migrationFromStandard() throws {
        let testKey = "dailyIntention_test_siri_migration"

        guard let appGroupDefaults = UserDefaults(suiteName: appGroupID) else {
            throw XCTSkip("App Group not available in test environment")
        }

        // Simuliere Altdaten in .standard (wie vor der Migration)
        let oldIntention = DailyIntention(date: "2026-03-13", selections: [.survival])
        let data = try JSONEncoder().encode(oldIntention)
        UserDefaults.standard.set(data, forKey: testKey)

        // Stelle sicher, App Group hat KEINE Daten
        appGroupDefaults.removeObject(forKey: testKey)
        appGroupDefaults.synchronize()

        // load() sollte Daten aus .standard migrieren
        let loaded = DailyIntention.load(key: testKey)
        XCTAssertEqual(loaded.selections, [.survival],
                       "load() should migrate data from .standard to App Group")

        // Nach Migration: Daten muessen in App Group sein
        let migratedData = appGroupDefaults.data(forKey: testKey)
        XCTAssertNotNil(migratedData,
                        "After migration, data must exist in App Group UserDefaults")
    }

    // MARK: - IntentionOptionEnum

    /// Verhalten: IntentionOptionEnum muss alle 6 IntentionOption-Werte abbilden.
    /// Bricht wenn: IntentionOptionEnum nicht existiert oder Cases fehlen
    func test_intentionOptionEnum_allCasesMapped() {
        let allCases = IntentionOptionEnum.allCases
        XCTAssertEqual(allCases.count, 6,
                       "IntentionOptionEnum must have all 6 intention options")

        // Verify all expected cases exist
        let rawValues = Set(allCases.map(\.rawValue))
        XCTAssertTrue(rawValues.contains("survival"))
        XCTAssertTrue(rawValues.contains("fokus"))
        XCTAssertTrue(rawValues.contains("bhag"))
        XCTAssertTrue(rawValues.contains("balance"))
        XCTAssertTrue(rawValues.contains("growth"))
        XCTAssertTrue(rawValues.contains("connection"))
    }

    /// Verhalten: asIntentionOption konvertiert korrekt zum DailyIntention-Model-Enum.
    /// Bricht wenn: IntentionOptionEnum.asIntentionOption falsch mappt
    func test_intentionOptionEnum_convertsToIntentionOption() {
        XCTAssertEqual(IntentionOptionEnum.fokus.asIntentionOption, IntentionOption.fokus)
        XCTAssertEqual(IntentionOptionEnum.bhag.asIntentionOption, IntentionOption.bhag)
        XCTAssertEqual(IntentionOptionEnum.survival.asIntentionOption, IntentionOption.survival)
        XCTAssertEqual(IntentionOptionEnum.balance.asIntentionOption, IntentionOption.balance)
        XCTAssertEqual(IntentionOptionEnum.growth.asIntentionOption, IntentionOption.growth)
        XCTAssertEqual(IntentionOptionEnum.connection.asIntentionOption, IntentionOption.connection)
    }

    // MARK: - GetEveningSummaryIntent

    /// Verhalten: Wenn keine Intention gesetzt ist, sagt Siri "keine Intention gesetzt".
    /// Bricht wenn: GetEveningSummaryIntent.perform() den isSet-Guard nicht prueft
    func test_getEveningSummary_noIntention_returnsNoIntentionDialog() async throws {
        // Stelle sicher, dass fuer heute keine Intention existiert
        let testKey = "dailyIntention_9999-12-31"
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.removeObject(forKey: testKey)
            defaults.synchronize()
        }

        let intent = GetEveningSummaryIntent()
        let result = try await intent.perform()

        // Der Dialog muss erwaehnen, dass keine Intention gesetzt ist
        let dialog = String(describing: result)
        XCTAssertTrue(dialog.contains("keine Intention"),
                      "When no intention is set, dialog must mention 'keine Intention'")
    }

    /// Verhalten: Intent darf die App NICHT oeffnen.
    /// Bricht wenn: GetEveningSummaryIntent.openAppWhenRun auf true steht
    func test_getEveningSummary_doesNotOpenApp() {
        XCTAssertFalse(GetEveningSummaryIntent.openAppWhenRun,
                       "GetEveningSummaryIntent must NOT open the app")
    }

    // MARK: - SetDailyIntentionIntent

    /// Verhalten: Intent speichert die uebergebene Intention korrekt.
    /// Bricht wenn: SetDailyIntentionIntent.perform() die Intention nicht speichert
    func test_setDailyIntention_savesCorrectly() async throws {
        let intent = SetDailyIntentionIntent()
        intent.intention = .fokus
        _ = try await intent.perform()

        // Pruefen ob Intention gespeichert wurde
        let loaded = DailyIntention.load()
        XCTAssertTrue(loaded.isSet, "Intention must be set after SetDailyIntentionIntent")
        XCTAssertTrue(loaded.selections.contains(.fokus),
                      "Saved intention must contain .fokus")
    }

    /// Verhalten: Intent darf die App NICHT oeffnen.
    /// Bricht wenn: SetDailyIntentionIntent.openAppWhenRun auf true steht
    func test_setDailyIntention_doesNotOpenApp() {
        XCTAssertFalse(SetDailyIntentionIntent.openAppWhenRun,
                       "SetDailyIntentionIntent must NOT open the app")
    }
}
