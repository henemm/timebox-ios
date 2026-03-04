import XCTest
@testable import FocusBlox

/// Tests for Bug 69: EKEventStoreChangedNotification auto-refresh
/// Bricht wenn: EventKitRepository.eventStoreChangeCount nicht existiert oder nicht incrementiert
final class EventStoreChangeNotificationTests: XCTestCase {

    /// Verhalten: eventStoreChangeCount startet bei 0
    /// Bricht wenn: Property eventStoreChangeCount nicht auf EventKitRepository existiert
    func test_eventStoreChangeCount_startsAtZero() {
        let repo = EventKitRepository()
        XCTAssertEqual(repo.eventStoreChangeCount, 0,
                       "eventStoreChangeCount should start at 0")
    }

    /// Verhalten: eventStoreChangeCount incrementiert bei EKEventStoreChanged Notification
    /// Bricht wenn: NotificationCenter Observer nicht registriert oder Counter nicht incrementiert
    func test_eventStoreChangeCount_incrementsOnNotification() {
        let repo = EventKitRepository()
        let initialCount = repo.eventStoreChangeCount

        // Simulate EventKit store change notification
        NotificationCenter.default.post(
            name: .EKEventStoreChanged,
            object: nil
        )

        // Give main queue time to process
        let expectation = XCTestExpectation(description: "Counter incremented")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertGreaterThan(repo.eventStoreChangeCount, initialCount,
                             "eventStoreChangeCount should increment after EKEventStoreChanged notification")
    }

    /// Verhalten: Mehrere Notifications incrementieren Counter mehrfach
    /// Bricht wenn: Observer nur einmal feuert oder Counter resettet
    func test_eventStoreChangeCount_incrementsMultipleTimes() {
        let repo = EventKitRepository()

        // Post 3 notifications
        for _ in 0..<3 {
            NotificationCenter.default.post(
                name: .EKEventStoreChanged,
                object: nil
            )
        }

        let expectation = XCTestExpectation(description: "Counters incremented")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertGreaterThanOrEqual(repo.eventStoreChangeCount, 3,
                                    "eventStoreChangeCount should increment for each notification")
    }
}
