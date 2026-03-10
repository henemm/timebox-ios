import XCTest
@testable import FocusBlox

final class CalendarDeepLinkTests: XCTestCase {

    // MARK: - FocusBlock Deep Link URL Generation

    func test_focusBlockDeepLinkURL_hasCorrectSchemeAndHost() {
        // Given: A FocusBlock event ID
        let eventID = "EK-EVENT-12345"

        // When
        let url = FocusBlock.deepLinkURL(for: eventID)

        // Then: URL should be focusblox://focus-block/{id}
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "focusblox")
        XCTAssertEqual(url?.host, "focus-block")
        XCTAssertEqual(url?.pathComponents.last, eventID)
    }

    func test_focusBlockDeepLinkURL_encodesSpecialCharacters() {
        // Given: An event ID with special characters (EventKit can return these)
        let eventID = "ABC/123+DEF"

        // When
        let url = FocusBlock.deepLinkURL(for: eventID)

        // Then: Should still produce a valid URL
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "focusblox")
    }

    func test_focusBlockDeepLinkURL_emptyID_returnsNil() {
        // Given: An empty event ID
        let eventID = ""

        // When
        let url = FocusBlock.deepLinkURL(for: eventID)

        // Then: Should return nil for empty IDs
        XCTAssertNil(url)
    }

    // MARK: - URL Parsing (for onOpenURL handler)

    func test_parseFocusBlockURL_extractsEventID() {
        // Given: A valid focus-block deep link
        let url = URL(string: "focusblox://focus-block/EK-EVENT-12345")!

        // When
        let eventID = FocusBlock.eventID(from: url)

        // Then
        XCTAssertEqual(eventID, "EK-EVENT-12345")
    }

    func test_parseFocusBlockURL_wrongHost_returnsNil() {
        // Given: A URL with wrong host
        let url = URL(string: "focusblox://create-task")!

        // When
        let eventID = FocusBlock.eventID(from: url)

        // Then
        XCTAssertNil(eventID)
    }

    func test_parseFocusBlockURL_noPath_returnsNil() {
        // Given: A URL with correct host but no path
        let url = URL(string: "focusblox://focus-block")!

        // When
        let eventID = FocusBlock.eventID(from: url)

        // Then
        XCTAssertNil(eventID)
    }
}
