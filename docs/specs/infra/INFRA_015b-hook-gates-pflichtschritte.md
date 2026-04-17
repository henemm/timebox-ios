---
entity_id: INFRA_015b-hook-gates-pflichtschritte
type: module
created: 2026-04-17
updated: 2026-04-17
status: draft
version: "1.0"
tags: [hooks, gates, workflow, enforcement]
---

# INFRA_015b — Hook-Gates für Pflichtschritte

## Approval

- [ ] Approved

## Purpose

3 neue Hook-Gates einbauen, damit der Orchestrator die Pflichtschritte `/inspect-ui`, Screenshot und `/13-localize` nicht mehr überspringen kann. Bisherige "Best Practice"-Hinweise in Skill-Dateien werden ignoriert — nur Hook-Enforcement ist zuverlässig.

GitHub Issue: #246

## Betroffene Dateien

| Datei | Änderung | Beschreibung |
|-------|----------|--------------|
| `.claude/hooks/workflow.py` | MODIFY | Neue Felder + 3 mark-Commands |
| `.claude/hooks/edit_gate.py` | MODIFY | Gate 1: inspect-ui Check |
| `.claude/hooks/phase_listener.py` | MODIFY | Gate 2: Screenshot Check |
| `.claude/hooks/bash_gate.py` | MODIFY | Gate 3: Localize Check |
| `.claude/commands/04-tdd-red.md` | MODIFY | "Best Practice" → "PFLICHT" |
| `.claude/commands/inspect-ui.md` | MODIFY | workflow.py mark-inspect-ui Aufruf |
| `.claude/commands/13-localize.md` | MODIFY | workflow.py mark-localize Aufruf |

## Gate 1: inspect-ui vor UI-Test-Writes

### Trigger
`edit_gate.py` — PreToolUse für Edit/Write

### Bedingung
Phase = `phase4_tdd_red` UND Dateipfad enthält `UITests/`

### Prüfung
Workflow-Feld `inspect_ui_done` muss `true` sein.

### Blockade-Meldung
```
BLOCKED: /inspect-ui ist PFLICHT vor UI-Test-Writes.
Führe /inspect-ui aus, um die Accessibility-Hierarchie zu inspizieren.
```

### Einfügepunkt
`edit_gate.py` Zeile 311-312: Direkt nach `if is_test:` in `TEST_ONLY_PHASES`, VOR dem `sys.exit(0)`. Nur für UI-Test-Dateien, nicht für Unit-Test-Dateien.

```python
# In TEST_ONLY_PHASES block (after line 310):
if phase in TEST_ONLY_PHASES:
    if is_test:
        # Gate 1: inspect-ui PFLICHT vor UI-Test-Writes
        if any(d in file_path for d in ["UITests/", "FocusBloxUITests/", "FocusBloxMacUITests/"]):
            if not workflow.get("inspect_ui_done"):
                print("BLOCKED: /inspect-ui ist PFLICHT vor UI-Test-Writes. "
                      "Führe /inspect-ui aus, um die Accessibility-Hierarchie zu inspizieren.",
                      file=sys.stderr)
                sys.exit(2)
        sys.exit(0)  # Test-Dateien erlaubt in TDD RED
```

### Workflow-Feld
- Name: `inspect_ui_done`
- Default: `false`
- Geschützt: Ja (in `PROTECTED_FIELDS`, nicht in `CHECKPOINT_FIELDS`)
- Gesetzt durch: `workflow.py mark-inspect-ui`
- Reset: Bei Phase-Wechsel zu `phase4_tdd_red` zurücksetzen (damit bei erneutem TDD RED neu inspiziert werden muss)

## Gate 2: Screenshot vor Checkpoint 3

### Trigger
`phase_listener.py` — UserPromptSubmit

### Bedingung
Phase = `phase5_implement` UND Keyword = "commit" UND `is_new_ui` ist NICHT `true`

### Prüfung
Im `test_artifacts` Array muss mindestens ein Eintrag mit `type == "screenshot"` existieren.

### Blockade-Meldung (stderr, informativ — phase_listener blockiert nie mit exit 2)
```
HINWEIS: Checkpoint 3 benötigt einen Screenshot.
Führe ./scripts/sim.sh screenshot aus und registriere das Artifact:
  workflow.py add-artifact screenshot "<pfad>" "<beschreibung>" phase5_implement
```

### Einfügepunkt
`phase_listener.py` Zeile 241-245: Im Checkpoint-3-Block, nach dem `has_unresolved`-Check.

```python
# Checkpoint 3 — only if no unresolved findings AND screenshot exists
if _matches(message, CHECKPOINT3_PHRASES):
    if phase == "phase5_implement" and not wf_data.get("checkpoint3_approved"):
        findings = wf_data.get("adversary_findings", [])
        has_unresolved = any(f.get("status") is None for f in findings)
        # Gate 2: Screenshot-Artifact prüfen (außer bei neuem UI)
        has_screenshot = wf_data.get("is_new_ui") or any(
            a.get("type") == "screenshot" for a in wf_data.get("test_artifacts", []))
        if not has_unresolved and has_screenshot:
            _call_workflow_checkpoint(3, f"User approved at {datetime.now().isoformat()}")
        elif not has_screenshot:
            print("HINWEIS: Checkpoint 3 benötigt einen Screenshot. "
                  "Führe ./scripts/sim.sh screenshot aus und registriere: "
                  "workflow.py add-artifact screenshot <pfad> <beschreibung> phase5_implement",
                  file=sys.stderr)
```

### Kein neues Workflow-Feld nötig
Nutzt das bestehende `test_artifacts`-Array mit `type == "screenshot"`.

### Ausnahme: is_new_ui
Wenn `is_new_ui == true` (neuer Screen, nichts zum Screenshotten), entfällt die Screenshot-Pflicht.

## Gate 3: Localize-Check vor Commit

### Trigger
`bash_gate.py` — PreToolUse für Bash (git commit)

### Bedingung
`git commit` mit `fix:` oder `feat:` UND aktiver Workflow

### Prüfung
Workflow-Feld `localize_checked` muss `true` sein ODER `no_user_strings` muss `true` sein.

### Blockade-Meldung
```
BLOCKED: /13-localize ist PFLICHT vor dem Commit.
Führe /13-localize aus oder setze no_user_strings wenn keine User-facing Strings betroffen sind:
  workflow.py set-field no_user_strings true
```

### Einfügepunkt
`bash_gate.py` nach Zeile 363 (nach dem Adversary-Findings Gate 6c): Neues Subgate 6d.

```python
# 6d. Localize Gate — kein Commit ohne Lokalisierungs-Check
if active_wf:
    loc_checked = active_wf.get("localize_checked", False)
    no_strings = active_wf.get("no_user_strings", False)
    if not loc_checked and not no_strings:
        print("BLOCKED: /13-localize ist PFLICHT vor dem Commit. "
              "Führe /13-localize aus oder setze no_user_strings: "
              "workflow.py set-field no_user_strings true",
              file=sys.stderr)
        sys.exit(2)
```

### Workflow-Felder
- `localize_checked`: Default `false`, geschützt, gesetzt durch `workflow.py mark-localize`
- `no_user_strings`: Default `false`, NICHT geschützt (Claude darf es setzen für reine Infra-Workflows)

## Workflow.py Änderungen

### Neue Felder in `_new_workflow()`

```python
def _new_workflow(name: str) -> dict:
    return {
        # ... bestehende Felder ...
        "inspect_ui_done": False,
        "localize_checked": False,
        "no_user_strings": False,
    }
```

### Neue mark-Commands

```python
def cmd_mark_inspect_ui(args: list[str]) -> None:
    """Mark inspect-ui as done for current workflow."""
    data, name = _read_active()
    data["inspect_ui_done"] = True
    _save_active(data)
    print(f"inspect-ui marked done for {name}")

def cmd_mark_localize(args: list[str]) -> None:
    """Mark localization check as done for current workflow."""
    data, name = _read_active()
    data["localize_checked"] = True
    _save_active(data)
    print(f"Localization check marked done for {name}")
```

### PROTECTED_FIELDS erweitern

```python
PROTECTED_FIELDS = {
    *CHECKPOINT_FIELDS,
    "spec_approved",
    "red_test_done",
    "ui_test_red_done",
    "context_file",
    "inspect_ui_done",      # NEU
    "localize_checked",     # NEU
    # no_user_strings bewusst NICHT protected — Claude darf es setzen
}
```

### COMMANDS erweitern

```python
COMMANDS = {
    # ... bestehende ...
    "mark-inspect-ui": cmd_mark_inspect_ui,
    "mark-localize": cmd_mark_localize,
}
```

### inspect_ui_done Reset bei Phase-Wechsel

In `cmd_phase()`: Wenn Ziel = `phase4_tdd_red`, setze `inspect_ui_done = False`.

```python
def cmd_phase(args: list[str]) -> None:
    # ... bestehende Logik ...
    data["current_phase"] = target
    # Reset inspect_ui_done when re-entering TDD RED
    if target == "phase4_tdd_red":
        data["inspect_ui_done"] = False
    _save_active(data)
```

## Skill-Änderungen

### inspect-ui.md

Ersetze den bestehenden State-Tracking-Abschnitt (Zeile 74-82) mit:

```markdown
## State-Tracking

**Nach erfolgreicher Ausführung** im Workflow registrieren:

\```bash
python3 .claude/hooks/workflow.py mark-inspect-ui
\```

Dies ist **PFLICHT** — der edit_gate Hook blockiert UI-Test-Writes ohne dieses Flag.
```

### 13-localize.md

Am Ende hinzufügen:

```markdown
## State-Tracking

**Nach erfolgreicher Ausführung** im Workflow registrieren:

\```bash
python3 .claude/hooks/workflow.py mark-localize
\```

Dies ist **PFLICHT** — der bash_gate Hook blockiert git commit ohne dieses Flag.
Falls keine User-facing Strings betroffen sind:
\```bash
python3 .claude/hooks/workflow.py set-field no_user_strings true
\```
```

### 04-tdd-red.md

Zeile 47-49 ersetzen:

```markdown
### 1b. Inspect-UI (PFLICHT vor UI-Tests)

**⛔ Gate-enforced:** Der edit_gate Hook blockiert UI-Test-Writes ohne vorheriges `/inspect-ui`.

\```bash
# 1. /inspect-ui ausführen für den Ziel-Screen
# 2. Danach automatisch im Workflow registriert
\```
```

## Test Plan

### Unit Tests (in `.claude/hooks/tests/`)

1. **test_inspect_ui_gate**: Phase 4 + UITests-Datei + inspect_ui_done=false → BLOCK
2. **test_inspect_ui_gate_allows**: Phase 4 + UITests-Datei + inspect_ui_done=true → ALLOW
3. **test_inspect_ui_gate_unit_tests**: Phase 4 + Unit-Test-Datei (nicht UITests) → ALLOW (kein Gate)
4. **test_screenshot_gate_blocks**: Phase 5 + "commit" + kein Screenshot-Artifact → Checkpoint 3 wird NICHT gesetzt
5. **test_screenshot_gate_allows**: Phase 5 + "commit" + Screenshot-Artifact → Checkpoint 3 wird gesetzt
6. **test_screenshot_gate_new_ui**: Phase 5 + "commit" + is_new_ui=true + kein Screenshot → Checkpoint 3 wird gesetzt
7. **test_localize_gate_blocks**: git commit + localize_checked=false + no_user_strings=false → BLOCK
8. **test_localize_gate_allows_checked**: git commit + localize_checked=true → ALLOW
9. **test_localize_gate_allows_no_strings**: git commit + no_user_strings=true → ALLOW
10. **test_mark_inspect_ui**: workflow.py mark-inspect-ui setzt Feld korrekt
11. **test_mark_localize**: workflow.py mark-localize setzt Feld korrekt
12. **test_inspect_ui_reset**: Phase-Wechsel zu phase4_tdd_red setzt inspect_ui_done zurück

## Known Limitations

- `no_user_strings` kann von Claude selbst gesetzt werden — bewusste Design-Entscheidung für Infra-Workflows. Missbrauch fällt beim Adversary auf.
- inspect-ui Gate greift nur in Phase 4, nicht bei nachträglichen UI-Test-Änderungen in Phase 5 (dort sind Tests ohnehin gesperrt).
- Screenshot Gate nutzt `type == "screenshot"` Convention im Artifact-Schema — keine Schema-Validierung.
- Alte Workflows ohne die neuen Felder: `.get("field", False)` mit Default-Fallback, kein Crash.

## Changelog

- 2026-04-17: Initial spec created
