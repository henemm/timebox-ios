import XCTest

/// Tests für das Deferred-Sort-Verhalten bei Badge-Taps in der BacklogView.
///
/// Gewünschtes Verhalten:
/// 1. Badge-Tap → neuer Wert SOFORT sichtbar (Label ändert sich)
/// 2. Task bleibt an seiner Y-Position (kein Sprung)
/// 3. Nach 3 Sekunden: Task gleitet animiert an neue Position
///
/// Diese Tests prüfen (1) und (2) — innerhalb von 0.8s nach dem Tap.
final class TaskJumpingBugProofTest: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: - Helpers

    /// Coordinate-based tap (workaround for FlowLayout hit test issues)
    private func tapBadge(_ badge: XCUIElement) {
        badge.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Find all importance badges in the current view, sorted by Y position (top to bottom)
    private func findImportanceBadges() -> [XCUIElement] {
        let badges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'importanceBadge_'")
        ).allElementsBoundByIndex
        return badges.sorted { $0.frame.minY < $1.frame.minY }
    }

    /// Find all urgency badges in the current view, sorted by Y position
    private func findUrgencyBadges() -> [XCUIElement] {
        let badges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'urgencyBadge_'")
        ).allElementsBoundByIndex
        return badges.sorted { $0.frame.minY < $1.frame.minY }
    }

    /// Record positions of all importance badges as [identifier: Y-position]
    private func recordBadgePositions() -> [(id: String, y: CGFloat)] {
        return findImportanceBadges().map { ($0.identifier, $0.frame.minY) }
    }

    /// Take a screenshot with a descriptive name and attach it to the test
    private func takeScreenshot(_ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Write diagnostic output to a file for inspection
    private func writeLog(_ text: String) {
        let path = "/tmp/task_jumping_test_log.txt"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write((text + "\n").data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: (text + "\n").data(using: .utf8))
        }
    }

    // MARK: - BUG-BEWEIS 1: Importance Badge Tap → Task springt

    /// Tippt JEDEN Importance-Badge im Backlog und misst ob sich irgendein Task bewegt.
    /// Wenn auch nur ein Task seine Y-Position ändert → Bug bewiesen.
    ///
    /// ERWARTET: FAIL — mindestens ein Task springt.
    /// NACH FIX: PASS — kein Task springt.
    func testImportanceTap_taskShouldNotChangeYPosition() throws {
        // Clear log file
        try? FileManager.default.removeItem(atPath: "/tmp/task_jumping_test_log.txt")

        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        sleep(3)

        takeScreenshot("01_before_any_tap")

        let badges = findImportanceBadges()
        writeLog("=== FOUND \(badges.count) IMPORTANCE BADGES ===")
        for (i, b) in badges.enumerated() {
            writeLog("  [\(i)] \(b.identifier) Y=\(b.frame.minY) label=\(b.label)")
        }

        guard badges.count >= 2 else {
            XCTFail("Brauche mindestens 2 Tasks. Gefunden: \(badges.count)")
            return
        }

        var anyJumped = false
        var jumpDetails = ""

        // Try tapping EACH badge (except the first) and check for position changes
        for i in (1..<min(badges.count, 5)).reversed() {
            let badge = badges[i]
            let targetID = badge.identifier
            let yBefore = badge.frame.minY

            // Record all positions before
            let allBefore = recordBadgePositions()
            writeLog("\n--- TAP \(i): \(targetID) at Y=\(yBefore) ---")

            tapBadge(badge)
            usleep(800_000) // 0.8s — within 3s deferred window

            // Check THIS badge's position
            let badgeAfter = app.buttons[targetID]
            if badgeAfter.exists {
                let yAfter = badgeAfter.frame.minY
                let delta = abs(yAfter - yBefore)
                writeLog("  AFTER: Y=\(yAfter), DELTA=\(delta)")

                if delta > 5 {
                    anyJumped = true
                    jumpDetails += "Badge \(targetID): Y \(yBefore)→\(yAfter) (delta=\(delta))\n"
                    writeLog("  *** JUMPED! ***")
                    takeScreenshot("JUMPED_badge_\(i)")
                }
            } else {
                writeLog("  BADGE DISAPPEARED!")
                anyJumped = true
                jumpDetails += "Badge \(targetID): VERSCHWUNDEN nach Tap\n"
            }

            // Also check if ANY other badge moved
            let allAfter = recordBadgePositions()
            for before in allBefore {
                if let after = allAfter.first(where: { $0.id == before.id }) {
                    let d = abs(after.y - before.y)
                    if d > 5 {
                        writeLog("  COLLATERAL: \(before.id) moved \(before.y)→\(after.y)")
                        anyJumped = true
                        jumpDetails += "Collateral \(before.id): Y \(before.y)→\(after.y)\n"
                    }
                }
            }
        }

        writeLog("\n=== RESULT: anyJumped=\(anyJumped) ===")
        writeLog(jumpDetails)

        takeScreenshot("99_final_state")

        // ASSERT: No task should have jumped (deferred sort keeps position frozen)
        XCTAssertFalse(anyJumped,
            "Task ist gesprungen nach Badge-Tap! Deferred Sort verhindert den Sprung nicht. " +
            "Details: \(jumpDetails) Log: /tmp/task_jumping_test_log.txt"
        )
    }

    // MARK: - BUG-BEWEIS 2: Urgency Badge Tap → Task springt

    /// Gleiches Prinzip wie Test 1, aber für Urgency-Badge.
    func testUrgencyTap_taskShouldNotChangeYPosition() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        sleep(3)

        takeScreenshot("01_urgency_before_tap")

        let badges = findUrgencyBadges()
        guard badges.count >= 2 else {
            XCTFail("Brauche mindestens 2 Tasks im Backlog. Gefunden: \(badges.count)")
            return
        }

        let targetBadge = badges.last!
        let targetID = targetBadge.identifier
        let yBefore = targetBadge.frame.minY

        print("=== URGENCY: POSITION VOR TAP ===")
        print("  \(targetID): Y=\(yBefore)")

        tapBadge(targetBadge)
        usleep(500_000)

        takeScreenshot("02_urgency_after_tap_0.5s")

        let badgeAfter = app.buttons[targetID]
        guard badgeAfter.exists else {
            XCTFail("BUG: Urgency Badge '\(targetID)' verschwunden nach Tap!")
            return
        }

        let yAfter = badgeAfter.frame.minY
        let yDelta = abs(yAfter - yBefore)

        print("=== URGENCY: POSITION NACH TAP ===")
        print("  \(targetID): Y=\(yAfter)")
        print("  DELTA: \(yDelta) Punkte")

        XCTAssertEqual(yBefore, yAfter, accuracy: 5.0,
            "BUG BEWIESEN: Task springt \(yDelta) Punkte nach Urgency-Badge-Tap. " +
            "(vorher: Y=\(yBefore), nachher: Y=\(yAfter))"
        )
    }

    // MARK: - BUG-BEWEIS 3: Reihenfolge der Tasks ändert sich

    /// Prüft ob sich die Reihenfolge der Badge-IDs (= Task-Reihenfolge) ändert.
    /// Dies ist der stärkste Beweis: Nicht nur die Position, sondern die
    /// tatsächliche SORTIER-REIHENFOLGE der Tasks wird gemessen.
    func testImportanceTap_taskOrderShouldNotChange() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        sleep(3)

        let badgesBefore = findImportanceBadges()
        guard badgesBefore.count >= 3 else {
            XCTFail("Brauche mindestens 3 Tasks. Gefunden: \(badgesBefore.count)")
            return
        }

        // Record order as list of IDs (top to bottom)
        let orderBefore = badgesBefore.map({ $0.identifier })
        print("=== REIHENFOLGE VOR TAP ===")
        for (i, id) in orderBefore.enumerated() {
            print("  [\(i)] \(id)")
        }

        // Tap the LAST badge (lowest priority → might jump up after importance increase)
        tapBadge(badgesBefore.last!)
        usleep(500_000)

        // Record new order
        let badgesAfter = findImportanceBadges()
        let orderAfter = badgesAfter.map({ $0.identifier })
        print("=== REIHENFOLGE NACH TAP ===")
        for (i, id) in orderAfter.enumerated() {
            print("  [\(i)] \(id)")
        }

        // Compare orders
        let orderChanged = orderBefore != orderAfter
        if orderChanged {
            takeScreenshot("03_ORDER_CHANGED_BUG_PROVEN")
            print("=== BUG BEWIESEN: Reihenfolge hat sich geändert! ===")
            // Find which task moved
            for (i, id) in orderBefore.enumerated() {
                if i < orderAfter.count && orderAfter[i] != id {
                    print("  Position \(i): \(id) → \(orderAfter[i])")
                }
            }
        }

        // ASSERT: Reihenfolge sollte gleich bleiben
        XCTAssertEqual(orderBefore, orderAfter,
            "Task-Reihenfolge hat sich innerhalb von 0.5s nach Importance-Badge-Tap geändert. " +
            "Deferred Sort verhindert die Neusortierung NICHT."
        )
    }

    // MARK: - TEST 4: Importance Badge zeigt neuen Wert SOFORT

    /// Prüft dass der Badge-Label sich sofort nach dem Tap ändert.
    /// Der User muss den neuen Wert sehen, um seine Eingabe zu prüfen.
    func testImportanceTap_badgeLabelChangesImmediately() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        sleep(3)

        let badges = findImportanceBadges()
        guard badges.count >= 2 else {
            XCTFail("Brauche mindestens 2 Tasks. Gefunden: \(badges.count)")
            return
        }

        // Pick a badge and record its label before tap
        let targetBadge = badges[1]
        let targetID = targetBadge.identifier
        let labelBefore = targetBadge.label

        writeLog("\n=== LABEL TEST ===")
        writeLog("  Badge: \(targetID)")
        writeLog("  Label BEFORE: \(labelBefore)")

        takeScreenshot("label_before_tap")

        // Tap → cycles importance (1→2→3→1)
        tapBadge(targetBadge)
        usleep(500_000) // 0.5s — well within 3s window

        let badgeAfter = app.buttons[targetID]
        guard badgeAfter.exists else {
            XCTFail("Badge verschwunden nach Tap!")
            return
        }

        let labelAfter = badgeAfter.label
        writeLog("  Label AFTER: \(labelAfter)")

        takeScreenshot("label_after_tap")

        // Label MUST have changed — proves new value is immediately visible
        XCTAssertNotEqual(labelBefore, labelAfter,
            "Badge-Label hat sich nicht geändert nach Tap! " +
            "Vorher: '\(labelBefore)', Nachher: '\(labelAfter)'. " +
            "Der neue Wert muss SOFORT sichtbar sein."
        )
    }

    // MARK: - TEST 5: Duration Badge Tap → Task springt nicht

    /// Prüft dass ein Duration-Badge-Tap keinen Positionssprung verursacht.
    func testDurationTap_taskShouldNotChangeYPosition() throws {
        let backlogTab = app.tabBars.buttons["Backlog"]
        if backlogTab.waitForExistence(timeout: 5) {
            backlogTab.tap()
        }
        sleep(3)

        // Find duration badges
        let durationBadges = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'durationBadge_'")
        ).allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }

        guard durationBadges.count >= 2 else {
            XCTFail("Brauche mindestens 2 Duration-Badges. Gefunden: \(durationBadges.count)")
            return
        }

        writeLog("\n=== DURATION TEST ===")

        // Record ALL importance badge positions (they share the row with duration badges)
        let allBefore = recordBadgePositions()
        writeLog("  Positions before: \(allBefore.map { "\($0.id): Y=\($0.y)" })")

        // Tap a duration badge (this opens the DurationPicker sheet)
        let targetDuration = durationBadges[1]
        let targetID = targetDuration.identifier
        let yBefore = targetDuration.frame.minY
        writeLog("  Tapping: \(targetID) at Y=\(yBefore)")

        tapBadge(targetDuration)
        usleep(800_000)

        // Check if a duration picker appeared — if so, select a value
        let picker15 = app.buttons["15 Min"]
        let picker30 = app.buttons["30 Min"]
        if picker15.waitForExistence(timeout: 2) {
            picker15.tap()
            usleep(800_000)
        } else if picker30.waitForExistence(timeout: 1) {
            picker30.tap()
            usleep(800_000)
        }

        // Check positions after
        let allAfter = recordBadgePositions()
        var anyJumped = false
        var jumpDetails = ""

        for before in allBefore {
            if let after = allAfter.first(where: { $0.id == before.id }) {
                let d = abs(after.y - before.y)
                if d > 5 {
                    anyJumped = true
                    jumpDetails += "\(before.id): Y \(before.y)→\(after.y) (delta=\(d))\n"
                    writeLog("  JUMPED: \(before.id) moved \(before.y)→\(after.y)")
                }
            }
        }

        writeLog("  Result: anyJumped=\(anyJumped)")

        XCTAssertFalse(anyJumped,
            "Task ist nach Duration-Badge-Tap gesprungen! " +
            "Details: \(jumpDetails)"
        )
    }
}
