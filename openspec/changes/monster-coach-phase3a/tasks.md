# Tasks: Monster Coach Phase 3a — Intention-basierter Backlog-Filter

> Erstellt: 2026-03-12
> Abhaengigkeit: Proposal genehmigt

---

## Implementierungs-Checkliste

### Phase A: Daten-Modell

- [ ] **A1** — `IntentionOption` in `DailyIntention.swift` um `intentionFilter` computed property erweitern
  - Gibt `IntentionFilterCriteria` zurueck (neues Struct, definiert in derselben Datei)
  - `.survival` gibt Sonderstatus `.noFilter` zurueck
  - `.balance` gibt `.groupByCategory` zurueck (kein Task-Ausschluss)
  - Alle anderen geben `.predicate` mit konkretem PlanItem-Kriterium zurueck

- [ ] **A2** — `IntentionFilterCriteria` enum in `DailyIntention.swift` definieren
  ```
  enum IntentionFilterCriteria {
      case noFilter          // survival
      case groupByCategory   // balance
      case predicate((PlanItem) -> Bool)  // fokus, bhag, growth, connection
  }
  ```

- [ ] **A3** — Statische Hilfsmethode `DailyIntention.activeFilters(from:) -> [IntentionOption]` auf UserDefaults-Key basierend

---

### Phase B: MorningIntentionView — Trigger nach Setzen

- [ ] **B1** — `@AppStorage("intentionJustSet")` und `@AppStorage("intentionFilterOptions")` Properties in `MorningIntentionView` hinzufuegen

- [ ] **B2** — Im "Intention setzen" Button-Handler nach dem Speichern:
  - `intentionFilterOptions` als kommagetrennte rawValues schreiben
  - `intentionJustSet = true` setzen
  - Bestehende Logik (intention speichern, isEditing = false) unveraendert lassen

---

### Phase C: FocusBloxApp — Tab-Wechsel

- [ ] **C1** — `@AppStorage("intentionJustSet")` Property in `FocusBloxApp` hinzufuegen

- [ ] **C2** — `.onChange(of: intentionJustSet)` im `body` des `WindowGroup` hinzufuegen:
  - Wenn `true`: `selectedTab = .backlog`, dann `intentionJustSet = false`

---

### Phase D: BacklogView — Filter-Chips + gefilterte Listen

- [ ] **D1** — `@AppStorage("intentionFilterOptions")` Property in `BacklogView` hinzufuegen

- [ ] **D2** — Computed property `activeIntentionFilters: [IntentionOption]` — liest und parsed den AppStorage-Key

- [ ] **D3** — Computed property `intentionFilterActive: Bool` — true wenn `activeIntentionFilters` nicht leer ist (und survival nicht dabei ist)

- [ ] **D4** — `intentionFilteredBacklogTasks: [PlanItem]` computed property — wendet ODER-Logik der aktiven Filter an

- [ ] **D5** — `intentionFilterChips` View-Komponente (`@ViewBuilder private var`) — horizontale HStack mit Chips
  - Jeder Chip: Intention-Icon + Label + X-Button
  - Nur sichtbar wenn `intentionFilterActive == true`
  - Accessibility-Identifier: `"intentionFilterChip_\(option.rawValue)"`
  - X-Button-Identifier: `"removeIntentionFilter_\(option.rawValue)"`

- [ ] **D6** — `intentionFilterChips` in `priorityView` als ersten Item in der List einfuegen (als `listRowBackground(.clear)` Section ohne Header)

- [ ] **D7** — `priorityView` anpassen: wenn `intentionFilterActive`, Backlog-Tasks aus `intentionFilteredBacklogTasks` statt `backlogTasks` nehmen

- [ ] **D8** — Balance-Sonderfall: wenn nur `.balance` aktiv (kein anderer Filter ausser survival), in `priorityView` Kategorie-Sections statt Tier-Sections rendern

- [ ] **D9** — "Filter entfernen" Logik: beim X-Tap die entsprechende Option aus `intentionFilterOptions` entfernen und AppStorage aktualisieren

---

### Phase E: Tests (TDD RED vor Phase A-D)

Tests muessen VOR der Implementierung geschrieben und rot sein — siehe `tests.md`.

---

### Phase F: Cleanup & Validierung

- [ ] **F1** — `intentionJustSet` Key wird in `FocusBloxApp.resetUserDefaultsIfNeeded()` beim UI-Test-Reset geloescht

- [ ] **F2** — `intentionFilterOptions` Key wird ebenfalls beim UI-Test-Reset geloescht

- [ ] **F3** — Sicherstellen dass `backlogViewMode` AppStorage unveraendert bleibt (keine Kollision mit neuen Keys)

- [ ] **F4** — Build auf iOS laufen lassen, keine Compiler-Warnings

- [ ] **F5** — Alle neuen Unit Tests gruen

- [ ] **F6** — Alle neuen UI Tests gruen
