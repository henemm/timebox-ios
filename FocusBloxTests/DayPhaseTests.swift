import XCTest
@testable import FocusBlox

final class DayPhaseTests: XCTestCase {

    // MARK: - DayPhase.from(hour:morningEnd:eveningStart:)

    /// Verhalten: Stunde 8 mit Default-Settings (morningEnd=12) → morning
    /// Bricht wenn: DayPhase.from() den hour < morningEnd Vergleich falsch macht
    func test_earlyMorning_returnsMorning() {
        let phase = DayPhase.from(hour: 8, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .morning, "8 Uhr sollte Morning sein")
    }

    /// Verhalten: Stunde 0 (Mitternacht) → morning
    /// Bricht wenn: DayPhase.from() Mitternacht nicht als Morning erkennt
    func test_midnight_returnsMorning() {
        let phase = DayPhase.from(hour: 0, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .morning, "Mitternacht sollte Morning sein")
    }

    /// Verhalten: Stunde 11 (letzte Stunde vor morningEnd) → morning
    /// Bricht wenn: DayPhase.from() < statt <= verwendet (Off-by-one)
    func test_lastMorningHour_returnsMorning() {
        let phase = DayPhase.from(hour: 11, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .morning, "11 Uhr sollte noch Morning sein")
    }

    /// Verhalten: Stunde 12 exakt (Grenze morningEnd) → daytime, NICHT morning
    /// Bricht wenn: DayPhase.from() <= statt < fuer morningEnd verwendet
    func test_exactMorningEnd_returnsDaytime() {
        let phase = DayPhase.from(hour: 12, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .daytime, "12 Uhr (morningEnd) sollte Daytime sein, nicht Morning")
    }

    /// Verhalten: Stunde 14 → daytime
    /// Bricht wenn: DayPhase.from() den Daytime-Bereich nicht korrekt erkennt
    func test_afternoon_returnsDaytime() {
        let phase = DayPhase.from(hour: 14, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .daytime, "14 Uhr sollte Daytime sein")
    }

    /// Verhalten: Stunde 17 (letzte Stunde vor eveningStart) → daytime
    /// Bricht wenn: DayPhase.from() < statt <= fuer eveningStart verwendet
    func test_lastDaytimeHour_returnsDaytime() {
        let phase = DayPhase.from(hour: 17, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .daytime, "17 Uhr sollte noch Daytime sein")
    }

    /// Verhalten: Stunde 18 exakt (Grenze eveningStart) → evening, NICHT daytime
    /// Bricht wenn: DayPhase.from() <= statt < fuer eveningStart verwendet
    func test_exactEveningStart_returnsEvening() {
        let phase = DayPhase.from(hour: 18, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .evening, "18 Uhr (eveningStart) sollte Evening sein, nicht Daytime")
    }

    /// Verhalten: Stunde 22 → evening
    /// Bricht wenn: DayPhase.from() den Evening-Bereich nicht korrekt erkennt
    func test_lateEvening_returnsEvening() {
        let phase = DayPhase.from(hour: 22, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .evening, "22 Uhr sollte Evening sein")
    }

    /// Verhalten: Stunde 23 (letzte Stunde des Tages) → evening
    /// Bricht wenn: DayPhase.from() Stunde 23 nicht handelt
    func test_lastHourOfDay_returnsEvening() {
        let phase = DayPhase.from(hour: 23, morningEnd: 12, eveningStart: 18)
        XCTAssertEqual(phase, .evening, "23 Uhr sollte Evening sein")
    }

    // MARK: - Custom Settings

    /// Verhalten: morningEnd=10 verschiebt den Morning-Bereich → 10 Uhr ist Daytime
    /// Bricht wenn: DayPhase.from() den morningEnd Parameter ignoriert
    func test_customMorningEnd_shiftsTransition() {
        let phase = DayPhase.from(hour: 10, morningEnd: 10, eveningStart: 18)
        XCTAssertEqual(phase, .daytime, "10 Uhr bei morningEnd=10 sollte Daytime sein")
    }

    /// Verhalten: eveningStart=20 verschiebt den Evening-Bereich → 19 Uhr ist noch Daytime
    /// Bricht wenn: DayPhase.from() den eveningStart Parameter ignoriert
    func test_customEveningStart_shiftsTransition() {
        let phase = DayPhase.from(hour: 19, morningEnd: 12, eveningStart: 20)
        XCTAssertEqual(phase, .daytime, "19 Uhr bei eveningStart=20 sollte noch Daytime sein")
    }
}
