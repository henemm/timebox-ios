# Unified Calendar View (Phase 1)

## Status: Approved

## Zusammenfassung

Zwei separate Tabs ("Blöcke" + "Zuordnen") werden zu einem einzigen "Blox"-Tab verschmolzen.
Timeline bleibt wie bisher, aber wenn man auf einen Block tippt, öffnet sich ein erweitertes Sheet
das SOWOHL die zugewiesenen Tasks zeigt ALS AUCH Next-Up-Tasks zum Hinzufügen anbietet.

## Änderungen

### 1. MainTabView.swift — Tab entfernen
- TaskAssignmentView Tab entfernen (5→4 Tabs)
- Tab-Label "Blöcke" → "Blox" (bereits korrekt)

### 2. BlockPlanningView.swift — Assign-Logik integrieren
- `assignTaskToBlock()` aus TaskAssignmentView übernehmen (EventKit + SyncEngine)
- `removeTaskFromBlock()` erweitern um SyncEngine-Aufrufe (assignedFocusBlockID + nextUp)
- `nextUpTasks` computed property für nicht-zugewiesene Tasks
- Sheet-Aufruf erweitern: nextUpTasks + onAssignTask an FocusBlockTasksSheet übergeben
- Icon in TimelineFocusBlockRow: "ellipsis" → "gearshape"

### 3. FocusBlockTasksSheet.swift — Next-Up-Sektion
- Neue Parameter: `nextUpTasks`, `onAssignTask`
- Oberer Bereich: Zugewiesene Tasks (bestehendes onMove + onDelete)
- Unterer Bereich: "Next Up" Section mit arrow.up.circle Button
- Tap auf Arrow-Up → Task wird dem Block zugewiesen

## Was sich NICHT ändert
- EditFocusBlockSheet, CreateFocusBlockSheet — unverändert
- macOS Views — keine Änderung
- TaskAssignmentView.swift — bleibt als Datei, wird nur nicht mehr referenziert
- Datenmodell, EventKit-Integration — keine Änderung
