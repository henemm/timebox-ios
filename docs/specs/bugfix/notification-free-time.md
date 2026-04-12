---
entity_id: notification-free-time
type: bugfix
created: 2026-04-12
updated: 2026-04-12
status: draft
version: "1.0"
tags: [notifications, coach, eventkit, gapfinder]
---

# Bug #208: Morning-Notification zeigt immer "Du hast 120 Min frei"

## Approval

- [ ] Approved

## Purpose

Die Morning-Notification zeigt immer denselben Text mit hardcoded 120 freien Minuten, weil `SmartNotificationEngine.precomputeNotificationContent` die Werte `freeMinutes: 120`, `meetingCount: 0` und `focusMinutes: 0` fest eingebaut hatte statt echte Kalender-Daten zu verwenden. Dieser Fix integriert GapFinder und EventKitRepository in die Notification-Pipeline — analog zu OrganizeMyDayIntent und CoachView, die GapFinder bereits korrekt nutzen.

## Source

- **File:** `Sources/Services/SmartNotificationEngine.swift`
- **Identifier:** `static func precomputeNotificationContent(context:eventKitRepo:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `GapFinder` | class | Berechnet freie Zeitslots aus Kalender-Events |
| `EventKitRepositoryProtocol` | protocol | Liefert CalendarEvents und FocusBlocks für einen Tag |
| `NotificationContentService` | service | Baut den finalen Notification-Text aus berechneten Werten |
| `CalendarEvent` | model | Repräsentiert einen Kalender-Eintrag; `isAllDay` wird für meetingCount-Filter genutzt |
| `FocusBlock` | model | Repräsentiert einen Focus-Block; Dauer wird für focusMinutes summiert |
| `MockEventKitRepository` | test double | Simuliert Kalender-Daten in Unit Tests |

## Implementation Details

```
precomputeNotificationContent(context:eventKitRepo:):

1. Kalender-Events und FocusBlocks für heute laden:
   let calendarEvents = (try? eventKitRepo.fetchCalendarEvents(for: today)) ?? []
   let focusBlocks    = (try? eventKitRepo.fetchFocusBlocks(for: today)) ?? []

2. Freie Minuten via GapFinder (min 15min, max 480min Slots):
   let gapFinder  = GapFinder(events: calendarEvents, focusBlocks: focusBlocks, scheduledTasks: [], date: today)
   let freeSlots  = gapFinder.findFreeSlots(minMinutes: 15, maxMinutes: 480)
   let freeMinutes = freeSlots.reduce(0) { $0 + $1.durationMinutes }

3. Meetings zählen (nur Non-All-Day-Events):
   let meetingCount = calendarEvents.filter { !$0.isAllDay }.count

4. Focus-Minuten summieren (Dauer aller FocusBlocks in Minuten):
   let focusMinutes = focusBlocks.reduce(0) { $0 + Int($1.endDate.timeIntervalSince($1.startDate) / 60) }

5. Berechnete Werte an NotificationContentService übergeben
   (statt zuvor hardcoded freeMinutes:120, meetingCount:0, focusMinutes:0)

Graceful Degradation:
- fetchCalendarEvents / fetchFocusBlocks schlagen bei verweigerter Berechtigung fehl
- ?? [] sorgt für leere Arrays → freeMinutes = 0, meetingCount = 0, focusMinutes = 0
- Notification wird trotzdem gebaut (kein Crash), aber ohne Kalender-Details
```

## Expected Behavior

- **Input:** ModelContext mit heutigen Tasks + EventKitRepository mit echten oder gemockten Kalender-Daten
- **Output:** `cachedMorningContent` enthält echte freie Minuten aus GapFinder, nicht "120"; `cachedEveningContent` enthält echte Focus-Minuten, nicht "0"
- **Side effects:** Keine Änderung an anderen Features (CoachView, DayView, OrganizeMyDayIntent bleiben unberührt)

## Known Limitations

- `precomputeNotificationContent` wird im BGAppRefreshTask aufgerufen. Ob EventKit-Fetch im Background-Kontext immer erfolgreich ist, ist abhängig von iOS-Background-Limits. Graceful Degradation über `?? []` fängt Fehler auf.
- `cachedMorningContent` wird für alle 7 geplanten Morning-Notifications der Woche wiederverwendet (7-Tage-Cache). Der Inhalt spiegelt den Stand des letzten BGAppRefresh wider — das ist bekanntes Verhalten und kein Scope dieses Bugs.

## Test Coverage

Datei: `FocusBloxTests/NotificationFreeTimeTests.swift`

| Test | Prüft |
|------|-------|
| `test_morningNotification_usesRealFreeMinutes_notHardcoded120` | Body enthält nicht "120" bei voller Kalender-Belegung |
| `test_morningNotification_usesRealMeetingCount` | Prompt-Builder erhält meetingCount > 0 |
| `test_eveningNotification_usesRealFocusMinutes` | cachedEveningContent reflektiert 90min (30+60) aus FocusBlocks |
| `test_morningNotification_noCalendarAccess_gracefulDegradation` | Kein Crash bei verweigerter Berechtigung, kein hardcoded "120" |

## Changelog

- 2026-04-12: Initial spec created
