# Bug 68 Analyse: FocusBlock View-Umbau — Tap Detail fehlt

## Agenten-Ergebnisse Zusammenfassung

5 parallele Investigate-Agenten + 1 Devil's Advocate. Ergebnisse:

### Agent 1 (History)
- Commit `4861e2f` (3. Maerz) hat Zuordnen-Tab entfernt, Task-Zuweisung in Block-Sheet verschoben
- iOS: Umbau komplett (4 Tabs, FocusBlockTasksSheet refactored)
- macOS: NIE vereinheitlicht — MacPlanningView + MacAssignView immer noch separat

### Agent 2 (Datenfluss)
- **iOS:** Tap-Chain ist vollstaendig verdrahtet:
  - `TimelineFocusBlockRow.onTapGesture` (L1155) → `onTapBlock()` (L1120)
  - → `TimelineHourRow.onTapBlock(block)` (L1052/1021)
  - → `BlockPlanningView: blockForTasks = block` (L138)
  - → `.sheet(item: $blockForTasks) { FocusBlockTasksSheet(...) }` (L96-111)
- **macOS:** Tap → `onNavigateToBlock(block.id)` → Wechsel zu Assign-Tab

### Agent 3 (Schreiber)
- iOS hat 4 `.sheet(item:)` Modifier am NavigationStack (L68, 76, 87, 96)
- macOS MacPlanningView hat KEIN `blockForTasks` — nur `blockToEdit`
- MacAssignView hat KEINE Tap-Handler — nur Drag & Drop

### Agent 4 (Szenarien)
- iOS Timeline: Block-Tap → FocusBlockTasksSheet, Gear-Tap → EditFocusBlockSheet
- macOS Timeline: Tap → navigiert zu Assign-Tab
- macOS Assign: Kein Tap — nur Drag & Drop

### Agent 5 (Blast Radius)
- MacAssignView ist KEIN Dead Code — aktiv in Sidebar-Navigation
- Blast Radius: Klein (2-4 Files, ~30 LoC)

### Devil's Advocate Challenge (Verdict: LUECKEN → eingearbeitet)

Drei Luecken identifiziert und nachgeprueft:

1. **ExistingBlocksSection (L208-250):** Definiert `onTapGesture { blockToEdit = block }` (oeffnet Edit-Sheet statt Tasks-Sheet). **NACHGEPRUEFT: DEAD CODE** — `existingBlocksSection` wird nirgends im View-Body aufgerufen. Kein Einfluss auf den Bug.

2. **XCTSkip in UI Tests:** `UnifiedCalendarViewUITests` hat 5x `XCTSkip` — Tests ueberspringen sich wenn keine echten FocusBlocks vorhanden. Tests beweisen NICHTS auf CI/Simulator. **BESTAETIGT:** iOS-Flow muss unabhaengig verifiziert werden.

3. **MacAssignView isPast-Filter (L192):** `.filter { !$0.isPast }` filtert vergangene Blocks heraus. Wenn ein past Block in MacPlanningView getappt wird, navigiert es zum Assign-Tab aber der Block ist dort nicht sichtbar. **BESTAETIGT:** Edge Case der ein stilles Versagen verursacht.

## Hypothesen (aktualisiert nach Challenge)

### H1: iOS funktioniert KORREKT im Code — Bug nur auf macOS (Wahrscheinlichkeit: HOCH)

**Beweis DAFUER:**
- Komplette Tap-Chain von Gesture bis Sheet ist verdrahtet (6 Stationen, alle verifiziert)
- `blockForTasks` → `.sheet(item:)` → `FocusBlockTasksSheet` ist Standard-SwiftUI-Pattern
- `existingBlocksSection` ist Dead Code → nur Timeline-Tap ist aktiv → korrekt verdrahtet
- Commit `4861e2f` zeigt +53 LoC in BlockPlanningView — alles fuer Task-Assignment-Flow

**Beweis DAGEGEN:**
- Bug wurde nach Commit gemeldet
- UI Tests sind wertlos (XCTSkip) → kein automatischer Beweis
- 4 `.sheet(item:)` Modifier (theoretisches SwiftUI-Risiko, aber unwahrscheinlich auf iOS 26)

### H2: macOS hat ZWEI separate Probleme (Wahrscheinlichkeit: HOCH)

**Problem A: Kein Tasks-Sheet**
- MacPlanningView hat kein `blockForTasks` und keinen `.sheet` fuer FocusBlockTasksSheet
- Tap → Tab-Wechsel zu Assign statt inline Sheet
- Assign-Tab hat nur Drag & Drop, kein Tap-to-Assign

**Problem B: isPast-Filter im Assign-Tab**
- Vergangene Blocks werden in MacAssignView herausgefiltert (L192)
- `highlightedBlockID` zeigt dann auf nichts → stilles Versagen
- Edge Case: User tippt vergangenen Block in Planning → Assign-Tab zeigt ihn nicht

### H3: iOS Sheet-Modifier-Konflikt (Wahrscheinlichkeit: NIEDRIG)
- 4 `.sheet(item:)` auf demselben NavigationStack (L68, 76, 87, 96)
- `.sensoryFeedback` steht zwischen Sheet #3 und #4 (L95)
- iOS 26 / SwiftUI 7 sollte das koennen, aber kein Beweis vorhanden

## Wahrscheinlichste Ursache

**Der Bug ist ein macOS-Problem. iOS funktioniert wahrscheinlich korrekt.**

1. **iOS:** Tap-Chain vollstaendig verdrahtet. Muss per UI Test verifiziert werden (aktuelle Tests sind wertlos wegen XCTSkip).

2. **macOS:** Keine inline Task-Zuweisung. Tab-Wechsel zu Assign statt Sheet. Vergangene Blocks unsichtbar nach Navigation. Zwei separate Views statt einer einheitlichen.

## Empfohlener Fix

### iOS: Nur Verifikation
- Bestehende UI Tests fixen (XCTSkip durch MockData ersetzen)
- Neuen Test: Block-Tap → FocusBlockTasksSheet oeffnet sich

### macOS: Tasks-Sheet hinzufuegen
- `MacPlanningView` bekommt `blockForTasks` State + `.sheet(item:)` wie iOS
- Tap auf Block → FocusBlockTasksSheet oeffnet sich (gleich wie iOS)
- `onNavigateToBlock` Callback entfernen oder als sekundaere Aktion behalten

### macOS: Dead Code / Cleanup
- `existingBlocksSection` in BlockPlanningView ist Dead Code → aufraemen
- MacAssignView pruefen ob noch gebraucht nach Sheet-Hinzufuegung

## Blast Radius

- **macOS Fix:** MacPlanningView.swift (~20 LoC)
- **iOS Verifikation:** UnifiedCalendarViewUITests.swift (~10 LoC)
- **Dead Code Cleanup:** BlockPlanningView.swift (L208-250 entfernen)
- Gesamt: 3 Dateien, ~50 LoC
- Keine Architektur-Aenderungen, keine neuen Dependencies
