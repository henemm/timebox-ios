import XCTest
@testable import FocusBlox

/// Bug 102: Coach-Sync iOS↔macOS — Unit Tests
/// Tests fuer die Guard-Logik in pushToCloud() und die Merge-Logik in pullFromCloud().
@MainActor
final class CoachSyncTests: XCTestCase {

    // MARK: - Push Guard Tests

    /// Verhalten: pushToCloud() soll KEINE Coach-Werte pushen wenn selectedCoachDate leer ist.
    /// Bricht wenn: Guard in SyncedSettings.shouldPushCoach() entfernt wird (leere Werte werden gepusht).
    func test_shouldPushCoach_returnsFalseWhenDateEmpty() {
        let result = SyncedSettings.shouldPushCoach(localCoachDate: "")
        XCTAssertFalse(result, "Bug 102: Leere Coach-Daten duerfen nicht gepusht werden")
    }

    /// Verhalten: pushToCloud() soll Coach-Werte pushen wenn selectedCoachDate gesetzt ist.
    /// Bricht wenn: Guard in SyncedSettings.shouldPushCoach() immer false zurueckgibt.
    func test_shouldPushCoach_returnsTrueWhenDateSet() {
        let result = SyncedSettings.shouldPushCoach(localCoachDate: "2026-03-14")
        XCTAssertTrue(result, "Gesetzte Coach-Daten sollen gepusht werden")
    }

    // MARK: - Pull Merge Tests

    /// Verhalten: Remote Coach soll akzeptiert werden wenn Remote-Datum neuer ist.
    /// Bricht wenn: Vergleich in shouldAcceptRemoteCoach() von >= auf > geaendert wird.
    func test_shouldAcceptRemoteCoach_acceptsWhenRemoteNewer() {
        let result = SyncedSettings.shouldAcceptRemoteCoach(
            remoteDate: "2026-03-14",
            localDate: "2026-03-13"
        )
        XCTAssertTrue(result, "Neuerer Remote-Coach soll akzeptiert werden")
    }

    /// Verhalten: Remote Coach soll abgelehnt werden wenn Local-Datum neuer ist.
    /// Bricht wenn: Vergleich in shouldAcceptRemoteCoach() von >= auf <= geaendert wird.
    func test_shouldAcceptRemoteCoach_rejectsWhenLocalNewer() {
        let result = SyncedSettings.shouldAcceptRemoteCoach(
            remoteDate: "2026-03-13",
            localDate: "2026-03-14"
        )
        XCTAssertFalse(result, "Aelterer Remote-Coach soll abgelehnt werden")
    }

    /// Verhalten: Bei gleichem Datum soll Remote gewinnen (Last-Writer-Wins).
    /// Bricht wenn: Vergleich in shouldAcceptRemoteCoach() von >= auf > geaendert wird.
    func test_shouldAcceptRemoteCoach_remoteWinsOnEqualDate() {
        let result = SyncedSettings.shouldAcceptRemoteCoach(
            remoteDate: "2026-03-14",
            localDate: "2026-03-14"
        )
        XCTAssertTrue(result, "Bug 102: Bei gleichem Datum gewinnt Remote (Last-Writer-Wins)")
    }

    /// Verhalten: Leeres Remote-Datum soll abgelehnt werden.
    /// Bricht wenn: isEmpty-Check in shouldAcceptRemoteCoach() entfernt wird.
    func test_shouldAcceptRemoteCoach_rejectsEmptyRemoteDate() {
        let result = SyncedSettings.shouldAcceptRemoteCoach(
            remoteDate: "",
            localDate: "2026-03-14"
        )
        XCTAssertFalse(result, "Leeres Remote-Datum soll abgelehnt werden")
    }

    /// Verhalten: Leeres Remote-Datum soll auch bei leerem Local-Datum abgelehnt werden.
    /// Bricht wenn: isEmpty-Check entfernt wird und "" >= "" als true evaluiert.
    func test_shouldAcceptRemoteCoach_rejectsBothEmpty() {
        let result = SyncedSettings.shouldAcceptRemoteCoach(
            remoteDate: "",
            localDate: ""
        )
        XCTAssertFalse(result, "Leere Daten auf beiden Seiten sollen keinen Merge ausloesen")
    }
}
