# Spec: Bug — macOS Coach Backlog zeigt keine Tasks im Monster-Mode

## Problem
Im Monster-Mode (Coach-Mode) zeigt der macOS Backlog-Tab keine Tasks.

## Root Cause
`.task { refreshTasks() }` und `.onChange(of: cloudKitMonitor.remoteChangeCount)` sind an `backlogView` gebunden (ContentView.swift:566-580). Bei `coachModeEnabled == true` wird `backlogView` nicht gerendert — daher laufen diese Modifier nie. `@State tasks` bleibt `[]`, `visibleTasks` ist leer, `MacCoachBacklogView` bekommt keine Daten.

## Fix

### Aenderung 1: `.task` und `.onChange` von `backlogView` auf NavigationSplitView verschieben

**Datei:** `FocusBloxMac/ContentView.swift`

**Vorher:** `.task { refreshTasks(); cloudKitMonitor.triggerSync() }` und `.onChange(of: cloudKitMonitor.remoteChangeCount)` sind Modifier auf dem VStack in `backlogView` (Zeile 566-580).

**Nachher:** Beide Modifier auf die NavigationSplitView verschieben (nach `.frame(minWidth: 1000, minHeight: 600)`), damit sie IMMER laufen — unabhaengig von `coachModeEnabled`.

### Betroffene Dateien
- `FocusBloxMac/ContentView.swift` — Modifier verschieben (1 Datei)

### Nicht betroffen
- iOS — eigene Datenladung via SyncEngine
- CoachBacklogViewModel — Shared Logic bleibt unveraendert
- MacCoachBacklogView — empfaengt Daten, laed nicht selbst

## Acceptance Criteria
1. macOS Coach Backlog zeigt Tasks wenn Coach-Mode aktiviert ist
2. macOS Normal Backlog funktioniert weiterhin
3. CloudKit-Sync-Refresh funktioniert in beiden Modi
4. Sidebar-Badges zeigen korrekte Zahlen im Coach-Mode

## Scope
- 1 Datei
- ~20 Zeilen verschieben (kein neuer Code)
- Unter 250 LoC Aenderung
