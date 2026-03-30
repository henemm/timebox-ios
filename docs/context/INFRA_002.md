# Context: INFRA_002 — Workflow v3: Von 51 Hooks auf Phasenwechsel-Architektur

## Request Summary
Komplettes Redesign des Hook-Systems. 51 Python-Hooks (~11.200 LoC) mit 227KB shared State auf eine Phasenwechsel-Architektur mit 5 Hooks und isoliertem State pro Workflow reduzieren. Gleiche Qualitätssicherung, 90% weniger Komplexität.

## Ist-Zustand (Probleme, live beobachtet)

### Hook-Overhead
- **51 Hook-Dateien**, ~11.222 LoC gesamt
- **41 Hook-Registrierungen** in settings.json
- Jeder Edit/Write durchläuft **17 Hooks**, jeder Bash-Befehl **15 Hooks**
- `workflow_state_multi.py` allein: **1.733 Zeilen**

### Over-Blocking (während Context-Gathering beobachtet)
1. `state_integrity_guard.py` blockiert `python3 -c "..."` wenn `.claude/hooks/*.py` im Code vorkommt — auch READ-only
2. `override_token_bash_guard.py` blockiert `wc -l` weil "workflow_state" als Substring im Dateinamen matcht
3. `visual_inspection_gate.py` blockiert Agent-Tool für reine Infrastruktur-Tasks (Screenshot-Pflicht für Nicht-UI)
4. Hooks können ihre eigene Analyse nicht zulassen → Self-Referential Deadlock

### Shared Mutable State
- `workflow_state.json`: **71.112 Tokens** (ein einzelnes File für alle Workflows)
- 8 weitere JSON State-Files: build_lock, test_execution_lock, validation_state, ui_test_preflight_state, ui_screenshot_lock, workflow_last_cleanup, user_override_token, workflow_state.lock
- Session-Tracking via TERM_SESSION_ID + `/tmp/claude_session_*`-Files → Race Conditions
- `fcntl.flock()` für State-Locks — funktioniert nicht über SSH/Container-Grenzen

### Bekannte Bugs (aus Memory)
- Workflows verschwinden nach set-field/switch (project_workflow-multi-bug)
- Dangling active_workflow Pointer nach Cleanup
- Session-ID-Hacks für parallele Workflows instabil

## Related Files

### Kernkomponenten
| File | Relevanz | LoC |
|------|----------|-----|
| `.claude/hooks/workflow_state_multi.py` | Zentrale State-Machine, CLI, alle Workflow-Operationen | 1733 |
| `.claude/settings.json` | Alle Hook-Registrierungen | 248 |
| `.claude/workflow_state.json` | Shared State für alle Workflows | ~71K tokens |

### Hook-Dateien nach Kategorie

**Phase/Workflow-Management (→ `phase_listener.py` + `phase_transition.py`):**
| File | Aufgabe | LoC |
|------|---------|-----|
| `workflow_gate.py` | Blockiert Edits ohne aktiven Workflow | ? |
| `workflow_state_updater.py` | UserPromptSubmit: Phase-Updates | ? |
| `workflow_cleanup.py` | UserPromptSubmit: Alte Workflows aufräumen | ? |
| `stop_lock_guard.py` | Stop-Lock prüfen (Edit + Bash) | ? |
| `stop_lock_listener.py` | UserPromptSubmit: Stop-Lock setzen/lösen | ? |
| `override_token.py` | Override-Token-Logik | ? |
| `override_token_guard.py` | Edit/Write: Override prüfen | ? |
| `override_token_bash_guard.py` | Bash: Override prüfen | ? |
| `override_token_listener.py` | UserPromptSubmit: Override-Token erzeugen | ? |
| `new_ui_listener.py` | UserPromptSubmit: "neues ui" Flag setzen | ? |
| `tdd_green_gate.py` | Bash: TDD GREEN Gate (User muss "go" sagen) | ? |
| `tdd_green_listener.py` | UserPromptSubmit: "go" erkennen | ? |

**Edit/Write Guards (→ `edit_gate.py`):**
| File | Aufgabe |
|------|---------|
| `strict_code_gate.py` | Blockiert Code-Edits in falscher Phase |
| `red_test_gate.py` | Blockiert Impl ohne RED-Artifacts |
| `spec_enforcement.py` | Blockiert ohne Spec |
| `tdd_enforcement.py` | TDD-Artefakt-Prüfung |
| `scope_guard.py` | LoC/File-Limits prüfen |
| `track_changes.py` | affected_files tracken |
| `claude_md_protection.py` | CLAUDE.md Schutz |
| `docs_location_guard.py` | Docs am richtigen Ort |
| `domain_pattern_guard.py` | Pattern-Compliance |
| `plan_validator.py` | Plan-Validierung |
| `post_implementation_gate.py` | Post-Impl Checks |
| `ui_screenshot_gate.py` | Screenshot-Pflicht |
| `ui_test_preflight.py` | UI Test Preflight Checks |
| `test_regression_guard.py` | Regression-Check |

**Bash Guards (→ `bash_gate.py`):**
| File | Aufgabe |
|------|---------|
| `sim_enforcer.py` | sim.sh Enforcement |
| `build_lock_guard.py` | Parallele Build-Verhinderung |
| `state_integrity_guard.py` | State-File-Schutz |
| `adversary_verdict_guard.py` | Adversary-Ergebnis prüfen |
| `result_inspection_gate.py` | Ergebnis-Inspektion |
| `validate_completeness_gate.py` | Vollständigkeits-Check |
| `artifact_existence_guard.py` | Artefakt-Existenz prüfen |
| `pre_commit_gate.py` | Pre-Commit Checks |
| `secrets_guard.py` | Secrets-Schutz |
| `test_lock_guard.py` | Test-Parallelität |
| `parallel_test_guard.py` | Test-Parallelität |
| `no_workaround_guard.py` | Workaround-Verbot |

**Agent/Task Guards (→ können entfallen oder in edit_gate/CLAUDE.md):**
| File | Aufgabe |
|------|---------|
| `visual_inspection_gate.py` | Screenshot vor Agent |
| `feature_understanding_gate.py` | Verständnis-Gate |

**PostToolUse (→ `post_bash.py`):**
| File | Aufgabe |
|------|---------|
| `build_lock_release.py` | Build-Lock freigeben |

**Standalone/Utility:**
| File | Aufgabe |
|------|---------|
| `adversary_gate.py` | Adversary-Logik (317 LoC) |
| `inspection_gate.py` | Inspektions-Logik (243 LoC) |
| `config_loader.py` | Konfiguration laden (236 LoC) |
| `on_ui_test_failure.py` | UI Test Failure Handler (274 LoC) |
| `notify_sound.py` | Sound-Notification (23 LoC) |
| `session_env.py` | Session-Environment |
| `preflight_gate.py` | Preflight-Checks |
| `ui_test_debugger_hint.py` | UI Test Debug-Hilfe |
| `ui_test_gate.py` | UI Test Gate |

### Slash Commands (bleiben, werden vereinfacht)
| File | Phase |
|------|-------|
| `.claude/commands/00-reset.md` | Reset |
| `.claude/commands/01-context.md` | Context |
| `.claude/commands/02-analyse.md` | Analyse |
| `.claude/commands/03-write-spec.md` | Spec |
| `.claude/commands/04-tdd-red.md` | TDD RED |
| `.claude/commands/05-implement.md` | TDD GREEN |
| `.claude/commands/06-validate.md` | Validate |
| `.claude/commands/10-bug.md` | Bug-Workflow |
| `.claude/commands/11-feature.md` | Feature-Workflow |

## Existing Patterns

### State-Machine Pattern (aktuell)
- Phasen als String in JSON: `"current_phase": "phase5_tdd_red"`
- Phase-Progression via `workflow_state_multi.py phase <phase>`
- Jeder Hook liest State-File → prüft Phase → blockiert oder nicht
- Session-Zuordnung via TTY-Hash + session_workflows Map

### Ziel-Pattern (INFRA_002)
- 1 JSON File pro Workflow: `.claude/workflows/<name>.json`
- Aktiver Workflow per `.claude/workflows/.active` Symlink
- Phasenwechsel-Validierung NUR beim Übergang (nicht bei jedem Edit)
- Optimistisch: frei arbeiten innerhalb einer Phase

## Dependencies
- **Upstream:** Claude Code Hook-System (PreToolUse, PostToolUse, UserPromptSubmit Events)
- **Upstream:** Slash Commands in `.claude/commands/`
- **Upstream:** `scripts/sim.sh` (Build/Test-Tool)
- **Downstream:** JEDER Claude Code Workflow in diesem Projekt

## Existing Specs
- Migrationsplan bereits in `docs/ACTIVE-todos.md` (INFRA_002 Sektion)
- Kein separates Spec-File existiert noch

## Risks & Considerations
1. **Migration-Risiko:** Während Umstellung könnten laufende Workflows korrupt werden → Clean Cutover nötig
2. **QA-Agent:** Muss genauso streng sein wie bisherige Hooks → gründlich testen
3. **Wertvolle Logik:** secrets_guard, scope_guard, sim_enforcer enthalten Logik die erhalten bleiben muss
4. **Scope:** XL-Ticket — muss in 4 Sub-Phasen aufgeteilt werden (je mit eigener Spec)
5. **Self-Referential:** Hooks können ihre eigene Migration blockieren → Override-Token oder temporäres Ausschalten nötig
6. **Backwards-Compatibility:** Alte workflow_state.json muss migriert oder neu aufgebaut werden

---

## Analysis

### Type
Feature (Infrastruktur-Redesign)

### Hook-Logik-Analyse: Was muss erhalten bleiben?

Nach dem Lesen aller kritischen Hooks ergibt sich folgendes Bild:

#### KATEGORIE A: Redundante Prüfungen (gleiche Logik, mehrere Hooks)
Die folgenden Hooks prüfen alle dasselbe Grundmuster: "Ist Phase >= phase6_implement?"

| Hook | Prüft | Redundanz mit |
|------|-------|---------------|
| `workflow_gate.py` (453 LoC) | Phase, affected_files, Override | `strict_code_gate.py` |
| `strict_code_gate.py` (458 LoC) | Phase, affected_files, Override, RED-done | `workflow_gate.py` + `tdd_enforcement.py` |
| `red_test_gate.py` | RED-Artifacts vorhanden | `tdd_enforcement.py` |
| `spec_enforcement.py` | Spec existiert | `workflow_gate.py` (implizit über Phase) |
| `tdd_enforcement.py` (460 LoC) | TDD-Artifacts, Timestamps, Failure-Evidence | Teilredundant mit `strict_code_gate.py` |

**Einsparung:** 5 Hooks → 1 `edit_gate.py` (~200 LoC)

#### KATEGORIE B: Wertvolle Standalone-Logik (MUSS erhalten bleiben)
| Hook | Logik | Integration in |
|------|-------|----------------|
| `secrets_guard.py` (269 LoC) | Sensitive Dateien blockieren (.env, credentials) | `bash_gate.py` |
| `sim_enforcer.py` (172 LoC) | xcrun/xcodebuild → sim.sh Redirect | `bash_gate.py` |
| `build_lock_guard.py` (211 LoC) | Mutex für parallele Builds, Stale-Detection | `bash_gate.py` |
| `pre_commit_gate.py` (542 LoC) | Backlog-Update, Adversary-Verdict, Tests, Screenshots | `bash_gate.py` |
| `state_integrity_guard.py` (277 LoC) | Protected Files vor Bash-Manipulation schützen | `bash_gate.py` |
| `override_token.py` (142 LoC) | Multi-Workflow Token-Management | Bleibt als Utility |

#### KATEGORIE C: Listener (UserPromptSubmit → State-Updates)
| Hook | Hört auf | Integration in |
|------|----------|----------------|
| `workflow_state_updater.py` | "approved", "freigabe" → spec_approved | `phase_listener.py` |
| `stop_lock_listener.py` | "stop", "stopp" → Stop-Lock | `phase_listener.py` |
| `override_token_listener.py` | "override", "ich genehmige" → Token | `phase_listener.py` |
| `new_ui_listener.py` | "neues ui" → is_new_ui Flag | `phase_listener.py` |
| `tdd_green_listener.py` | "go" → GREEN Gate freigeben | `phase_listener.py` |
| `workflow_cleanup.py` | Session-Start → alte Workflows aufräumen | `phase_listener.py` |

**Einsparung:** 6 Hooks → 1 `phase_listener.py` (~150 LoC)

#### KATEGORIE D: Können in CLAUDE.md + Phase-Transition wandern
| Hook | Aktuell | Besser als |
|------|---------|------------|
| `visual_inspection_gate.py` | Blockiert Agent-Tool | CLAUDE.md Guidance + phase_transition.py |
| `feature_understanding_gate.py` | Verständnis-Gate | CLAUDE.md Guidance |
| `scope_guard.py` (205 LoC) | Task-Scope-Prüfung | `edit_gate.py` (affected_files reicht) |
| `track_changes.py` | affected_files tracken | `edit_gate.py` (implizit) |
| `docs_location_guard.py` | Docs-Pfade prüfen | CLAUDE.md Guidance |
| `domain_pattern_guard.py` | Pattern-Compliance | CLAUDE.md Guidance |
| `plan_validator.py` | Plan-Validierung | CLAUDE.md Guidance |
| `no_workaround_guard.py` | Workaround-Verbot | CLAUDE.md Guidance |
| `claude_md_protection.py` | CLAUDE.md Schutz | `edit_gate.py` (Protected Files) |
| `ui_test_preflight.py` | Preflight für UI Tests | CLAUDE.md + Skill |
| `ui_screenshot_gate.py` | Screenshot-Pflicht | CLAUDE.md + phase_transition.py |
| `test_regression_guard.py` | Regression-Check | `phase_transition.py` |
| `post_implementation_gate.py` | Post-Impl Checks | `phase_transition.py` |
| `adversary_verdict_guard.py` | Adversary-Ergebnis | `bash_gate.py` (pre-commit) |
| `result_inspection_gate.py` | Ergebnis-Inspektion | `phase_transition.py` |
| `validate_completeness_gate.py` | Vollständigkeit | `phase_transition.py` |
| `artifact_existence_guard.py` | Artefakte vorhanden | `phase_transition.py` |
| `test_lock_guard.py` | Test-Parallelität | `bash_gate.py` |
| `parallel_test_guard.py` | Test-Parallelität | `bash_gate.py` (merge mit test_lock) |

### Ziel-Architektur: 5 Hooks + 2 Utilities

```
settings.json (NEU):
  PreToolUse:
    Edit|Write  → edit_gate.py       (Phase + affected_files + TDD + Protected Files)
    Bash        → bash_gate.py       (sim_enforcer + build_lock + state_integrity + secrets + pre_commit)
  PostToolUse:
    Bash        → post_bash.py       (build_lock_release)
  UserPromptSubmit:
                → phase_listener.py  (approval + stop + override + new_ui + green_gate + cleanup)

  phase_transition.py wird NICHT als Hook registriert — wird von Slash-Commands direkt aufgerufen.

Utilities (kein Hook, importiert von anderen):
  override_token.py  → Token-Management
  workflow.py         → State-Management (ersetzt workflow_state_multi.py, ~300 LoC)
```

### Scope Assessment

Da XL-Ticket, aufgeteilt in **4 Sub-Phasen** (je eigenständig deploybar):

| Sub-Phase | Files | LoC | Risiko |
|-----------|-------|-----|--------|
| **P1: State-Isolation** | 3 create, 1 modify | ~400 | LOW — neues Dir, Symlink, Migration |
| **P2: Hook-Konsolidierung** | 5 create, 51 delete, 2 modify | ~800 create, -11K delete | HIGH — alle Hooks gleichzeitig |
| **P3: QA-Agent** | 2 create, 1 modify | ~300 | MEDIUM — neues Konzept |
| **P4: Cleanup** | 0 create, 46 delete, 2 modify | -9K delete | LOW — nur löschen |

**Empfehlung:** P1 und P2 zusammen als ersten Spec, weil P2 ohne P1 keinen Sinn macht (State-Format ändert sich). P3 als eigenständigen Spec. P4 als Cleanup nach P2+P3.

**Konkret für die erste Spec (P1+P2):**
- **8 Dateien** erstellen/ändern
- **~1200 LoC** neuer Code
- **~11.000 LoC** gelöschter Code (Netto: -9.800 LoC)
- Risk Level: **HIGH** (alle Hooks gleichzeitig ersetzen = Big Bang)

### Technischer Ansatz

**Clean Cutover statt inkrementell:**
1. Alle neuen Hooks parallel entwickeln (in `.claude/hooks/v3/`)
2. Gegen existierenden State testen
3. An einem Punkt: settings.json umschalten, alte Hooks löschen
4. Kein Zurück — Git Branch als Safety Net

**Warum nicht inkrementell:**
- Hooks importieren sich gegenseitig (workflow_state_multi als shared Dependency)
- Altes State-Format und neues State-Format parallel zu unterstützen verdoppelt die Komplexität
- Die meisten Hooks sind redundant — einzeln ersetzen bringt nichts

### Dependencies
- **Upstream:** Claude Code Hook-System (Events: PreToolUse, PostToolUse, UserPromptSubmit)
- **Upstream:** Slash Commands in `.claude/commands/` (rufen workflow_state_multi.py auf)
- **Upstream:** `override_token.py` (importiert von fast allen Hooks)
- **Downstream:** JEDER zukünftige Workflow in diesem Projekt
- **Downstream:** CLAUDE.md (muss aktualisiert werden)
- **Downstream:** Slash Commands (müssen neue CLI nutzen)

### Offene Fragen
- [ ] Soll P3 (QA-Agent) in der ersten Iteration dabei sein oder ist P1+P2 Scope genug?
- [ ] Sollen laufende Workflows (MAC_RW_2.1_TL) vorher abgeschlossen werden oder wird State migriert?
- [ ] Wie viel der "CLAUDE.md Guidance" (Kategorie D) soll tatsächlich in CLAUDE.md statt in Hooks?
