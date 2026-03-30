---
entity_id: INFRA_002
type: infrastructure
created: 2026-03-30
updated: 2026-03-30
status: draft
version: "1.0"
tags: [hooks, workflow, infrastructure, redesign]
---

# INFRA_002: Workflow v3 — Von 51 Hooks auf Phasenwechsel-Architektur

## Approval

- [ ] Approved

## Purpose

Komplettes Redesign des Hook-Systems. 51 Python-Hooks (~11.200 LoC) auf 5 Hooks (~1.200 LoC) konsolidieren. Gleiche Qualitätssicherung, 90% weniger Komplexität. Eliminiert Over-Blocking, Race Conditions, Session-Tracking-Bugs und Self-Referential Deadlocks.

## Scope

Dieses Ticket deckt **P1 (State-Isolation) + P2 (Hook-Konsolidierung)** ab. P3 (QA-Agent) und P4 (Cleanup) sind separate Folge-Tickets.

---

## Teil 1: State-Isolation

### Problem
- Ein einziges `workflow_state.json` (71K Tokens) für alle Workflows
- Session-Tracking via TERM_SESSION_ID + /tmp-Files → Race Conditions
- Workflows verschwinden nach set-field/switch
- `fcntl.flock()` für Locks → funktioniert nicht über SSH-Grenzen

### Lösung

**1 JSON-File pro Workflow** in `.claude/workflows/`:

```
.claude/workflows/
├── .active              ← Symlink auf aktiven Workflow (z.B. → INFRA_002.json)
├── INFRA_002.json       ← State für INFRA_002
├── MAC_RW_2.1_TL.json   ← State für MAC_RW_2.1_TL
└── _archive/            ← Abgeschlossene Workflows (phase8_complete)
```

**Workflow-File-Format** (vereinfacht gegenüber aktuellem State):

```json
{
  "name": "INFRA_002",
  "current_phase": "phase3_spec",
  "created": "2026-03-30T10:00:00",
  "last_updated": "2026-03-30T12:00:00",
  "spec_file": "docs/specs/infra/INFRA_002-workflow-v3.md",
  "spec_approved": false,
  "context_file": "docs/context/INFRA_002.md",
  "affected_files": ["file1.swift", "file2.swift"],
  "test_artifacts": [],
  "is_new_ui": false,
  "red_test_done": false,
  "ui_test_red_done": false,
  "green_approved": false,
  "adversary_verdict": null
}
```

**Was entfällt:**
- `session_workflows` Map (kein Session-Tracking mehr)
- `_tty_key()`, `_session_id()`, `/tmp/claude_session_*` Files
- `fcntl.flock()` File-Locks (atomare File-Writes stattdessen)
- `visual_inspection_done/notes`, `result_inspection_done/notes`, `user_expectation_done/notes` (→ CLAUDE.md Guidance)
- `phases_completed` Array (redundant mit current_phase)
- `backlog_status` (wird aus Phase abgeleitet)
- `red_test_snapshot` (unnötig komplex)

**Aktiver Workflow:** Per `.active` Symlink statt `active_workflow` Key. Wechsel = Symlink umbiegen. Kein Locking nötig.

**Migration:** Einmaliges Python-Script liest `workflow_state.json`, splittet in einzelne Files, erstellt `.active` Symlink. Alte Datei wird nach `.claude/workflow_state.json.bak` verschoben.

### Neue CLI: `workflow.py` (~300 LoC, ersetzt 1.733 LoC)

```bash
python3 .claude/hooks/workflow.py start "INFRA_002"      # Erstellt .claude/workflows/INFRA_002.json + Symlink
python3 .claude/hooks/workflow.py switch "MAC_RW_2.1_TL"  # Symlink umbiegen
python3 .claude/hooks/workflow.py status                   # Aktiven Workflow + Phase anzeigen
python3 .claude/hooks/workflow.py phase phase6_implement   # Phase setzen (mit Validierung)
python3 .claude/hooks/workflow.py set-field key value      # Feld setzen
python3 .claude/hooks/workflow.py complete                 # → _archive/ verschieben
python3 .claude/hooks/workflow.py list                     # Alle Workflows auflisten
python3 .claude/hooks/workflow.py set-affected-files f1 f2 # affected_files setzen
```

Intern: Atomare Writes via `tempfile` + `os.rename()` statt Lock-Files.

---

## Teil 2: Hook-Konsolidierung (51 → 5)

### Neue Hook-Registrierung (settings.json)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "python3 .claude/hooks/edit_gate.py", "timeout": 5 }]
      },
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "python3 .claude/hooks/bash_gate.py", "timeout": 300 }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "python3 .claude/hooks/post_bash.py", "timeout": 5 }]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [{ "type": "command", "command": "python3 .claude/hooks/phase_listener.py", "timeout": 5 }]
      }
    ]
  }
}
```

**Kein PreToolUse Task-Matcher mehr.** visual_inspection_gate und feature_understanding_gate werden CLAUDE.md Guidance.

### Hook 1: `edit_gate.py` (PreToolUse Edit|Write)

Konsolidiert: workflow_gate, strict_code_gate, red_test_gate, spec_enforcement, tdd_enforcement, scope_guard, track_changes, claude_md_protection, docs_location_guard, domain_pattern_guard, plan_validator, post_implementation_gate, ui_screenshot_gate, ui_test_preflight, test_regression_guard, override_token_guard, stop_lock_guard.

**Logik (sequentiell, Short-Circuit):**

```
1. Protected State Files? (.claude/workflow_state.json etc.) → BLOCK
2. Always-Allowed? (docs/, tests/, scripts/, .md, .json) → ALLOW
3. Nicht Code-File? → ALLOW
4. Infrastructure File? (.claude/hooks/) → Override-Token prüfen → BLOCK/ALLOW
5. Stop-Lock aktiv? → BLOCK
6. Workflow für Datei finden (affected_files Match)
7. Kein Workflow? → BLOCK ("Starte /01-context oder /02-analyse")
8. Phase < phase6_implement? → BLOCK (mit kontextabhängiger Meldung)
9. Override-Token vorhanden? → ALLOW (überspringt TDD-Check)
10. RED-Test-Artifacts vorhanden? (red_test_done || ui_test_red_done || artifacts mit phase5_tdd_red) → Falls nein: BLOCK
11. ALLOW
```

**Geschätzt:** ~200 LoC (vs. ~2.500 LoC aktuell für die 17 Edit-Hooks zusammen)

### Hook 2: `bash_gate.py` (PreToolUse Bash)

Konsolidiert: state_integrity_guard, sim_enforcer, build_lock_guard, stop_lock_guard, override_token_bash_guard, adversary_verdict_guard, result_inspection_gate, validate_completeness_gate, artifact_existence_guard, pre_commit_gate, secrets_guard, test_lock_guard, parallel_test_guard, no_workaround_guard, tdd_green_gate.

**Logik (sequentiell):**

```
1. Stop-Lock aktiv? → BLOCK
2. State-Integrity: Referenziert Bash-Command Protected File + Write-Indicator? → BLOCK (außer Whitelist)
3. Secrets: Sensitives File + Content-Output? → BLOCK
4. Sim-Enforcer: xcrun/xcodebuild ohne sim.sh? → BLOCK
5. Build-Lock: xcodebuild Command? → Lock prüfen/warten/acquiren
6. Git Commit?
   a. ACTIVE-todos.md staged/aktuell? → Falls nein: BLOCK
   b. Workflow-ID als ERLEDIGT markiert? → Falls nein: BLOCK
   c. Adversary-Verdict vorhanden und sauber? → Falls nein: BLOCK
7. TDD-GREEN-Gate: In phase6 + "go" nicht erteilt? → BLOCK
8. ALLOW
```

**Geschätzt:** ~350 LoC (vs. ~2.800 LoC aktuell für die 15 Bash-Hooks zusammen)

### Hook 3: `post_bash.py` (PostToolUse Bash)

Konsolidiert: build_lock_release.

**Logik:**
```
1. War ein xcodebuild Command? → Lock-File löschen
2. EXIT
```

**Geschätzt:** ~30 LoC (vs. 63 LoC aktuell)

### Hook 4: `phase_listener.py` (UserPromptSubmit)

Konsolidiert: workflow_state_updater, stop_lock_listener, override_token_listener, new_ui_listener, tdd_green_listener, workflow_cleanup.

**Logik:**
```
1. User-Nachricht parsen
2. Match gegen Keyword-Listen:
   - "approved"/"freigabe"/"lgtm" → spec_approved = true, Phase → phase4_approved
   - "stop"/"stopp" → Stop-Lock setzen
   - "weiter"/"continue" → Stop-Lock lösen
   - "override"/"ich genehmige" → Override-Token erstellen
   - "neues ui" → is_new_ui = true
   - "go" → green_approved = true
3. Session-ID publishen (für Workflow-Zuordnung falls nötig)
```

**Geschätzt:** ~120 LoC (vs. ~500 LoC aktuell für die 6 UserPromptSubmit-Hooks)

### Hook 5: `phase_transition.py` (KEIN Hook — wird von Slash-Commands aufgerufen)

Wird direkt von `workflow.py phase <new_phase>` aufgerufen. Validiert ALLE Voraussetzungen der nächsten Phase.

**Validierungsmatrix:**

| Übergang | Prüfung |
|----------|---------|
| → phase2_analyse | context_file existiert |
| → phase3_spec | analysis_findings nicht leer |
| → phase4_approved | spec_file existiert, spec_approved == true |
| → phase5_tdd_red | spec_approved == true |
| → phase6_implement | RED-Artifacts mit FAIL-Ergebnis vorhanden |
| → phase7_validate | GREEN-Artifacts mit PASS-Ergebnis vorhanden |
| → phase8_complete | adversary_verdict starts with "VERIFIED", ACTIVE-todos aktualisiert |

**Geschätzt:** ~150 LoC

### Utility: `override_token.py` (bleibt fast unverändert)

142 LoC, Multi-Workflow Token-Management. Wird von edit_gate.py und bash_gate.py importiert. Minimale Anpassung: Pfad zu Token-File ggf. aktualisieren.

---

## Was in CLAUDE.md wandert (statt Hooks)

Folgende Prüfungen werden aus Hooks entfernt und als **Guidance-Regeln** in CLAUDE.md formuliert:

| Bisheriger Hook | CLAUDE.md Regel |
|----------------|-----------------|
| `visual_inspection_gate.py` | "Bei UI-Bugs: Zuerst Screenshot machen bevor Agents gestartet werden" |
| `feature_understanding_gate.py` | "Vor Investigation: Problem in 2 Sätzen beschreiben können" |
| `no_workaround_guard.py` | "Keine Workarounds. Root Cause finden." |
| `domain_pattern_guard.py` | "Bestehende Patterns fortführen (AccessibilityIdentifier etc.)" |
| `ui_test_preflight.py` | "Vor UI Tests: /inspect-ui ausführen" |
| `on_ui_test_failure.py` | "Bei UI Test Failure: Screenshot machen, Hierarchy inspizieren" |
| `ui_test_debugger_hint.py` | "Debug-Tipps für UI Tests" |
| `notify_sound.py` | Entfällt (23 LoC Sound-Notification) |

**Prinzip:** Hooks = Gesetz (harte Blocker). CLAUDE.md = Guidance (Empfehlungen die Claude befolgen soll, aber nicht erzwungen werden).

---

## Affected Files

### Erstellen (8 Dateien)
| Datei | Beschreibung | LoC |
|-------|-------------|-----|
| `.claude/hooks/workflow.py` | Neue State-CLI (ersetzt workflow_state_multi.py) | ~300 |
| `.claude/hooks/edit_gate.py` | Konsolidierter Edit/Write Guard | ~200 |
| `.claude/hooks/bash_gate.py` | Konsolidierter Bash Guard | ~350 |
| `.claude/hooks/post_bash.py` | Build-Lock Release | ~30 |
| `.claude/hooks/phase_listener.py` | UserPromptSubmit Listener | ~120 |
| `.claude/hooks/phase_transition.py` | Phasenwechsel-Validierung | ~150 |
| `.claude/hooks/migrate_state.py` | Einmaliges Migrations-Script | ~80 |
| `.claude/workflows/` | Verzeichnis für isolierte Workflow-States | — |

### Ändern (3 Dateien)
| Datei | Änderung |
|-------|---------|
| `.claude/settings.json` | 41 Hook-Einträge → 4 |
| `.claude/hooks/override_token.py` | Minimale Pfad-Anpassung |
| `CLAUDE.md` | Neue Guidance-Regeln (Kategorie D) |

### Löschen (46 Dateien, ~10.000 LoC)
Alle bisherigen Hook-Dateien außer `override_token.py`:
- adversary_gate.py, adversary_verdict_guard.py, artifact_existence_guard.py
- build_lock_guard.py, build_lock_release.py, claude_md_protection.py
- config_loader.py, docs_location_guard.py, domain_pattern_guard.py
- feature_understanding_gate.py, inspection_gate.py, new_ui_listener.py
- no_workaround_guard.py, notify_sound.py, on_ui_test_failure.py
- override_token_bash_guard.py, override_token_guard.py, override_token_listener.py
- parallel_test_guard.py, plan_validator.py, post_implementation_gate.py
- pre_commit_gate.py, preflight_gate.py, red_test_gate.py
- result_inspection_gate.py, scope_guard.py, secrets_guard.py
- session_env.py, sim_enforcer.py, spec_enforcement.py
- state_integrity_guard.py, stop_lock_guard.py, stop_lock_listener.py
- strict_code_gate.py, tdd_enforcement.py, tdd_green_gate.py
- tdd_green_listener.py, test_lock_guard.py, test_regression_guard.py
- track_changes.py, ui_screenshot_gate.py, ui_test_debugger_hint.py
- ui_test_gate.py, ui_test_preflight.py, validate_completeness_gate.py
- visual_inspection_gate.py, workflow_cleanup.py, workflow_gate.py
- workflow_state_multi.py, workflow_state_updater.py

### Löschen (State-Files)
- `.claude/workflow_state.json` (nach Migration)
- `.claude/workflow_state.lock`
- `.claude/test_execution_lock.json`
- `.claude/validation_state.json`
- `.claude/ui_test_preflight_state.json`
- `.claude/ui_screenshot_lock.json`
- `.claude/workflow_last_cleanup.json`

---

## Migrations-Strategie

### Clean Cutover (nicht inkrementell)

1. **Vorbereitung:** Alle neuen Hooks in `.claude/hooks/` entwickeln (mit Prefix `v3_` während Entwicklung)
2. **Migration:** `migrate_state.py` ausführen → splittet workflow_state.json in einzelne Files
3. **Switch:** settings.json auf neue Hooks umschalten, alte löschen
4. **Verify:** Alle Slash-Commands testen (start, switch, phase, status)
5. **Cleanup:** Alte State-Files löschen, Backups entfernen

### Slash-Command-Updates

Alle Commands in `.claude/commands/` müssen von `workflow_state_multi.py` auf `workflow.py` umgestellt werden. Das ist ein Search-Replace:
```
workflow_state_multi.py → workflow.py
```

---

## Test Plan

Da dies reine Infrastruktur ist (Python-Hooks, keine Swift-App):

### Unit Tests (Python)
1. `workflow.py` — start, switch, phase, set-field, complete, list, status
2. `edit_gate.py` — Protected Files, Always-Allowed, Phase-Check, TDD-Check, Override
3. `bash_gate.py` — State-Integrity, Secrets, Sim-Enforcer, Build-Lock, Pre-Commit
4. `phase_listener.py` — Approval, Stop-Lock, Override, New-UI, Green-Gate
5. `phase_transition.py` — Alle Phasenübergänge mit Validierung
6. `migrate_state.py` — Migration von v2 State auf isolierte Files

### Integration Tests (manuell via Workflow)
1. Kompletter Workflow: /01-context → /02-analyse → /03-write-spec → approved → /04-tdd-red → /05-implement → /06-validate
2. Override-Token: "override" → Edit in falscher Phase → funktioniert
3. Parallele Workflows: 2 Workflows starten, zwischen ihnen wechseln
4. Migration: Bestehenden State migrieren, Workflows weiter nutzbar

---

## Expected Behavior

- **Vorher:** 17 Hooks pro Edit (bis 85s), 15 Hooks pro Bash (bis 365s). Over-Blocking bei Infrastruktur-Tasks.
- **Nachher:** 1 Hook pro Edit (~5ms), 1 Hook pro Bash (~5-300ms je nach Build-Lock). Kein Over-Blocking.
- **Gleiche Garantien:** Kein Code ohne Workflow, kein Impl ohne RED-Tests, kein Commit ohne Adversary-Verdict.

## Known Limitations

- QA-Agent (P3) ist nicht Teil dieser Spec — Adversary bleibt vorerst manuell getriggert
- `notify_sound.py` wird ersatzlos gestrichen (23 LoC Sound-Notification)
- `config_loader.py` wird ersatzlos gestrichen — Konfiguration direkt in Hooks

## Changelog

- 2026-03-30: Initial spec created
