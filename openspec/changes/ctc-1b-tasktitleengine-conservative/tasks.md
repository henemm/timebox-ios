# CTC-1b: Implementierungs-Checkliste

## Phase 5: TDD RED (Tests zuerst)

- [ ] `TaskTitleEngineTests.swift` erweitern:
  - [ ] `test_improvedTask_preservesOriginalWords_whenAvailable` — "Bahnfahrt" bleibt "Bahnfahrt", "OH" bleibt "OH"
  - [ ] `test_improvedTask_extractsDueDateToday_whenAvailable` — "heute erledigen" → dueDate = heute
  - [ ] `test_improvedTask_setsUrgent_whenAvailable` — "heute erledigen!" → urgency = "urgent"
  - [ ] `test_improvedTask_removesUrgencyHintFromTitle_whenAvailable` — "heute erledigen!" nicht im Titel
  - [ ] `test_improvedTask_doesNotOverwriteExistingDueDate` — bestehende dueDate bleibt erhalten
  - [ ] `test_improvedTask_doesNotOverwriteExistingUrgency` — bestehende urgency bleibt erhalten
- [ ] Tests ausfuehren → ALLE neuen Tests schlagen FEHL (RED bestaetigt)
- [ ] Artifact erstellen: `docs/artifacts/ctc-1b-tasktitleengine-conservative/unit-test-red-output.txt`

## Phase 6: Implementieren

- [ ] `ImprovedTitle` → `ImprovedTask` umbenennen
- [ ] Felder hinzufuegen: `dueDateRelative: String?`, `isUrgent: Bool`
- [ ] `@Guide` Beschreibungen fuer neue Felder schreiben
- [ ] System Prompt: konservative Regeln ergaenzen
- [ ] `performImprovement()`: dueDate setzen (nur wenn nil)
- [ ] `performImprovement()`: urgency setzen (nur wenn nil + isUrgent == true)
- [ ] Private Hilfsmethode `relativeDateFrom(_:)` hinzufuegen

## Phase 7: Validieren

- [ ] Alle neuen Tests GRUEN
- [ ] Alle bestehenden Tests weiterhin GRUEN
- [ ] Build erfolgreich (iOS + macOS)
- [ ] `docs/ACTIVE-todos.md` aktualisieren: #27 als ERLEDIGT markieren
