# Bug 44: Review Tab - Kategorie-Breakdown in Tagesansicht + Bugfixes

## Problem

Der Review Tab hat 4 Probleme:

1. **iOS Bug**: `DailyReviewView.loadData()` nutzt `syncEngine.sync()` das erledigte Tasks rausfiltert - Task-Liste unvollstaendig
2. **iOS Feature**: Tages-View zeigt keine Kategorie-Zeitverteilung (nur im Wochen-View vorhanden)
3. **macOS Bug**: Tasks werden nach `createdAt` gefiltert statt `completedAt` - falsche Zuordnung zum Tag
4. **macOS Feature**: Tages-View zeigt nur flache Task-Liste, keine Kategorie-Aufschluesselung

## Root Cause

### iOS (DailyReviewView.swift)
- Zeile 468: `allTasks = try await syncEngine.sync()` - `sync()` ruft `fetchIncompleteTasks()` auf
- Zeile 130-138: Tages-View rendert nur `dailyStatsHeader` + `blocksSection`, nicht `categoryStatsSection`

### macOS (MacReviewView.swift)
- Zeile 66: `task.createdAt >= startOfToday` statt `task.completedAt`
- Zeile 103-165: `DayReviewContent` hat keine Kategorie-Balken

## Fix

### iOS DailyReviewView.swift

**Fix 1:** `loadData()` - Ersetze `syncEngine.sync()` durch direkten `FetchDescriptor<LocalTask>()`:
```swift
let descriptor = FetchDescriptor<LocalTask>()
let localTasks = try modelContext.fetch(descriptor)
allTasks = localTasks.map { PlanItem(localTask: $0) }
```

**Fix 2:** Tages-View - Fuege `categoryStatsSection` nach `blocksSection` ein. Dazu:
- Neue computed property `dailyCategoryStats` (identisch zu `categoryStats`, aber mit `todayBlocks` statt `weekBlocks`)
- Neue computed property `todayCalendarEvents` (Filter `calendarEvents` auf heute)
- Einbindung der bestehenden `categoryStatsSection` (parametrisiert fuer daily/weekly)

### macOS MacReviewView.swift

**Fix 3:** `todayTasks` Property - Ersetze `task.createdAt >= startOfToday` durch `task.completedAt`:
```swift
return completedTasks.filter { task in
    guard let completedAt = task.completedAt else { return false }
    return completedAt >= startOfToday
}
```

Analog fuer `weekTasks`:
```swift
return completedTasks.filter { task in
    guard let completedAt = task.completedAt else { return false }
    return completedAt >= startOfWeek
}
```

**Fix 4:** `DayReviewContent` - Fuege Kategorie-Zeitverteilung hinzu:
- Uebergib `calendarEvents` und `statsCalculator` an `DayReviewContent`
- Berechne categoryStats analog zu `WeekReviewContent`
- Zeige Kategorie-Balken unterhalb der Task-Liste

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `Sources/Views/DailyReviewView.swift` | loadData fix + dailyCategoryStats + UI Einbindung |
| `FocusBloxMac/MacReviewView.swift` | completedAt filter + DayReviewContent Kategorie-Balken |

## Testplan

### Unit Tests (FocusBloxTests)
1. Test: `syncEngine.sync()` wird NICHT mehr in DailyReviewView verwendet (indirekt ueber Datenfluss)
2. Test: `ReviewStatsCalculator.computeCategoryMinutes()` funktioniert mit tages-gefilterten Events

### UI Tests
1. iOS: Tages-View zeigt "Zeit pro Kategorie" Sektion
2. macOS: Tages-View zeigt Kategorie-Balken

## Scope

- 2 Dateien
- ~120 LoC Aenderungen
- Keine neuen Models oder Dependencies
