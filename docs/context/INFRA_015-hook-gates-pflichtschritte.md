# Context: INFRA_015 — Hook-Gates für Pflichtschritte

## Request Summary
3 neue Hook-Gates einbauen, damit der Orchestrator Pflichtschritte (/inspect-ui, Screenshot, /13-localize) nicht mehr überspringen kann. GitHub Issue #246.

## Betroffene Dateien

| Datei | Relevanz |
|-------|----------|
| `.claude/hooks/edit_gate.py` | Gate 1: inspect-ui Check vor UI-Test-Writes in Phase 4 |
| `.claude/hooks/phase_listener.py` | Gate 2: Screenshot-Artifact prüfen bevor Checkpoint 3 gesetzt wird |
| `.claude/hooks/bash_gate.py` | Gate 3: localize_checked Flag prüfen vor git commit |
| `.claude/hooks/workflow.py` | Neue Felder: `inspect_ui_done`, `localize_checked` + neue mark-Commands |
| `.claude/commands/04-tdd-red.md` | "Best Practice" zurück zu "PFLICHT (Gate-enforced)" |
| `.claude/commands/inspect-ui.md` | Muss Workflow-State setzen (inspect_ui_done) |
| `.claude/commands/13-localize.md` | Muss Workflow-State setzen (localize_checked) |

## Bestehende Patterns

### Workflow-State Felder setzen
- `mark-red`, `mark-ui-red`, `mark-green`, etc. in workflow.py (Zeile 522-555)
- Protected Fields werden über `PROTECTED_FIELDS` Set geschützt (Zeile 430-436)
- Dedicated mark-* Commands statt set-field für kritische Felder

### Edit-Gate Phase-Checks
- Phase4 TEST_ONLY: Nur Test-Dateien (edit_gate.py Zeile 309-315)
- Phase5 SOURCE_ONLY: Keine Tests (edit_gate.py Zeile 317-323)
- Pattern: Phase prüfen → Datei-Typ prüfen → BLOCK/ALLOW

### Phase-Listener Checkpoint-Prüfung
- Checkpoint 3 prüft bereits: keine ungelösten Adversary-Findings (phase_listener.py Zeile 241-245)
- Pattern: Keyword match → Phase prüfen → Zusatzbedingung prüfen → workflow.py aufrufen

### Bash-Gate Commit-Prüfung
- Prüft bereits: Issue-Link + Checkpoint 3 + Adversary-Findings (bash_gate.py Zeile 312-363)
- Pattern: `git commit` erkennen → Workflow laden → Felder prüfen → BLOCK/ALLOW

## Bestehender inspect-ui State
- `inspect-ui.md` referenziert `preflight_gate.py` (Zeile 78) — existiert NICHT
- `ui_test_preflight_state.json` ist in PROTECTED_STATE_FILES (edit_gate.py Zeile 51)
- Es gab mal ein Preflight-System, wurde aber entfernt/nie fertig gebaut

## Dependencies
- `workflow.py` wird von allen Hooks als CLI aufgerufen (subprocess)
- `edit_gate.py` liest Workflow-State direkt (JSON)
- `phase_listener.py` liest Workflow-State direkt + ruft workflow.py per subprocess
- `bash_gate.py` liest Workflow-State direkt

## Risiken
- Neue Gate-Felder müssen in `_new_workflow()` initialisiert werden (sonst KeyError bei alten Workflows)
- `inspect_ui_done` sollte pro Phase resettet werden (bei Phase-Wechsel zurücksetzen?)
- Localize-Gate muss Workflows ohne User-facing Strings überspringen können (Flag: `no_user_strings`)
