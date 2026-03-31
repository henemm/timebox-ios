# BUG_119 — ReviewEventIntegrationTests: Calendar-Events nicht kategorisiert

## Problem

6 Unit Tests in 2 Dateien schlagen fehl, weil sie den veralteten Notes-basierten Category-Mechanismus nutzen. Seit BUG_63 (2026-03-02) werden Categories in UserDefaults gespeichert, nicht in Event-Notes.

## Root Cause

`makeEvent(category: "income")` schreibt `notes: "category:income"`, aber `CalendarEvent.category` liest aus `UserDefaults["calendarEventCategories"][calendarItemIdentifier]`. UserDefaults wird nie beschrieben → `category` ist immer `nil`.

## Betroffene Dateien

| Datei | Betroffene Tests |
|-------|-----------------|
| `FocusBloxTests/ReviewEventIntegrationTests.swift` | `testCategoryStatsIncludesCalendarEvents`, `testCategoryStatsExcludesFocusBlockEvents`, `testCategoryStatsCombinesTasksAndEvents` |
| `FocusBloxTests/ReviewDailyCategoryTests.swift` | `testDailyCategoryStatsIncludesCalendarEvents`, `testDailyCalendarEventFiltering`, `testMacOSCalendarEventFiltering` |

## Fix

### 1. ReviewEventIntegrationTests.swift

- `makeEvent()` Helper: Nach Event-Erstellung Category in UserDefaults schreiben (wenn `category != nil`)
- `makeFocusBlockEvent()` Helper: Gleiche Anpassung
- `tearDown()` hinzufuegen: `UserDefaults.standard.removeObject(forKey: "calendarEventCategories")`

### 2. ReviewDailyCategoryTests.swift

- Jeden Test der `notes: "category:X"` nutzt: UserDefaults-Mapping vor Assertion setzen
- `tearDown()` hinzufuegen: UserDefaults aufraeumen

### Kein Produktionscode betroffen

Der Fix aendert ausschliesslich Test-Dateien. `ReviewStatsCalculator` und `CalendarEvent` bleiben unveraendert.

## Acceptance Criteria

- Alle 6 Tests in beiden Dateien sind GRUEN
- `./scripts/sim.sh unit ReviewEventIntegrationTests` → PASS
- `./scripts/sim.sh unit ReviewDailyCategoryTests` → PASS
- Keine UserDefaults-Leaks zwischen Tests (tearDown)
