# Unified Calendar View

## Status: In Arbeit (Bug 68 — Spec war unvollstaendig)

## Quelle

Hennings Original-Beschreibung (Session 77dfd7a4, Zeile 77):

> Unter iOS ist es zu schmal, um Blox und Task nebeneinander anzuzeigen, es muss untereinander sein.
> Oben die Tasks die bereits zugewiesen wurden und die direkt Handles zum Verschieben haben.
> Unten die "NextUp" Tasks.
> Neu: Es gibt eine aufklappbare Sektion "mehr" in der man auch auf alle anderen Tasks zugreifen kann.
> Ein Klick auf das "Pfeilnachoben" Icon fuegt beliebige Tasks dem FokusBlox hinzu (immer am Ende).
> Unter macOS liegen die Fensterbereiche, die unter iOS uebereinander liegen, nebeneinander.

## Zusammenfassung

Tap auf einen FocusBlock oeffnet ein Full-Screen Sheet zur Task-Zuweisung.
Gleiche Komponente (`FocusBlockTasksSheet`) auf iOS und macOS.
- **iOS:** Sektionen untereinander (vertikal, ScrollView)
- **macOS:** Sektionen nebeneinander (horizontal, HSplitView)

## FocusBlockTasksSheet — Aufbau

### Sektion 1: Zugewiesene Tasks
- Tasks die bereits dem Block zugewiesen sind
- Drag-Handles zum Umsortieren (onMove)
- Swipe-to-Remove (onDelete)
- Leerer Zustand: "Keine Tasks im Block" mit Hinweis

### Sektion 2: Next Up Tasks
- Alle Tasks mit `isNextUp == true` die NICHT im Block sind
- Jeder Task hat arrow.up.circle Button zum Zuweisen
- Tap auf Button → Task wird dem Block hinzugefuegt (am Ende)
- Immer sichtbar (auch wenn leer: "Keine Next Up Tasks")

### Sektion 3: Alle Tasks (aufklappbar)
- **NEU** — fehlte in der bisherigen Implementation
- Aufklappbare Sektion (DisclosureGroup oder similar)
- Zeigt ALLE unerledigten, nicht-zugewiesenen Tasks
- Filter: `!isCompleted && !isNextUp && !blockTaskIDs.contains(id)`
- Gleicher arrow.up.circle Button zum Zuweisen
- Tap → Task wird dem Block hinzugefuegt (am Ende)

### Sheet-Konfiguration
- **Full-Screen:** `.presentationDetents([.large])` (NICHT `.medium`)
- Accessibility-Identifier: `"focusBlockTasksSheet"`
- NavigationStack mit "Tasks im Block" Titel + "Fertig" Button

## Plattform-Layout

### iOS
```
┌─────────────────────────┐
│ Tasks im Block    Fertig│
├─────────────────────────┤
│ ☰ Task A         ✕     │
│ ☰ Task B         ✕     │
├─────────────────────────┤
│ Next Up (3)             │
│ Task C            ↑     │
│ Task D            ↑     │
├─────────────────────────┤
│ ▶ Alle Tasks (12)      │
│   Task E          ↑    │
│   Task F          ↑    │
│   ...                   │
└─────────────────────────┘
```

### macOS
```
┌──────────────────┬──────────────────┐
│ Tasks im Block   │ Next Up (3)      │
│ ☰ Task A    ✕   │ Task C      ↑   │
│ ☰ Task B    ✕   │ Task D      ↑   │
│                  ├──────────────────┤
│                  │ ▶ Alle Tasks (12)│
│                  │   Task E    ↑   │
│                  │   Task F    ↑   │
└──────────────────┴──────────────────┘
```

## Aenderungen (Bug 68 Fix)

### 1. FocusBlockTasksSheet.swift (Shared, Sources/)
- NEU: Parameter `allTasks: [PlanItem]`
- NEU: Sektion 3 "Alle Tasks" als DisclosureGroup
- AENDERUNG: `.presentationDetents([.large])` statt `[.medium, .large]`
- AENDERUNG: Leere Next Up Section sichtbar (mit "Keine Next Up Tasks")
- NEU: `#if os(iOS)` vertikales Layout / `#if os(macOS)` horizontales Layout (HSplitView)

### 2. BlockPlanningView.swift (iOS)
- AENDERUNG: `allTasks` an FocusBlockTasksSheet uebergeben (bereits als @State vorhanden)
- Filter fuer Sektion 3: `allTasks.filter { !$0.isCompleted && !$0.isNextUp && !blockTaskIDs.contains($0.id) }`

### 3. MacPlanningView.swift (macOS)
- NEU: `@State private var blockForTasks: FocusBlock?`
- NEU: `.sheet(item: $blockForTasks) { FocusBlockTasksSheet(...) }`
- AENDERUNG: `onTapBlock` setzt `blockForTasks = block` (statt `onNavigateToBlock`)
- NEU: `allTasks` laden und an Sheet uebergeben

### 4. Dead Code Cleanup
- BlockPlanningView: `existingBlocksSection` entfernen (Dead Code, nie aufgerufen)

## Was sich NICHT aendert
- EditFocusBlockSheet, CreateFocusBlockSheet — unveraendert
- Timeline-Rendering — unveraendert
- Datenmodell, EventKit-Integration — unveraendert
- Gear-Icon Tap → EditFocusBlockSheet — unveraendert

## Seiteneffekte
- MacPlanningView braucht Zugang zu Tasks (SyncEngine/ModelContext)
- `onNavigateToBlock` Callback in MacPlanningView wird durch Sheet ersetzt
- ContentView.swift (macOS): `onNavigateToBlock` Parameter entfaellt
- Keine neuen Permissions, keine AppStorage-Keys
