# Bug-Analyse: nextUpSortOrder Arithmetic Overflow (macOS)

## Symptom
**Plattform:** macOS
**Aktion:** Swipe auf Task in Liste → "Next Up" waehlen
**Crash:** `Thread 1: Swift runtime failure: arithmetic overflow`
**Stelle:** `FocusBloxMac/ContentView.swift:824` — `var order = maxOrder + 1`

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- Kein fruehrer Bug fuer nextUpSortOrder Overflow bekannt
- `Int.max` Pattern wurde mit Next Up Feature eingefuehrt
- Kein bisheriger Fix-Versuch

### Agent 2: Datenfluss-Trace
- `nextUpSortOrder` ist `Int?` in LocalTask, Default nil
- Wird auf `Int.max` gesetzt in 4 Stellen (als "ans Ende anfuegen")
- macOS `addToNextUp()` liest `.max() ?? 0` und addiert +1
- `moveNextUpTasks()` (Drag-Reorder) ist sicher — renumbered zu 0,1,2...

### Agent 3: Alle Schreiber
- 9 Schreibstellen fuer nextUpSortOrder gefunden
- **4 setzen `Int.max`:** SyncEngine:59, QuickCaptureView:311, QuickCapturePanel:194, MenuBarView:401
- **1 macht `max() + 1`:** ContentView:824 (CRASH-Stelle)
- **1 renumbered sicher:** moveNextUpTasks:852 (0,1,2...)
- **2 setzen nil:** removeFromNextUp, SyncEngine:61-62
- **1 setzt expliziten Index:** updateNextUpSortOrder (SyncEngine:70)

### Agent 4: Szenarien
- Haupt-Szenario: Task bekommt `Int.max` via SyncEngine/QuickCapture → macOS `addToNextUp` liest `max()` = `Int.max` → `+ 1` = OVERFLOW
- iOS ist NICHT betroffen (hat kein `addToNextUp`)
- Zweites Szenario: Mehrfaches `addToNextUp` ohne Reorder koennte akkumulieren, aber erst bei Int.max problematisch

### Agent 5: Blast Radius
- 5 potentiell overflow-anfaellige Stellen
- `sortOrder` in LocalTaskSource hat aehnliches Pattern (aber dort kein `max() + 1`)
- `@Query`-Sort nach nextUpSortOrder funktioniert korrekt mit `Int.max` (nur Addition crasht)

## Hypothesen

### Hypothese 1: Int.max + 1 Overflow (HOHE Wahrscheinlichkeit)
**Beschreibung:** Ein Task hat bereits `nextUpSortOrder = Int.max` (gesetzt via SyncEngine, QuickCapture, oder MenuBar). Wenn macOS `addToNextUp()` aufgerufen wird, findet `compactMap(\.nextUpSortOrder).max()` den Wert `Int.max`. Dann wird `var order = maxOrder + 1` berechnet — Integer Overflow.

**Beweis DAFUER:**
- `SyncEngine.swift:59` setzt explizit `Int.max` bei jedem `updateNextUp(isNextUp: true)`
- `QuickCaptureView.swift:311`, `QuickCapturePanel.swift:194`, `MenuBarView.swift:401` setzen ebenfalls `Int.max`
- `addToNextUp` (ContentView:823-824) macht `max() + 1` OHNE Overflow-Guard
- Swift prueft Arithmetic Overflow im Release-Mode NICHT, aber im Debug-Mode (Xcode Run) SCHON
- Das Crash-Pattern passt exakt: `Int.max + 1` = Overflow

**Beweis DAGEGEN:**
- Keiner. Die Code-Pfade sind eindeutig.

**Wahrscheinlichkeit:** **HOCH (99%)**

### Hypothese 2: Akkumulation durch wiederholtes addToNextUp (NIEDRIGE Wahrscheinlichkeit)
**Beschreibung:** Wiederholtes Hinzufuegen ohne Reorder koennte Werte akkumulieren bis Overflow.

**Beweis DAFUER:**
- `addToNextUp` inkrementiert `order` fuer jede Task in der Schleife
- Theoretisch moeglich bei extremer Nutzung

**Beweis DAGEGEN:**
- Startwert ist immer `max() + 1`, nicht kumulativ ueber Sessions
- Muesste ~9.2 Quintillionen mal aufgerufen werden
- Praktisch unmoeglich

**Wahrscheinlichkeit:** **NIEDRIG (0%)**

### Hypothese 3: Race Condition zwischen Plattformen (NIEDRIGE Wahrscheinlichkeit)
**Beschreibung:** iOS setzt `Int.max` via CloudKit Sync, macOS liest den Wert bevor `moveNextUpTasks` renumbered.

**Beweis DAFUER:**
- CloudKit Sync existiert, iOS und macOS teilen SwiftData Store
- iOS setzt `Int.max` haeufiger (bei jedem updateNextUp)

**Beweis DAGEGEN:**
- Ist Untermenge von Hypothese 1 — egal WER `Int.max` setzt, der Crash entsteht in `addToNextUp`
- Keine echte Race Condition, sondern deterministischer Overflow

**Wahrscheinlichkeit:** **NIEDRIG (ist gleiche Root Cause wie H1)**

## Wahrscheinlichste Ursache

**Hypothese 1: Int.max + 1 Overflow**

Die Root Cause besteht aus ZWEI Problemen:
1. `Int.max` wird als Sentinel-Wert fuer "ans Ende anfuegen" verwendet (4 Stellen)
2. macOS `addToNextUp()` macht `max() + 1` ohne Overflow-Schutz

Beides zusammen ergibt den deterministischen Crash.

## Debugging-Plan

**Nicht noetig** — die Code-Pfade sind eindeutig lesbar:
- `SyncEngine:59` → setzt `Int.max`
- `ContentView:823-824` → liest `max()` = `Int.max`, dann `+ 1` = CRASH

Ein Print-Statement in `addToNextUp` wuerde `maxOrder = 9223372036854775807` zeigen.

## Blast Radius

- **macOS ContentView.addToNextUp** — direkt betroffen (CRASH)
- **SyncEngine.updateNextUp** — setzt `Int.max` (Quelle des Problems)
- **QuickCaptureView** — setzt `Int.max` (Quelle)
- **QuickCapturePanel (macOS)** — setzt `Int.max` (Quelle)
- **MenuBarView (macOS)** — setzt `Int.max` (Quelle)
- **sortOrder in LocalTaskSource** — aehnliches Pattern, aber kein `max() + 1` Zugriff

## Fix-Optionen

### Option A: Overflow-Guard in addToNextUp (Minimal-Fix)
Ersetze `maxOrder + 1` durch sicheren Wert:
```swift
let maxOrder = nextUpTasks.compactMap(\.nextUpSortOrder).max() ?? 0
var order = maxOrder >= Int.max - ids.count ? maxOrder : maxOrder + 1
```
Problem: Behandelt nur Symptom, `Int.max` bleibt als Sentinel.

### Option B: Int.max durch sinnvollen Wert ersetzen (Richtige Loesung)
Ersetze alle 4 `Int.max`-Zuweisungen durch `(existingMax + 1)`:
```swift
// Statt: task.nextUpSortOrder = Int.max
// Besser: Berechne naechsten freien Index
```
Problem: Braucht Zugriff auf bestehende Tasks an jeder Stelle.

### Option C: Hybrid — Guard + Renumber (Pragmatisch)
1. In `addToNextUp`: Wenn `maxOrder >= 10000`, zuerst alle renumbern (0,1,2...)
2. Dann normal `max() + 1`
3. `Int.max`-Stellen optional spaeter bereinigen (Backlog)
