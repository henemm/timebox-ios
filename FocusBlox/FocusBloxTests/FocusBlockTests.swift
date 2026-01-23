import XCTest
@testable import FocusBlox

final class FocusBlockTests: XCTestCase {

    // MARK: - CalendarEvent Focus Block Detection Tests

    /// GIVEN: A CalendarEvent with notes containing "focusBlock:true"
    /// WHEN: isFocusBlock is accessed
    /// THEN: Returns true
    func testIsFocusBlockReturnsTrueForFocusBlockEvent() {
        let event = CalendarEvent(
            id: "test-1",
            title: "Focus Block 09:00",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true"
        )

        XCTAssertTrue(event.isFocusBlock)
    }

    /// GIVEN: A CalendarEvent with notes NOT containing "focusBlock:true"
    /// WHEN: isFocusBlock is accessed
    /// THEN: Returns false
    func testIsFocusBlockReturnsFalseForRegularEvent() {
        let event = CalendarEvent(
            id: "test-2",
            title: "Team Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "Regular meeting notes"
        )

        XCTAssertFalse(event.isFocusBlock)
    }

    /// GIVEN: A CalendarEvent with nil notes
    /// WHEN: isFocusBlock is accessed
    /// THEN: Returns false
    func testIsFocusBlockReturnsFalseForNilNotes() {
        let event = CalendarEvent(
            id: "test-3",
            title: "Quick Call",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            isAllDay: false,
            calendarColor: nil,
            notes: nil
        )

        XCTAssertFalse(event.isFocusBlock)
    }

    // MARK: - Task IDs Parsing Tests

    /// GIVEN: A CalendarEvent with notes containing "tasks:id1|id2|id3"
    /// WHEN: focusBlockTaskIDs is accessed
    /// THEN: Returns ["id1", "id2", "id3"]
    func testFocusBlockTaskIDsParsesPipeSeparatedIDs() {
        let event = CalendarEvent(
            id: "test-4",
            title: "Focus Block 10:00",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:reminder-1|reminder-2|reminder-3"
        )

        XCTAssertEqual(event.focusBlockTaskIDs, ["reminder-1", "reminder-2", "reminder-3"])
    }

    /// GIVEN: A CalendarEvent with notes containing no tasks line
    /// WHEN: focusBlockTaskIDs is accessed
    /// THEN: Returns empty array
    func testFocusBlockTaskIDsReturnsEmptyForNoTasksLine() {
        let event = CalendarEvent(
            id: "test-5",
            title: "Focus Block 11:00",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true"
        )

        XCTAssertEqual(event.focusBlockTaskIDs, [])
    }

    // MARK: - Completed IDs Parsing Tests

    /// GIVEN: A CalendarEvent with notes containing "completed:id1|id2"
    /// WHEN: focusBlockCompletedIDs is accessed
    /// THEN: Returns ["id1", "id2"]
    func testFocusBlockCompletedIDsParsesPipeSeparatedIDs() {
        let event = CalendarEvent(
            id: "test-6",
            title: "Focus Block 14:00",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:id1|id2|id3\ncompleted:id1|id2"
        )

        XCTAssertEqual(event.focusBlockCompletedIDs, ["id1", "id2"])
    }

    // MARK: - FocusBlock Serialization Tests

    /// GIVEN: taskIDs and completedTaskIDs arrays
    /// WHEN: serializeToNotes is called
    /// THEN: Returns correctly formatted notes string
    func testSerializeToNotesCreatesCorrectFormat() {
        let taskIDs = ["reminder-1", "reminder-2"]
        let completedIDs = ["reminder-1"]

        let notes = FocusBlock.serializeToNotes(taskIDs: taskIDs, completedTaskIDs: completedIDs)

        XCTAssertTrue(notes.contains("focusBlock:true"))
        XCTAssertTrue(notes.contains("tasks:reminder-1|reminder-2"))
        XCTAssertTrue(notes.contains("completed:reminder-1"))
    }

    /// GIVEN: empty taskIDs and completedTaskIDs
    /// WHEN: serializeToNotes is called
    /// THEN: Returns only "focusBlock:true"
    func testSerializeToNotesOmitsEmptyLists() {
        let notes = FocusBlock.serializeToNotes(taskIDs: [], completedTaskIDs: [])

        XCTAssertEqual(notes, "focusBlock:true")
        XCTAssertFalse(notes.contains("tasks:"))
        XCTAssertFalse(notes.contains("completed:"))
    }

    // MARK: - FocusBlock Creation from CalendarEvent Tests

    /// GIVEN: A CalendarEvent that is a focus block
    /// WHEN: FocusBlock(from:) is called
    /// THEN: Returns a valid FocusBlock
    func testFocusBlockCreationFromCalendarEvent() {
        let startDate = Date()
        let endDate = Date().addingTimeInterval(7200) // 2 hours

        let event = CalendarEvent(
            id: "fb-1",
            title: "Focus Block 09:00",
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:task-1|task-2\ncompleted:task-1"
        )

        let focusBlock = FocusBlock(from: event)

        XCTAssertNotNil(focusBlock)
        XCTAssertEqual(focusBlock?.id, "fb-1")
        XCTAssertEqual(focusBlock?.title, "Focus Block 09:00")
        XCTAssertEqual(focusBlock?.taskIDs, ["task-1", "task-2"])
        XCTAssertEqual(focusBlock?.completedTaskIDs, ["task-1"])
        XCTAssertEqual(focusBlock?.durationMinutes, 120)
    }

    /// GIVEN: A CalendarEvent that is NOT a focus block
    /// WHEN: FocusBlock(from:) is called
    /// THEN: Returns nil
    func testFocusBlockCreationReturnsNilForNonFocusBlock() {
        let event = CalendarEvent(
            id: "regular-1",
            title: "Team Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "Agenda: Q1 Review"
        )

        let focusBlock = FocusBlock(from: event)

        XCTAssertNil(focusBlock)
    }
}
