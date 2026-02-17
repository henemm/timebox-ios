# Unified Block-Detail Navigation

**Modus:** AENDERUNG
**Datum:** 2026-02-10
**Status:** Geplant
**Kategorie:** Support Feature

---

## Was und Warum

### Problem

1. **Tap auf FocusBlock im Planen-Tab ist kaputt:** Oeffnet FocusBlockTasksSheet, aber `tasksForBlock()` sucht nur in `nextUpTasks`. Tasks die bereits zugewiesen wurden haben `isNextUp = false` und erscheinen nicht.
2. **Doppelte Funktionalitaet:** Planen-Tab hat eigene Task-Zuweisung (Sheets), obwohl der Zuweisen-Tab das besser kann (Drag&Drop, Reorder, Remove).
3. **Datum nicht synchron:** Jeder Tab hat eigenen `selectedDate` State. Wechsel zwischen Tabs verliert den Kontext.
4. **Drop-Lag:** Nach jedem Drop wird ein voller EventKit-Reload gemacht.

### Loesung

- Tap auf FocusBlock im Planen-Tab navigiert zum Zuweisen-Tab
- Datum wird als Binding von ContentView geteilt
- FocusBlockTasksSheet und TaskPickerSheet werden aus MacPlanningView entfernt
- Optimistisches UI-Update statt vollem Reload nach Drop

### User-Nutzen

Statt einer kaputten Sheet-Ansicht bekommt der User einen nahtlosen Uebergang zum Zuweisen-Tab, wo er alle Funktionen hat (Drag&Drop, Entfernen, Umsortieren). Das Datum bleibt synchron, der Kontext geht nicht verloren.

---

## Aktueller Zustand

### MacPlanningView.swift (648 LoC)
- `@State private var selectedDate` -- eigener Date-State
- `@State private var blockForTasks: FocusBlock?` -- Sheet-Trigger
- `@State private var showTaskPicker` -- Sheet-Trigger
- `@State private var blockForAddingTask: FocusBlock?` -- Hilfs-State
- `.sheet(item: $blockForTasks)` -- FocusBlockTasksSheet (KAPUTT: nutzt nextUpTasks)
- `.sheet(isPresented: $showTaskPicker)` -- TaskPickerSheet
- `tasksForBlock()` -- sucht nur in nextUpTasks (Bug)
- `reorderTasksInBlock()` -- nur lokal, nicht persistiert
- `removeTaskFromBlock()` -- nur lokal, nicht persistiert
- `onTapBlock` Callback: setzt `blockForTasks = block`

### MacAssignView.swift (458 LoC)
- `@State private var selectedDate` -- eigener Date-State
- Hat BEIDE Queries: `nextUpTasks` UND `allTasks`
- Funktionierende Drag&Drop, Remove, Reorder
- ScrollView mit LazyVStack

### ContentView.swift (597 LoC)
- `@State private var selectedSection: MainSection = .backlog`
- `MacPlanningView()` und `MacAssignView()` ohne Parameter aufgerufen
- Kein Mechanismus fuer programmatischen Tab-Wechsel von Child-Views

---

## Delta (Was aendert sich)

### ContentView.swift
- NEU: `@State private var sharedDate = Date()`
- NEU: `@State private var highlightedBlockID: String?`
- AENDERUNG: `MacPlanningView(selectedDate: $sharedDate, onNavigateToBlock: { blockID in selectedSection = .assign; highlightedBlockID = blockID })`
- AENDERUNG: `MacAssignView(selectedDate: $sharedDate, highlightedBlockID: $highlightedBlockID)`

### MacPlanningView.swift
- AENDERUNG: `selectedDate` wird `@Binding` statt `@State`
- NEU: `let onNavigateToBlock: (String) -> Void` Parameter
- ENTFERNT: `blockForTasks` State Variable
- ENTFERNT: `showTaskPicker` State Variable
- ENTFERNT: `blockForAddingTask` State Variable
- ENTFERNT: `.sheet(item: $blockForTasks)` (FocusBlockTasksSheet)
- ENTFERNT: `.sheet(isPresented: $showTaskPicker)` (TaskPickerSheet struct + Sheet)
- ENTFERNT: `tasksForBlock()` Funktion
- ENTFERNT: `reorderTasksInBlock()` Funktion
- ENTFERNT: `removeTaskFromBlock()` Funktion
- AENDERUNG: `onTapBlock` ruft `onNavigateToBlock(block.id)` auf

### MacAssignView.swift
- AENDERUNG: `selectedDate` wird `@Binding` statt `@State`
- NEU: `@Binding var highlightedBlockID: String?`
- NEU: ScrollViewReader + `.scrollTo(highlightedBlockID)` + `.onChange(of: highlightedBlockID)`
- NEU: `.id(block.id)` auf MacFocusBlockCard
- AENDERUNG: `assignTaskToBlock` -- optimistisches lokales Update vor EventKit-Speicherung

### FocusBlockTasksSheet.swift
- NICHT GEAENDERT (wird weiterhin von iOS BlockPlanningView genutzt)

---

## Seiteneffekte

- `MacPlanningView` Preview muss angepasst werden (neue Parameter)
- `MacAssignView` Preview muss angepasst werden (neue Parameter)
- TaskPickerSheet struct wird entfernt (nur in MacPlanningView definiert, nicht shared)
- iOS Code ist NICHT betroffen
- Keine AppStorage-Keys geaendert
- Keine neuen Permissions

---

## State Management Entscheidung

**Gewaehlt: Binding-Approach (Lift State to Parent)**

Begruendung:
- Einfachstes SwiftUI-Pattern
- Single Source of Truth in ContentView
- Kein zusaetzlicher ViewModel oder @Environment noetig
- Nur 2 Bindings: `selectedDate` + `highlightedBlockID`
- Skaliert gut (weitere Tabs koennten spaeter auch das Datum teilen)

Verworfen:
- `@AppStorage`: Unnoetig persistent, Date-Serialisierung komplex
- Shared ViewModel: Over-Engineering fuer 2 Properties
- `@Environment`: Zu viel Boilerplate fuer simple Werte
