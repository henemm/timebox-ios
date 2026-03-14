import XCTest
@testable import FocusBlox

final class MorningIntentionTests: XCTestCase {

    // MARK: - IntentionOption Tests

    func test_allCases_have6Options() {
        XCTAssertEqual(IntentionOption.allCases.count, 6)
    }

    func test_eachOption_hasLabelAndIcon() {
        for option in IntentionOption.allCases {
            XCTAssertFalse(option.label.isEmpty, "\(option.rawValue) should have a label")
            XCTAssertFalse(option.icon.isEmpty, "\(option.rawValue) should have an icon")
        }
    }

    func test_survivalOption_properties() {
        let option = IntentionOption.survival
        XCTAssertEqual(option.label, "Egal, Tag überleben")
        XCTAssertEqual(option.icon, "shield")
    }

    func test_fokusOption_properties() {
        let option = IntentionOption.fokus
        XCTAssertEqual(option.label, "Nicht verzetteln")
        XCTAssertEqual(option.icon, "scope")
    }

    func test_bhagOption_properties() {
        let option = IntentionOption.bhag
        XCTAssertEqual(option.label, "Das große Ding anpacken")
        XCTAssertEqual(option.icon, "flame")
    }

    func test_balanceOption_properties() {
        let option = IntentionOption.balance
        XCTAssertEqual(option.label, "In allen Bereichen leben")
        XCTAssertEqual(option.icon, "equal")
    }

    func test_growthOption_properties() {
        let option = IntentionOption.growth
        XCTAssertEqual(option.label, "Etwas Neues lernen")
        XCTAssertEqual(option.icon, "book")
    }

    func test_connectionOption_properties() {
        let option = IntentionOption.connection
        XCTAssertEqual(option.label, "Für andere da sein")
        XCTAssertEqual(option.icon, "heart.circle")
    }

    // MARK: - DailyIntention Tests

    func test_emptyIntention_isSetFalse() {
        let intention = DailyIntention(date: "2026-03-12", selections: [])
        XCTAssertFalse(intention.isSet)
    }

    func test_intentionWithSelections_isSetTrue() {
        let intention = DailyIntention(date: "2026-03-12", selections: [.fokus, .bhag])
        XCTAssertTrue(intention.isSet)
    }

    func test_todayKey_format() {
        let key = DailyIntention.todayKey()
        // Key format: "dailyIntention_YYYY-MM-DD"
        XCTAssertTrue(key.hasPrefix("dailyIntention_"))
        let datePart = key.replacingOccurrences(of: "dailyIntention_", with: "")
        XCTAssertEqual(datePart.count, 10, "Date part should be YYYY-MM-DD format")
        XCTAssertTrue(datePart.contains("-"), "Date should contain dashes")
    }

    func test_saveAndLoad_roundtrip() {
        // Use unique test key to avoid collisions
        let testKey = "dailyIntention_test_\(UUID().uuidString)"
        var intention = DailyIntention(date: "2026-03-12", selections: [.survival, .growth])
        intention.save(key: testKey)

        let loaded = DailyIntention.load(key: testKey)
        XCTAssertEqual(loaded.date, "2026-03-12")
        XCTAssertEqual(loaded.selections, [.survival, .growth])
        XCTAssertTrue(loaded.isSet)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    func test_load_missingKey_returnsEmptyIntention() {
        let loaded = DailyIntention.load(key: "dailyIntention_nonexistent_key_xyz")
        XCTAssertFalse(loaded.isSet)
        XCTAssertTrue(loaded.selections.isEmpty)
    }

    // MARK: - Notification Reminder Tests

    @MainActor
    func test_buildIntentionReminderRequest_correctID() {
        let request = NotificationService.buildIntentionReminderRequest(hour: 7, minute: 0)
        XCTAssertEqual(request.identifier, "coach-intention-reminder")
    }

    @MainActor
    func test_buildIntentionReminderRequest_correctTrigger() {
        let request = NotificationService.buildIntentionReminderRequest(hour: 8, minute: 30)
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        XCTAssertNotNil(trigger, "Trigger should be UNCalendarNotificationTrigger")
        XCTAssertTrue(trigger!.repeats, "Trigger should repeat daily")
        XCTAssertEqual(trigger!.dateComponents.hour, 8)
        XCTAssertEqual(trigger!.dateComponents.minute, 30)
    }

    @MainActor
    func test_buildIntentionReminderRequest_correctContent() {
        let request = NotificationService.buildIntentionReminderRequest(hour: 7, minute: 0)
        XCTAssertEqual(request.content.title, "Guten Morgen")
        XCTAssertEqual(request.content.body, "Was soll heute zählen?")
    }
}
