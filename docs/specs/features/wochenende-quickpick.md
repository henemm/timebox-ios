---
entity_id: wochenende-quickpick
type: feature
created: 2026-05-03
updated: 2026-05-03
status: draft
version: "1.0"
tags: [backlog, postpone, quickpick, ios, macos]
---

# Feature — "Dieses Wochenende" als Quick-Pick im Verschieben-Menü

## Approval

- [ ] Approved

## Purpose

Erweitert das Verschieben-Menü um einen vierten Quick-Pick "Dieses Wochenende". Setzt `dueDate` auf den nächsten Samstag, 09:00 — analog Apple-Reminders-Standard.

## Source

- **Files:** `Sources/Views/BacklogView.swift` (iOS), `FocusBloxMac/ContentView.swift` (macOS), `Sources/Models/LocalTask.swift` (Helper)
- **Identifier:** `weekendMenuButton`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask.postpone(_:to:context:)` | function | Bestehende Methode aus #293, wird wiederverwendet |
| `LocalTask.dueDate` | model field | Wird gesetzt auf berechnetes Date |
| `Calendar.current` | system | Wochentag-Berechnung |

## Implementation Details

### Neuer Helper in `Sources/Models/LocalTask.swift`

```swift
static func nextSaturdayAt9(from now: Date = Date()) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    let weekday = calendar.component(.weekday, from: today)  // 1=So, 7=Sa
    let daysUntilSat: Int
    if weekday == 7 { daysUntilSat = 7 }       // heute Sa: nächster Sa (in 7 Tagen)
    else if weekday == 1 { daysUntilSat = 6 }  // heute So: nächster Sa (in 6 Tagen)
    else { daysUntilSat = 7 - weekday }        // Mo–Fr: kommender Sa
    let nextSat = calendar.date(byAdding: .day, value: daysUntilSat, to: today)!
    return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextSat)!
}
```

### iOS — `Sources/Views/BacklogView.swift`

In `postponeMenu(for:)` einen Button zwischen "Morgen" und "Nächste Woche":

```swift
Button {
    let target = LocalTask.nextSaturdayAt9()
    LocalTask.postpone(item, to: target, context: modelContext)
} label: {
    Label("Dieses Wochenende", systemImage: "calendar")
}
.accessibilityIdentifier("weekendMenuButton")
```

### macOS — `FocusBloxMac/ContentView.swift`

Analog im Mac-Menü (`singleTaskContextMenuItems`):

```swift
Button {
    let target = LocalTask.nextSaturdayAt9()
    LocalTask.postpone(task, to: target, context: modelContext)
} label: {
    Label("Dieses Wochenende", systemImage: "calendar")
}
.accessibilityIdentifier("weekendMenuButton")
```

### Menü-Reihenfolge (neu, beide Plattformen)

1. Morgen
2. **Dieses Wochenende** ← NEU
3. Nächste Woche
4. Eigenes Datum...

## Expected Behavior

- **Input:** Nutzer wählt "Dieses Wochenende" im Verschieben-Untermenü
- **Output:** `task.dueDate` ist gesetzt auf nächsten Samstag 09:00 (lokale Zeitzone)
- **Side effects:** `rescheduleCount += 1`, `modifiedAt = Date.now`, `context.save()`, `taskDataChanged`-Notification (alles via `postpone(_:to:context:)`)

## Acceptance Criteria

| Nr | Kriterium |
|----|-----------|
| AC-1 | Verschieben-Untermenü zeigt "Dieses Wochenende" zwischen "Morgen" und "Nächste Woche" |
| AC-2 | `nextSaturdayAt9` liefert korrektes Datum für jeden Wochentag (3 Test-Cases: Mo, Fr, Sa) |
| AC-3 | An einem **Mittwoch** liefert `nextSaturdayAt9` den kommenden Samstag (in 3 Tagen), 09:00 |
| AC-4 | An einem **Samstag** liefert `nextSaturdayAt9` den nächsten Samstag (in 7 Tagen), 09:00 |
| AC-5 | An einem **Sonntag** liefert `nextSaturdayAt9` den nächsten Samstag (in 6 Tagen), 09:00 |
| AC-6 | Tap auf "Dieses Wochenende" setzt `task.dueDate` exakt auf nächsten Samstag 09:00 |
| AC-7 | Tap auf "Dieses Wochenende" inkrementiert `rescheduleCount` |
| AC-8 | Auf macOS funktioniert der Eintrag identisch |

## Accessibility Identifiers

| Identifier | Element | Plattform |
|------------|---------|-----------|
| `weekendMenuButton` | Menüeintrag "Dieses Wochenende" | iOS + macOS |

## Test-Hinweise (für Phase 4 / QA-Writer)

### Unit-Tests (`FocusBloxTests/TaskPostponeTests.swift`)

- `test_nextSaturdayAt9_fromWednesday` — Datum-Construct: 2026-05-06 (Mi) → Erwartung 2026-05-09 09:00 (Sa)
- `test_nextSaturdayAt9_fromSaturday` — 2026-05-09 (Sa) → 2026-05-16 09:00 (Sa)
- `test_nextSaturdayAt9_fromSunday` — 2026-05-10 (So) → 2026-05-16 09:00 (Sa)

### UI-Test (`FocusBloxUITests/CustomDatePostponeUITests.swift` — erweitert)

- `test_postponeMenu_showsWeekendOption` — Long-Press → Verschieben → `weekendMenuButton.exists` ist true

## Out-of-Scope

- Keine Änderung an bestehenden `postpone(byDays:)` und `postpone(to:)`
- Kein "Heute Abend" oder andere Quick-Picks
- Kein i18n (Deutsch hart-codiert wie auch "Morgen", "Nächste Woche")

## Affected Files

1. `Sources/Models/LocalTask.swift`
2. `Sources/Views/BacklogView.swift`
3. `FocusBloxMac/ContentView.swift`
4. `FocusBloxTests/TaskPostponeTests.swift`
5. `FocusBloxUITests/CustomDatePostponeUITests.swift`

## Changelog

- 2026-05-03: Initial spec
