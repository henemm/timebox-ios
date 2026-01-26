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

    // MARK: - Task Times (Zeit-Tracking) Tests

    /// GIVEN: A CalendarEvent with notes containing "times:id1=120|id2=90"
    /// WHEN: focusBlockTaskTimes is accessed
    /// THEN: Returns ["id1": 120, "id2": 90]
    func testFocusBlockTaskTimesParsesPipeSeparatedTimes() {
        let event = CalendarEvent(
            id: "test-times-1",
            title: "Focus Block with Times",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:id1|id2\ncompleted:id1|id2\ntimes:id1=120|id2=90"
        )

        let times = event.focusBlockTaskTimes
        XCTAssertEqual(times["id1"], 120)
        XCTAssertEqual(times["id2"], 90)
    }

    /// GIVEN: A CalendarEvent with no times line
    /// WHEN: focusBlockTaskTimes is accessed
    /// THEN: Returns empty dictionary
    func testFocusBlockTaskTimesReturnsEmptyForNoTimesLine() {
        let event = CalendarEvent(
            id: "test-times-2",
            title: "Focus Block no Times",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:id1|id2"
        )

        let times = event.focusBlockTaskTimes
        XCTAssertTrue(times.isEmpty)
    }

    /// GIVEN: taskIDs, completedTaskIDs, and taskTimes
    /// WHEN: serializeToNotes is called
    /// THEN: Returns notes string including times line
    func testSerializeToNotesIncludesTaskTimes() {
        let taskIDs = ["task-1", "task-2"]
        let completedIDs = ["task-1"]
        let taskTimes = ["task-1": 180, "task-2": 90]

        let notes = FocusBlock.serializeToNotes(
            taskIDs: taskIDs,
            completedTaskIDs: completedIDs,
            taskTimes: taskTimes
        )

        XCTAssertTrue(notes.contains("focusBlock:true"))
        XCTAssertTrue(notes.contains("tasks:task-1|task-2"))
        XCTAssertTrue(notes.contains("completed:task-1"))
        XCTAssertTrue(notes.contains("times:"))
        XCTAssertTrue(notes.contains("task-1=180"))
        XCTAssertTrue(notes.contains("task-2=90"))
    }

    /// GIVEN: taskIDs, completedTaskIDs, and empty taskTimes
    /// WHEN: serializeToNotes is called
    /// THEN: Returns notes string without times line
    func testSerializeToNotesOmitsEmptyTaskTimes() {
        let notes = FocusBlock.serializeToNotes(
            taskIDs: ["task-1"],
            completedTaskIDs: [],
            taskTimes: [:]
        )

        XCTAssertFalse(notes.contains("times:"))
    }

    /// GIVEN: A FocusBlock with taskTimes
    /// WHEN: notesString is accessed
    /// THEN: Returns correctly formatted notes including times
    func testFocusBlockNotesStringIncludesTimes() {
        let block = FocusBlock(
            id: "fb-times",
            title: "Focus Block",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            taskIDs: ["t1", "t2"],
            completedTaskIDs: ["t1"],
            taskTimes: ["t1": 300]
        )

        let notes = block.notesString
        XCTAssertTrue(notes.contains("times:t1=300"))
    }

    /// GIVEN: A CalendarEvent with times data
    /// WHEN: FocusBlock(from:) is called
    /// THEN: FocusBlock has correct taskTimes
    func testFocusBlockCreationParsesTaskTimes() {
        let event = CalendarEvent(
            id: "fb-times-2",
            title: "Focus Block",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            calendarColor: nil,
            notes: "focusBlock:true\ntasks:t1|t2\ncompleted:t1\ntimes:t1=240|t2=60"
        )

        let block = FocusBlock(from: event)

        XCTAssertNotNil(block)
        XCTAssertEqual(block?.taskTimes["t1"], 240)
        XCTAssertEqual(block?.taskTimes["t2"], 60)
    }

    /// GIVEN: A FocusBlock with no taskTimes
    /// WHEN: taskTimes is accessed
    /// THEN: Returns empty dictionary
    func testFocusBlockDefaultsToEmptyTaskTimes() {
        let block = FocusBlock(
            id: "fb-no-times",
            title: "Focus Block",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            taskIDs: ["t1"],
            completedTaskIDs: []
        )

        XCTAssertTrue(block.taskTimes.isEmpty)
    }
}
