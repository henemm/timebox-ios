import XCTest
@testable import FocusBlox

/// TDD RED: Coach-Tab Auto-Scroll Phase-Logik (#200).
/// Tests MÜSSEN FEHLSCHLAGEN — coachPhase(hour:morningEnd:eveningStart:hasIntention:) existiert noch nicht.
@MainActor
final class CoachPhaseLogicTests: XCTestCase {

    // MARK: - Morning Phase

    /// Verhalten: Vor morningEnd ohne Intention → .morning (Intention noch offen)
    func test_beforeMorningEnd_noIntention_isMorning() {
        let phase = DayPhase.coachPhase(hour: 8, morningEnd: 10, eveningStart: 18, hasIntention: false)
        XCTAssertEqual(phase, .morning, "08:00 ohne Intention sollte .morning sein")
    }

    /// Verhalten: Vor morningEnd MIT Intention → .daytime (Intention erledigt, weiter)
    func test_beforeMorningEnd_withIntention_isDaytime() {
        let phase = DayPhase.coachPhase(hour: 8, morningEnd: 10, eveningStart: 18, hasIntention: true)
        XCTAssertEqual(phase, .daytime, "08:00 mit Intention sollte .daytime sein")
    }

    // MARK: - Daytime Phase

    /// Verhalten: Nach morningEnd → .daytime (unabhängig von Intention)
    func test_afterMorningEnd_noIntention_isDaytime() {
        let phase = DayPhase.coachPhase(hour: 11, morningEnd: 10, eveningStart: 18, hasIntention: false)
        XCTAssertEqual(phase, .daytime, "11:00 sollte .daytime sein, auch ohne Intention")
    }

    /// Verhalten: Nach morningEnd mit Intention → .daytime
    func test_afterMorningEnd_withIntention_isDaytime() {
        let phase = DayPhase.coachPhase(hour: 14, morningEnd: 10, eveningStart: 18, hasIntention: true)
        XCTAssertEqual(phase, .daytime, "14:00 mit Intention sollte .daytime sein")
    }

    // MARK: - Evening Phase

    /// Verhalten: Ab eveningStart → .evening
    func test_atEveningStart_isEvening() {
        let phase = DayPhase.coachPhase(hour: 18, morningEnd: 10, eveningStart: 18, hasIntention: true)
        XCTAssertEqual(phase, .evening, "18:00 sollte .evening sein")
    }

    /// Verhalten: Nach eveningStart → .evening
    func test_afterEveningStart_isEvening() {
        let phase = DayPhase.coachPhase(hour: 21, morningEnd: 10, eveningStart: 18, hasIntention: false)
        XCTAssertEqual(phase, .evening, "21:00 sollte .evening sein")
    }

    // MARK: - Default morningEnd = 10

    /// Verhalten: Default morningEnd sollte 10 sein (nicht 12)
    func test_defaultMorningEnd_is10() {
        // Um 10:00 ohne Intention → sollte .daytime sein (morningEnd = 10)
        let phase = DayPhase.coachPhase(hour: 10, morningEnd: 10, eveningStart: 18, hasIntention: false)
        XCTAssertEqual(phase, .daytime, "10:00 mit morningEnd=10 sollte .daytime sein")
    }
}
