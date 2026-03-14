import XCTest
@testable import FocusBlox

/// Tests for DailyCoachSelection App Group persistence, CoachTypeEnum,
/// GetEveningSummaryIntent, and SetDailyIntentionIntent.
final class SiriIntentionTests: XCTestCase {

    private let appGroupID = "group.com.henning.focusblox"

    override func tearDown() {
        super.tearDown()
        // Clean up AppStorage keys
        UserDefaults.standard.removeObject(forKey: "selectedCoach")
    }

    // MARK: - DailyCoachSelection Persistence

    /// Verhalten: save()/load() muessen ueber App Group UserDefaults funktionieren.
    func test_dailyCoachSelection_savesAndLoads() {
        var selection = DailyCoachSelection(date: DailyCoachSelection.todayDateString(), coach: .feuer)
        selection.save()

        let loaded = DailyCoachSelection.load()
        XCTAssertEqual(loaded.coach, .feuer, "load() must return the saved coach")
    }

    /// Verhalten: Kein Coach gesetzt → coach ist nil.
    func test_dailyCoachSelection_noCoach_returnsNil() {
        // Save with nil coach
        var selection = DailyCoachSelection(date: DailyCoachSelection.todayDateString(), coach: nil)
        selection.save()

        let loaded = DailyCoachSelection.load()
        XCTAssertNil(loaded.coach, "Coach should be nil when none selected")
        XCTAssertFalse(loaded.isSet, "isSet should be false when no coach")
    }

    // MARK: - CoachTypeEnum

    /// Verhalten: CoachTypeEnum muss alle 4 CoachType-Werte abbilden.
    func test_coachTypeEnum_allCasesMapped() {
        let allCases = CoachTypeEnum.allCases
        XCTAssertEqual(allCases.count, 4,
                       "CoachTypeEnum must have all 4 coach options")

        let rawValues = Set(allCases.map(\.rawValue))
        XCTAssertTrue(rawValues.contains("troll"))
        XCTAssertTrue(rawValues.contains("feuer"))
        XCTAssertTrue(rawValues.contains("eule"))
        XCTAssertTrue(rawValues.contains("golem"))
    }

    /// Verhalten: asCoachType konvertiert korrekt zum CoachType-Model-Enum.
    func test_coachTypeEnum_convertsToCoachType() {
        XCTAssertEqual(CoachTypeEnum.troll.asCoachType, CoachType.troll)
        XCTAssertEqual(CoachTypeEnum.feuer.asCoachType, CoachType.feuer)
        XCTAssertEqual(CoachTypeEnum.eule.asCoachType, CoachType.eule)
        XCTAssertEqual(CoachTypeEnum.golem.asCoachType, CoachType.golem)
    }

    // MARK: - GetEveningSummaryIntent

    /// Verhalten: Wenn kein Coach gesetzt, sagt Siri "keinen Coach gewaehlt".
    func test_getEveningSummary_noCoach_returnsNoCoachDialog() async throws {
        // Clear today's coach
        var selection = DailyCoachSelection(date: DailyCoachSelection.todayDateString(), coach: nil)
        selection.save()

        let intent = GetEveningSummaryIntent()
        let result = try await intent.perform()

        let dialog = String(describing: result)
        XCTAssertTrue(dialog.contains("keinen Coach"),
                      "When no coach is set, dialog must mention 'keinen Coach'")
    }

    /// Verhalten: Intent darf die App NICHT oeffnen.
    func test_getEveningSummary_doesNotOpenApp() {
        XCTAssertFalse(GetEveningSummaryIntent.openAppWhenRun,
                       "GetEveningSummaryIntent must NOT open the app")
    }

    // MARK: - SetDailyIntentionIntent

    /// Verhalten: Intent speichert den uebergebenen Coach korrekt.
    func test_setDailyIntention_savesCorrectly() async throws {
        let intent = SetDailyIntentionIntent()
        intent.coach = .troll
        _ = try await intent.perform()

        let loaded = DailyCoachSelection.load()
        XCTAssertTrue(loaded.isSet, "Coach must be set after SetDailyIntentionIntent")
        XCTAssertEqual(loaded.coach, .troll, "Saved coach must be .troll")
    }

    /// Verhalten: Intent darf die App NICHT oeffnen.
    func test_setDailyIntention_doesNotOpenApp() {
        XCTAssertFalse(SetDailyIntentionIntent.openAppWhenRun,
                       "SetDailyIntentionIntent must NOT open the app")
    }
}
