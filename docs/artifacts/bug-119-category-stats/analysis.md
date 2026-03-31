# BUG_119 — ReviewEventIntegrationTests: Calendar-Events nicht kategorisiert

## Symptom

`testCategoryStatsIncludesCalendarEvents` erwartet `stats["income"] == 60` und `stats["learning"] == 30`, bekommt aber `nil`.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- BUG_54: Category-Persistence via Notes + `.futureEvents` Span
- BUG_63: Notes sind read-only bei Events mit Gaesten → Fix: UserDefaults-Mapping mit `calendarItemIdentifier`
- BUG_119 ist der dritte Bug in der Category-Persistenz-Kette

### Agent 2 (Datenfluss-Trace)
- `CalendarEvent.category` (Zeile 61-63) liest aus **UserDefaults** (`calendarEventCategories[calendarItemIdentifier]`)
- `ReviewStatsCalculator.computeCategoryMinutes()` (Zeile 19-20) filtert mit `guard let category = event.category`
- Wenn `category == nil` → Event wird uebersprungen

### Agent 3 (Alle Schreiber)
- Einziger Schreiber: `EventKitRepository.updateEventCategory()` → UserDefaults
- Aufrufer: `BlockPlanningView` (iOS) + `MacPlanningView` (macOS)
- Keine andere Stelle schreibt Categories

### Agent 4 (Szenarien)
- 10 Szenarien identifiziert
- Kritischer Fund: Test erstellt Events mit `notes: "category:\(category)"` — aber Code liest aus UserDefaults, NICHT aus Notes

### Agent 5 (Blast Radius)
- `ReviewStatsCalculator` wird auf iOS + macOS identisch genutzt
- Produktiver Code funktioniert korrekt (UserDefaults-Mapping wird durch User-Interaktion gesetzt)
- Problem ist isoliert auf Test-Setup

## Hypothesen

### Hypothese 1: Test nutzt veralteten Category-Mechanismus (HOCH)

**Beweis DAFUER:**
- Test `makeEvent()` setzt `notes: "category:\(category)"` (Zeile 19-20 in ReviewEventIntegrationTests.swift)
- `CalendarEvent.category` liest aber aus `UserDefaults["calendarEventCategories"][calendarItemIdentifier]` (Zeile 61-63 in CalendarEvent.swift)
- UserDefaults wird im Test NIEMALS beschrieben
- Daher: `event.category` ist IMMER `nil` → Guard in ReviewStatsCalculator schlaegt fehl → stats bleiben leer

**Beweis DAGEGEN:**
- Keiner. Der Code ist eindeutig.

**Wahrscheinlichkeit: HOCH (99%)**

**Ursache der Veralterung:** BUG_63 (Commit 6cf8e8c, 2026-03-02) hat Category-Storage von Notes auf UserDefaults umgestellt. Die Tests wurden danach nicht aktualisiert.

### Hypothese 2: ReviewStatsCalculator ignoriert Calendar-Events generell (NIEDRIG)

**Beweis DAFUER:** Tests schlagen fehl
**Beweis DAGEGEN:** Code in ReviewStatsCalculator Zeile 18-22 iteriert explizit ueber calendarEvents und addiert `durationMinutes`. Die Logik ist korrekt — sie bekommt nur keine kategorisierten Events.

**Wahrscheinlichkeit: NIEDRIG (1%)**

### Hypothese 3: CalendarEvent.category Property ist defekt (NIEDRIG)

**Beweis DAFUER:** Keiner
**Beweis DAGEGEN:** `CalendarCategoryMappingTests.swift` (236 Zeilen, 8+ Tests) validiert die UserDefaults-basierte Category-Zuordnung ausfuehrlich. Diese Tests sind GRUEN.

**Wahrscheinlichkeit: NIEDRIG (0%)**

## Root Cause

**Test-Code nutzt veralteten Notes-basierten Category-Mechanismus, waehrend der Produktions-Code seit BUG_63 UserDefaults nutzt.**

Der Test-Helper `makeEvent()` setzt `notes: "category:\(category)"`, aber `CalendarEvent.category` liest aus `UserDefaults.standard.dictionary(forKey: "calendarEventCategories")`. Da der Test UserDefaults nie beschreibt, ist `event.category` immer `nil`.

## Fix-Ansatz

Test-Helper `makeEvent()` muss nach Event-Erstellung die Category in UserDefaults schreiben:
```swift
UserDefaults.standard.set(
    [event.calendarItemIdentifier: category],
    forKey: "calendarEventCategories"
)
```

Zusaetzlich: `tearDown()` muss UserDefaults aufraeumen um Test-Isolation zu gewaehrleisten.

## Blast Radius

- **Produktiver Code:** Nicht betroffen. `ReviewStatsCalculator` + Views funktionieren korrekt.
- **Andere Tests:** `CalendarCategoryMappingTests` sind unabhaengig und GRUEN.
- **Plattformen:** Fix betrifft nur die Test-Datei, kein Plattform-spezifischer Code.
