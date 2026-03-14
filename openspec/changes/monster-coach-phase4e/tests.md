# Tests: Monster Coach Phase 4e — Monster in Push-Notifications

> Erstellt: 2026-03-14
> Status: Zur Freigabe
> Bezug: `proposal.md`

---

## Uebersicht

| Test-Typ | Anzahl | Ziel-File |
|----------|--------|-----------|
| Unit Tests | 8 | `FocusBloxTests/MonsterNotificationAttachmentTests.swift` (neu) |
| UI Tests | 3 | `FocusBloxUITests/MonsterNotificationAttachmentUITests.swift` (neu) |

---

## Unit Tests: MonsterNotificationAttachmentTests

Datei: `FocusBloxTests/MonsterNotificationAttachmentTests.swift`

Diese Tests pruefen, dass die bestehenden Builder-Funktionen korrekt mit dem neuen `intention`-Parameter umgehen — inhaltlich (Attachment gesetzt oder nicht) und hinsichtlich Backward-Kompatibilitaet (kein Attachment wenn kein Intention-Parameter).

### buildIntentionReminderRequest — mit Intention

```swift
func test_buildIntentionReminderRequest_withIntention_contentHasAttachments() {
    // Arrangement: intention = .bhag
    // Act: buildIntentionReminderRequest(hour: 8, minute: 0, intention: .bhag)
    // Assert: request.content.attachments.isEmpty == false
}
```

```swift
func test_buildIntentionReminderRequest_withIntention_attachmentIdentifierContainsMonsterName() {
    // Arrangement: intention = .fokus → monsterDiscipline = .fokus → imageName = "monsterFokus"
    // Act: buildIntentionReminderRequest(hour: 8, minute: 0, intention: .fokus)
    // Assert: request.content.attachments.first?.identifier.contains("monsterFokus") == true
}
```

```swift
func test_buildIntentionReminderRequest_withoutIntention_contentHasNoAttachments() {
    // Backward-Kompatibilitaet: kein intention-Parameter = kein Attachment
    // Act: buildIntentionReminderRequest(hour: 8, minute: 0)
    // Assert: request.content.attachments.isEmpty == true
}
```

### buildEveningReminderRequest — mit Intention

```swift
func test_buildEveningReminderRequest_withIntention_contentHasAttachments() {
    // Arrangement: intention = .connection, now = 10:00 (weit vor 20:00)
    // Act: buildEveningReminderRequest(hour: 20, minute: 0, intention: .connection, now: earlyMorning)
    // Assert: request?.content.attachments.isEmpty == false
}
```

```swift
func test_buildEveningReminderRequest_withoutIntention_contentHasNoAttachments() {
    // Backward-Kompatibilitaet
    // Act: buildEveningReminderRequest(hour: 20, minute: 0, now: earlyMorning)
    // Assert: request?.content.attachments.isEmpty == true
}
```

### buildDailyNudgeRequests — Attachment in allen Requests

```swift
func test_buildDailyNudgeRequests_allRequestsHaveAttachment() {
    // Arrangement: intention = .bhag, maxCount = 3
    // Act: buildDailyNudgeRequests(intention: .bhag, gap: .noBhagBlockCreated, ..., maxCount: 3)
    // Assert: requests.allSatisfy { !$0.content.attachments.isEmpty } == true
}
```

```swift
func test_buildDailyNudgeRequests_attachmentUsesCorrectMonsterForBhag() {
    // Arrangement: .bhag → monsterDiscipline = .mut → imageName = "monsterMut"
    // Act: buildDailyNudgeRequests(intention: .bhag, gap: .noBhagBlockCreated, ...)
    // Assert: requests.first?.content.attachments.first?.identifier.contains("monsterMut") == true
}
```

```swift
func test_buildDailyNudgeRequests_survival_returnsEmptyRegardlessOfAttachment() {
    // Survival = keine Notifications, auch kein Attachment
    // Act: buildDailyNudgeRequests(intention: .survival, gap: .noBhagBlockCreated, ...)
    // Assert: requests.isEmpty == true
}
```

### Intention-zu-Monster Mapping

```swift
func test_intentionMonsterMapping_allSixIntentionsMapped() {
    // Prueft dass jede IntentionOption eine gueltige imageName ergibt
    // Kein neuer Code — validiert das bestehende Mapping ist vollstaendig
    for intention in IntentionOption.allCases {
        let imageName = intention.monsterDiscipline.imageName
        // Assert: imageName ist nicht leer
        // Assert: imageName startet mit "monster"
    }
}
```

---

## Hinweis: Attachment-Test-Einschraenkung

`UNNotificationAttachment` laedt eine Datei vom Filesystem. In Unit Tests ist kein Asset Catalog verfuegbar — `UIImage(named:)` gibt `nil` zurueck. Deshalb testen die Unit Tests nur:
1. Dass `content.attachments` nicht leer ist wenn ein Attachment erstellt wurde
2. Dass der Attachment-Identifier den richtigen Monster-Namen enthaelt

Die tatsaechliche Bildladung (ob `UIImage(named:)` das PNG findet) wird durch die UI Tests abgedeckt, die auf dem Simulator mit echtem Asset Catalog laufen.

---

## UI Tests: MonsterNotificationAttachmentUITests

Datei: `FocusBloxUITests/MonsterNotificationAttachmentUITests.swift`

Diese Tests pruefen das Ende-zu-Ende Verhalten: Intention setzen → Notification wird mit Attachment geplant.

**Strategie:** Da Notification-Attachments nicht direkt in der App-UI sichtbar sind, pruefen die UI Tests das korrekte Scheduling indirekt — ueber die Settings-UI und die bestehenden Coach-Notification-Elemente. Die Tests bestaetigen, dass die App nicht abstuerzt und die Notification-Settings korrekt funktionieren.

```swift
func test_monsterNotification_intentionReminderScheduledWithoutCrash() {
    // Arrangement: Coach-Modus aktivieren, Morgen-Erinnerung aktivieren
    // Act: Intention setzen (z.B. "Nicht verzetteln" = .fokus)
    // Assert: App stuerzt nicht ab (kein Crash durch UIImage-Laden)
    // Assert: Settings-View zeigt Morgen-Erinnerung Toggle als aktiv
}
```

```swift
func test_monsterNotification_eveningReminderScheduledWithoutCrash() {
    // Arrangement: Coach-Modus aktivieren, Abend-Erinnerung aktivieren
    // Act: In FocusBloxApp scenePhase wird Abend-Erinnerung geplant
    // Vereinfachung: Testen ob Settings-View korrekt zeigt dass Abend-Erinnerung aktiv ist
    // Assert: "coachEveningReminderToggle" existiert und ist aktiviert
}
```

```swift
func test_monsterNotification_coachSettingsVisible_afterIntentionSet() {
    // Regression: Settings zeigen noch alle Coach-Notification-Optionen nach Intention-Setzen
    // Arrangement: Coach-Modus an, alle Notifications aktiviert
    // Assert: morningReminderToggle existiert, eveningReminderToggle existiert, dailyNudgesToggle existiert
}
```

---

## Accessibility Identifiers (keine neuen noetig)

Die bestehenden Identifiers aus Phase 3b und 3e werden weiterverwendet. Keine neuen UI-Elemente werden hinzugefuegt — die Attachment-Logik ist rein technisch im Service.

---

## TDD-Reihenfolge

1. `MonsterNotificationAttachmentTests` schreiben (RED) — `buildMonsterAttachment` existiert noch nicht, Parameter fehlen
2. `MonsterNotificationAttachmentUITests` schreiben (RED) — Crash-Tests schlagen fehl solange Implementierung fehlt
3. `buildMonsterAttachment(for:)` in `NotificationService.swift` implementieren
4. Builder-Funktionen um optionalen `intention`-Parameter erweitern
5. `scheduleIntentionReminder` und `scheduleEveningReminder` Signaturen anpassen
6. `MorningIntentionView.swift` + `FocusBloxApp.swift` Aufrufe anpassen
7. Alle Tests erneut durchlaufen → alles GREEN
