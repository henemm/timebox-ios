# Context: Task 3 - Push-Notification bei Focus Block Start

## Anforderung

Push-Notification soll X Minuten vor Start eines Focus Blocks (oder bei Start) geschickt werden.

## Analysis

### Bestehende Architektur

**NotificationService.swift** - Bereits vorhanden:
- `requestPermission()` - Permission-Anfrage
- `scheduleTaskOverdueNotification()` - Task-Timer Notifications
- `cancelTaskNotification()` - Stornierung einzelner Notifications
- Nutzt `UNUserNotificationCenter`

**FocusBlock-Erstellung:**
- `BlockPlanningView.createFocusBlock()` → `EventKitRepository.createFocusBlock()`
- Focus Blocks werden als Kalender-Events gespeichert
- Haben `startDate` und `endDate`

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Services/NotificationService.swift | MODIFY | +scheduleFocusBlockNotification(), +cancelFocusBlockNotification() |
| Sources/Views/BlockPlanningView.swift | MODIFY | Nach createFocusBlock() Notification schedulen |
| Sources/Views/EditFocusBlockSheet.swift | MODIFY | Bei Zeit-Änderung Notification aktualisieren |

### Scope Assessment

- Files: 3
- Estimated LoC: +60/-0
- Risk Level: LOW

### Technical Approach

1. **NotificationService erweitern:**
   ```swift
   static func scheduleFocusBlockNotification(
       blockID: String,
       blockTitle: String,
       startDate: Date,
       minutesBefore: Int = 5
   )

   static func cancelFocusBlockNotification(blockID: String)
   ```

2. **Trigger-Zeitpunkt:**
   - Default: 5 Minuten vor Start
   - Alternative: Bei Start (minutesBefore = 0)
   - Wenn startDate < 5 Min in Zukunft → sofort bei Start

3. **Integration:**
   - Nach `createFocusBlock()` → `scheduleFocusBlockNotification()`
   - Nach `updateFocusBlockTime()` → reschedule Notification
   - Nach `deleteFocusBlock()` → `cancelFocusBlockNotification()`

### Notification Content

```
Title: "Focus Block startet"
Body: "Focus Block um [Uhrzeit] beginnt in 5 Minuten"
Sound: default
```

Bei Start (0 Min):
```
Title: "Focus Block startet jetzt"
Body: "Focus Block [Titel] beginnt jetzt"
```

### Open Questions

- [x] Wie viele Minuten vor Start? → Default 5 Min, konfigurierbar
- [ ] Soll der User die Vorlaufzeit einstellen können? → Erstmal hardcoded

## Next Steps

1. `/write-spec` - Specification erstellen
2. User Approval
3. `/tdd-red` - UI Tests schreiben
4. `/implement` - Implementieren
