# Tasks: Unified Block-Detail Navigation

**Geschaetzter Aufwand:** Klein (3 Dateien, netto ca. -60 LoC)

---

## Implementierungs-Checkliste

### Phase 1: Shared State einrichten

- [ ] **ContentView.swift:** `@State private var sharedDate = Date()` hinzufuegen
- [ ] **ContentView.swift:** `@State private var highlightedBlockID: String?` hinzufuegen
- [ ] **ContentView.swift:** `MacPlanningView` mit `selectedDate:` und `onNavigateToBlock:` aufrufen
- [ ] **ContentView.swift:** `MacAssignView` mit `selectedDate:` und `highlightedBlockID:` aufrufen
- [ ] **ContentView.swift:** Navigation-Callback: `selectedSection = .assign` + `highlightedBlockID = blockID`

### Phase 2: MacPlanningView aufraemen

- [ ] **MacPlanningView.swift:** `selectedDate` von `@State` zu `@Binding` aendern
- [ ] **MacPlanningView.swift:** `onNavigateToBlock: (String) -> Void` Parameter hinzufuegen
- [ ] **MacPlanningView.swift:** `blockForTasks` State entfernen
- [ ] **MacPlanningView.swift:** `showTaskPicker` State entfernen
- [ ] **MacPlanningView.swift:** `blockForAddingTask` State entfernen
- [ ] **MacPlanningView.swift:** `.sheet(item: $blockForTasks)` entfernen (FocusBlockTasksSheet)
- [ ] **MacPlanningView.swift:** `.sheet(isPresented: $showTaskPicker)` entfernen (TaskPickerSheet)
- [ ] **MacPlanningView.swift:** `TaskPickerSheet` struct Definition entfernen
- [ ] **MacPlanningView.swift:** `tasksForBlock()` Funktion entfernen
- [ ] **MacPlanningView.swift:** `reorderTasksInBlock()` Funktion entfernen
- [ ] **MacPlanningView.swift:** `removeTaskFromBlock()` Funktion entfernen
- [ ] **MacPlanningView.swift:** `onTapBlock` Callback: `onNavigateToBlock(block.id)` aufrufen
- [ ] **MacPlanningView.swift:** Preview anpassen (neue Parameter)

### Phase 3: MacAssignView erweitern

- [ ] **MacAssignView.swift:** `selectedDate` von `@State` zu `@Binding` aendern
- [ ] **MacAssignView.swift:** `@Binding var highlightedBlockID: String?` hinzufuegen
- [ ] **MacAssignView.swift:** init-Parameter anpassen
- [ ] **MacAssignView.swift:** ScrollViewReader um ScrollView wrappen
- [ ] **MacAssignView.swift:** `.id(block.id)` auf MacFocusBlockCard setzen
- [ ] **MacAssignView.swift:** `.onChange(of: highlightedBlockID)` mit scrollTo implementieren
- [ ] **MacAssignView.swift:** highlightedBlockID nach Scroll zuruecksetzen (Delay)
- [ ] **MacAssignView.swift:** Preview anpassen (neue Parameter)

### Phase 4: Drop-Lag Optimierung

- [ ] **MacAssignView.swift:** `assignTaskToBlock` -- lokales `focusBlocks` Array sofort aktualisieren
- [ ] **MacAssignView.swift:** EventKit-Speicherung im Hintergrund (ohne `await loadFocusBlocks()` zu blockieren)
- [ ] **MacAssignView.swift:** Bei EventKit-Fehler: Rollback des lokalen Updates + Fehlermeldung

### Phase 5: Validierung

- [ ] macOS Build kompiliert ohne Fehler
- [ ] iOS Build kompiliert ohne Fehler (keine Regression)
- [ ] Tap auf FocusBlock im Planen-Tab wechselt zum Zuweisen-Tab
- [ ] Datum bleibt synchron beim Tab-Wechsel
- [ ] Zuweisen-Tab scrollt zum richtigen Block
- [ ] Drag&Drop im Planen-Tab funktioniert weiterhin
- [ ] Drag&Drop im Zuweisen-Tab funktioniert weiterhin
- [ ] EditFocusBlockSheet funktioniert weiterhin (unveraendert)

---

## Dateien-Uebersicht

| Datei | Aktion | Delta (ca.) |
|-------|--------|-------------|
| `FocusBloxMac/ContentView.swift` | MODIFY | +10 / -3 |
| `FocusBloxMac/MacPlanningView.swift` | MODIFY | +8 / -95 |
| `FocusBloxMac/MacAssignView.swift` | MODIFY | +25 / -5 |
| **Gesamt** | | **+43 / -103 = netto -60** |

Keine neuen Dateien. Keine geloeschten Dateien.
