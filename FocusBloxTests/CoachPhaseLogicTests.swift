import XCTest
@testable import FocusBlox

/// Unit Tests für DayPhase.from() — Coach-Tab Phase-Logik.
@MainActor
final class CoachPhaseLogicTests: XCTestCase {

    /// Verhalten: Vor morningEnd → .morning
    func test_beforeMorningEnd_isMorning() {
        let phase = DayPhase.from(hour: 8, morningEnd: 10, eveningStart: 18)
        XCTAssertEqual(phase, .morning, "08:00 sollte .morning sein")
    }

    /// Verhalten: Nach morningEnd → .daytime
    func test_afterMorningEnd_isDaytime() {
        let phase = DayPhase.from(hour: 11, morningEnd: 10, eveningStart: 18)
        XCTAssertEqual(phase, .daytime, "11:00 sollte .daytime sein")
    }

    /// Verhalten: Genau morningEnd → .daytime (exclusive boundary)
    func test_atMorningEnd_isDaytime() {
        let phase = DayPhase.from(hour: 10, morningEnd: 10, eveningStart: 18)
        XCTAssertEqual(phase, .daytime, "10:00 mit morningEnd=10 sollte .daytime sein")
    }

    /// Verhalten: Ab eveningStart → .evening
    func test_atEveningStart_isEvening() {
        let phase = DayPhase.from(hour: 18, morningEnd: 10, eveningStart: 18)
        XCTAssertEqual(phase, .evening, "18:00 sollte .evening sein")
    }

    /// Verhalten: Nach eveningStart → .evening
    func test_afterEveningStart_isEvening() {
        let phase = DayPhase.from(hour: 21, morningEnd: 10, eveningStart: 18)
        XCTAssertEqual(phase, .evening, "21:00 sollte .evening sein")
    }
}
