---
entity_id: td-03-services-tests
type: test
created: 2026-03-16
updated: 2026-03-16
status: draft
version: "1.0"
tags: [tech-debt, testing, unit-tests]
---

# TD-03: Services ohne Unit Tests absichern

## Approval

- [x] Approved

## Purpose

Drei bestehende Services (GapFinder, NotificationService, FocusBlockActionService) haben keine Unit Tests. Diese Spezifikation beschreibt das Nachruesten von 40-49 Tests als Sicherheitsnetz gegen Regressionen — ohne Produktionscode zu veraendern.

## Source

- **File:** `FocusBloxTests/GapFinderTests.swift` (neu)
- **File:** `FocusBloxTests/NotificationServiceBuildTests.swift` (neu)
- **File:** `FocusBloxTests/FocusBlockActionServiceTests.swift` (neu)
- **File:** `Sources/Testing/MockEventKitRepository.swift` (Erweiterung)
- **Identifier:** `GapFinder.findFreeSlots()`, `NotificationService.build*()`, `FocusBlockActionService.completeTask()` / `skipTask()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Sources/Models/GapFinder.swift` | module | Getestete Pure-Logic-Struct (153 LoC) |
| `Sources/Services/NotificationService.swift` | module | Getestete build-Methoden (694 LoC) |
| `Sources/Services/FocusBlockActionService.swift` | module | Getestete complete/skip Logik (140 LoC) |
| `Sources/Models/CalendarEvent.swift` | model | Fixtures fuer GapFinder-Tests |
| `Sources/Models/FocusBlock.swift` | model | Fixtures fuer GapFinder + FocusBlockActionService |
| `Sources/Models/LocalTask.swift` | model | Fixtures fuer FocusBlockActionService |
| `Sources/Models/CoachType.swift` | model | NotificationService Nudge-Tests |
| `Sources/Models/CoachGap.swift` | model | NotificationService Nudge-Algorithmus (7 Gap-Typen) |
| `Sources/Services/RecurrenceService.swift` | service | FocusBlockActionService erzeugt recurring Tasks |
| `Sources/Testing/MockEventKitRepository.swift` | mock | Erweiterung: updateFocusBlock Call-Tracking |
| `FocusBloxTests/BadgeOverdueNotificationTests.swift` | reference | Referenz-Pattern fuer NotificationService-Tests |
| `FocusBloxTests/CoachMissionServiceTests.swift` | reference | GIVEN/WHEN/THEN Factory-Pattern |

## Implementation Details

### Implementierungsreihenfolge

**Phase 1: GapFinder** — Pure Logic, kein Mock noetig, null Risiko
**Phase 2: NotificationService** — build-Methoden, Pattern aus BadgeOverdueNotificationTests
**Phase 3: FocusBlockActionService** — Mock erweitern, dann Service-Logik testen

---

### Phase 1: GapFinderTests.swift (12-15 Tests)

**Setup:** CalendarEvent- und FocusBlock-Fixtures via Hilfsfunktionen, kein ModelContainer noetig (pure struct).

```
test_findFreeSlots_emptyCalendar_returnsDefaultSuggestions
  → Leerer Kalender ergibt Standard-Vorschlaege [09:00, 11:00, 14:00, 16:00]

test_findFreeSlots_singleEvent_correctGapsBeforeAndAfter
  → Ein Event um 10-11 Uhr → Slots davor und danach korrekt

test_findFreeSlots_multipleEvents_gapsBetweenEvents
  → Mehrere Events → alle Luecken werden gefunden

test_findFreeSlots_overlappingEvents_mergedBusyPeriods
  → Ueberlappende Events werden zu einem Busy-Block zusammengefasst

test_findFreeSlots_gapShorterThanMinMinutes_excluded
  → Luecke < 30min wird nicht als Slot zurueckgegeben

test_findFreeSlots_gapLongerThanMaxMinutes_cappedToMaxMinutes
  → Luecke > 60min ergibt Slot mit exakt 60min Dauer

test_findFreeSlots_allDayEvent_excludedFromCalculation
  → All-Day-Event wird nicht als Busy-Zeit gezaehlt

test_findFreeSlots_focusBlockCountsAsBusy
  → Existierender FocusBlock blockiert den Zeitslot

test_findFreeSlots_today_pastSlotsExcluded
  → Slots die vor der aktuellen Uhrzeit liegen werden nicht zurueckgegeben

test_findFreeSlots_futureDate_startsFrom0600
  → Zukuenftiger Tag beginnt Suche ab 06:00 Uhr

test_findFreeSlots_fullDay_returnsEmptyArray
  → Komplett verplanter Tag ergibt leeres Array

test_findFreeSlots_dayMostlyFree_returnsDefaultSuggestions
  → Tag mit < 120min Terminen ergibt Standard-Vorschlaege
```

---

### Phase 2: NotificationServiceBuildTests.swift (18-22 Tests)

**Setup:** Kein ModelContainer noetig. `AppSettings.shared` Singleton — Tests sind read-only, kein gegenseitiger Einfluss. Kein `UNUserNotificationCenter` noetig (nur build-Methoden).

**buildFocusBlockNotificationRequest (3 Tests):**
```
test_buildFocusBlockNotificationRequest_validDate_correctContent
  → title/body korrekt befuellt

test_buildFocusBlockNotificationRequest_validDate_correctTrigger
  → UNTimeIntervalNotificationTrigger mit korrektem Interval

test_buildFocusBlockNotificationRequest_pastDate_returnsNil
  → Vergangenes Startdatum → nil zurueck
```

**buildFocusBlockEndNotificationRequest (3 Tests):**
```
test_buildFocusBlockEndNotificationRequest_completedCount_inContent
  → completedCount erscheint im body

test_buildFocusBlockEndNotificationRequest_totalCount_inContent
  → totalCount erscheint im body

test_buildFocusBlockEndNotificationRequest_trigger_correctInterval
  → Trigger-Interval entspricht Block-Endzeitpunkt
```

**buildIntentionReminderRequest (3 Tests):**
```
test_buildIntentionReminderRequest_calendarTrigger_repeats
  → UNCalendarNotificationTrigger mit repeats: true

test_buildIntentionReminderRequest_withCoach_contentAttached
  → Coach-Typ beeinflusst Notification-Inhalt

test_buildIntentionReminderRequest_withoutCoach_defaultContent
  → Ohne Coach-Typ: Standard-Inhalt
```

**buildEveningReminderRequest (2 Tests):**
```
test_buildEveningReminderRequest_timeNotYetPassed_calendarTrigger
  → Uhrzeit noch in der Zukunft → korrekter Calendar-Trigger

test_buildEveningReminderRequest_timePassed_returnsNil
  → Uhrzeit bereits vergangen → nil zurueck
```

**buildDailyNudgeRequests (5-7 Tests):**
```
test_buildDailyNudgeRequests_evenSpacing_distributionAlgorithm
  → Requests sind gleichmaessig ueber Zeitfenster verteilt

test_buildDailyNudgeRequests_allSevenCoachGapTexts_represented
  → Alle 7 CoachGap-Typen kommen in den Requests vor

test_buildDailyNudgeRequests_windowAlreadyPassed_returnsEmpty
  → Zeitfenster liegt in der Vergangenheit → leeres Array

test_buildDailyNudgeRequests_maxCountZero_returnsEmpty
  → maxCount: 0 → leeres Array

test_buildDailyNudgeRequests_maxCountOne_returnsSingleRequest
  → maxCount: 1 → genau ein Request
```

---

### Phase 3: FocusBlockActionServiceTests.swift (10-12 Tests)

**Setup:** `@MainActor`, `ModelContainer(isStoredInMemoryOnly: true)`, `MockEventKitRepository`.

**completeTask (6-7 Tests):**
```
test_completeTask_happyPath_returnsCompleted
  → Normaler Task → .completed Ergebnis

test_completeTask_happyPath_marksTaskDone
  → Task.isCompleted wird true gesetzt

test_completeTask_happyPath_updatesFocusBlock
  → MockEventKitRepository.updateFocusBlock wird aufgerufen

test_completeTask_blockerTask_returnsCompletedWithoutChanges
  → blockerTaskID != nil → .completed ohne Task-/Block-Aenderung

test_completeTask_clearsDependentTasksBlocker
  → Abhaengige Tasks erhalten blockerTaskID = nil

test_completeTask_recurringTask_createsNextInstance
  → Wiederkehrender Task → RecurrenceService erzeugt naechste Instanz

test_completeTask_updatesTaskTimes
  → taskTimes Dictionary wird mit Zeiterfassung aktualisiert
```

**skipTask (3-4 Tests):**
```
test_skipTask_multipleRemaining_reordersQueue
  → Queue wird neu sortiert, gibt .skipped zurueck

test_skipTask_lastRemaining_autoCompletes
  → Letzter Task in Queue → .skippedLast zurueck

test_skipTask_updatesTaskTimes
  → taskTimes wird auch beim Skippen erfasst
```

---

### MockEventKitRepository Erweiterung

**Neue Properties:**
```swift
var updateFocusBlockCalled: Bool
var updateFocusBlockCallCount: Int
var lastUpdatedEventID: String?
var lastUpdatedTaskIDs: [String]?
var lastUpdatedCompletedIDs: [String]?
var lastUpdatedTaskTimes: [String: TimeInterval]?
```

Implementierung folgt dem bestehenden Muster von `deleteCalendarEventCalled` / `lastDeletedEventID`.

---

### Test-Konventionen (projektweite Standards)

```swift
@MainActor
final class GapFinderTests: XCTestCase {
    // GIVEN / WHEN / THEN Struktur
    // Keine sleep() — stattdessen waitForExistence(timeout:) bei async
    // Naming: test_[subject]_[scenario]_[expectation]
}
```

## Expected Behavior

- **Input:** Bestehende Services ohne Produktionscode-Aenderung
- **Output:** 3 neue Test-Dateien + 1 erweiterte Mock-Datei, alle Tests gruen
- **Side effects:** Keine Produktionslogik wird veraendert. MockEventKitRepository erhaelt neue Properties, die bestehende Tests nicht beeinflussen (nil/false defaults).

## Known Limitations

- `AppSettings.shared` ist Singleton — Tests koennen Einstellungen nicht isoliert ueberschreiben. Tests verwenden Defaults und sind read-only.
- `UNUserNotificationCenter` ist nicht mockbar — deshalb ausschliesslich `build*()` Methoden testen, keine `schedule*()`/`cancel*()` Methoden.
- Ziel ist kritische Pfad-Abdeckung, nicht 100% Code-Coverage.

## Changelog

- 2026-03-16: Initial spec created
