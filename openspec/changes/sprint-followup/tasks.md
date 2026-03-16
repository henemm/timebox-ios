# FEATURE_024: Sprint Follow-up — Implementierungs-Checkliste

---

## Phase 1: TDD RED (Vor der Implementation)

### Unit Tests (FocusBlockActionServiceTests.swift)

- [ ] `test_followUpTask_completesOriginalTask` — Original-Task wird als completed markiert
- [ ] `test_followUpTask_createsNewLocalTaskCopy` — Neue LocalTask-Kopie wird angelegt
- [ ] `test_followUpTask_copyHasCorrectFields` — Kopie hat Originaltitel, Metadaten, isCompleted=false
- [ ] `test_followUpTask_copyHasNoBlocker` — blockerTaskID ist nil auf der Kopie
- [ ] `test_followUpTask_copyHasNoRecurrence` — recurrencePattern ist "none" auf der Kopie
- [ ] `test_followUpTask_copyIsNotNextUp` — isNextUp ist false auf der Kopie
- [ ] `test_followUpTask_returnsFollowedUp` — Rueckgabewert ist `.followedUp`
- [ ] `test_followUpTask_recordsTaskTime` — taskTimes wird wie bei completeTask gesetzt

### UI Tests (FocusBloxUITests/SprintFollowUpUITests.swift — neu)

- [ ] `test_followUpButton_isVisible` — "Follow-up"-Button existiert in currentTaskView
- [ ] `test_followUpButton_opensTaskFormSheet` — Antippen oeffnet TaskFormSheet
- [ ] `test_followUpButton_taskFormSheet_hasCancelButton` — Sheet hat "Abbrechen"
- [ ] `test_followUpButton_taskFormSheet_hasSaveButton` — Sheet hat "Speichern"
- [ ] `test_followUpButton_afterSave_progressesToNextTask` — Sprint geht nach Speichern weiter

---

## Phase 2: Implementation

### FocusBlockActionService.swift

- [ ] `TaskActionResult.followedUp` Case hinzufuegen
- [ ] `followUpTask()` Methode implementieren:
  - [ ] `completeTask()` intern aufrufen
  - [ ] Neue `LocalTask`-Kopie erstellen (Felder kopieren, isCompleted/completedAt/assignedFocusBlockID/blockerTaskID/recurrencePattern zuruecksetzen)
  - [ ] Kopie in `modelContext` insertern und speichern
  - [ ] Neue Task-ID zurueckgeben (fuer Sheet-Oeffnung)
  - [ ] `return .followedUp(newTaskID: ...)`

### FocusLiveView.swift

- [ ] `@State private var showFollowUpSheet = false` hinzufuegen
- [ ] `@State private var followUpTaskID: String? = nil` hinzufuegen
- [ ] Follow-up-Button in `currentTaskView()` neben Skip/Complete einfuegen
- [ ] `followUpTask()` Handler implementieren:
  - [ ] `FocusBlockActionService.followUpTask()` aufrufen
  - [ ] `showFollowUpSheet = true` setzen
- [ ] `.sheet(isPresented: $showFollowUpSheet)` mit `TaskFormSheet` im Edit-Modus verdrahten
- [ ] Nach Sheet-Dismiss: `followUpTaskID = nil`, `await loadData()`
- [ ] "Abbrechen"-Callback: Kopie via modelContext loeschen

### SprintFollowUpUITests.swift (neue Datei)

- [ ] Datei anlegen
- [ ] Mock-Setup (Sprint-State mit aktivem Task)
- [ ] Alle UI Tests implementieren (TDD RED: zuerst fehlschlagend)

---

## Phase 3: Validation

- [ ] Alle Unit Tests gruen (`xcodebuild test ...`)
- [ ] Alle UI Tests gruen
- [ ] Build ohne Errors
- [ ] Kein Drive-by Refactoring in anderen Dateien
- [ ] ACTIVE-todos.md auf ERLEDIGT setzen
