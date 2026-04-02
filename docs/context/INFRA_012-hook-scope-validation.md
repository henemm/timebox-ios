# Context: INFRA_012 — Hook-System Scope-Validierung

## Request Summary
Das Hook-System hat 3 Scope-Validierungs-Luecken, die es ermoeglichten, ein komplettes Feature (Coach-Tab-Layout) am Workflow vorbei zu implementieren, indem `set-affected-files` nachtraeglich mit fremden Dateien aufgerufen wurde.

## Related Files

| File | Relevance |
|------|-----------|
| `.claude/hooks/edit_gate.py` | Luecke 1+2: Prueft affected_files, aber validiert nicht Zeitpunkt/Konsistenz |
| `.claude/hooks/workflow.py` | Luecke 2: `set-affected-files` hat keine Phase-Einschraenkung, kein Auto-Complete |
| `.claude/hooks/bash_gate.py` | Luecke 3: pbxproj-Manipulation via Python-Einzeiler nicht blockiert |
| `.claude/commands/02-analyse.md` | Ruft `set-affected-files` in Phase 2 auf |
| `.claude/commands/03-write-spec.md` | Ruft `set-affected-files --replace` in Phase 3 auf |
| `.claude/commands/10-bug.md` | Ruft `set-affected-files --replace` in Spec-Phase auf |
| `.claude/commands/11-feature.md` | Ruft `set-affected-files --replace` in Spec-Phase auf |

## Existing Patterns

- **Phase-Validierung**: `workflow.py:_validate_transition()` prueft Gates bei Phase-Wechseln (context_file, spec_approved, red_test_done etc.)
- **Edit-Gate**: `edit_gate.py` prueft Phase + affected_files + TDD-Artifacts sequentiell
- **Override-Token**: Ermoeglicht Bypass aller Gates mit explizitem User-Token
- **Build-Lock**: `bash_gate.py` hat Session-basiertes Build-Lock-System
- **Commit-Gate**: `bash_gate.py` blockiert `git commit` ohne Adversary-Verdict

## Dependencies

- **Upstream**: `workflow.py` State-Modell (JSON), `.sessions.json` Mapping
- **Downstream**: Alle `/01-context` bis `/07-deploy` Commands nutzen `set-affected-files`

## Existing Specs

- `docs/specs/infra/INFRA_002-workflow-v3.md` — Workflow v3 Architektur
- `docs/specs/infra/INFRA_003-session-aware-workflows.md` — Session-Isolation

## Luecken-Analyse (aus Issue #186)

### Luecke 1: affected_files jederzeit aenderbar (KRITISCH)
- `cmd_set_affected_files()` hat **keine Phase-Pruefung**
- Kann in phase6_implement beliebige neue Dateien hinzufuegen
- Edit-Gate laesst dann diese Dateien durch

### Luecke 2: Kein Auto-Complete nach Commit (HOCH)
- Workflow bleibt in phase6/7 nach Commit offen
- Keine Pruefung ob Workflow bereits committed wurde
- Ermoeglicht Wiederverwertung fuer andere Features

### Luecke 3: pbxproj via Python nicht blockiert (MITTEL)
- `bash_gate.py` blockiert `sed -i project.pbxproj`
- Aber `python3 -c "from pbxproj..."` geht durch
- WRITE_INDICATORS erkennt `python3 -c` zwar, aber nur mit PROTECTED_FILE_PATTERNS
- `project.pbxproj` ist nicht in PROTECTED_FILE_PATTERNS

## Analysis

### Type
Infrastruktur-Bug (Hook-System Scope-Validierung)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `.claude/hooks/workflow.py` | MODIFY | Phase-Guard in `cmd_set_affected_files()` (+15 LoC) |
| `.claude/hooks/bash_gate.py` | MODIFY | `project.pbxproj` in PROTECTED_FILE_PATTERNS + Script-Whitelist (+2 LoC) |
| `scripts/add_file_to_project.py` | CREATE | Whitegelistetes Script fuer pbxproj-Manipulation (~30 LoC) |

### Scope Assessment
- Files: 3
- Estimated LoC: +47
- Risk Level: LOW

### Technical Approach

**Luecke 1 (IMPLEMENTIEREN):** Phase-Guard in `cmd_set_affected_files()`. Erlaubte Phasen: `phase1_context` bis `phase4_approved`. Override-Token als Bypass. `/10-bug` Schritt 7.5 ruft es in `phase4_approved` auf — das bleibt kompatibel.

**Luecke 2 (NICHT IMPLEMENTIEREN):** Bestehende Gates decken den Fall bereits ab: Adversary-Verdict vor Commit, Edit-Sperre in phase6b/phase7. Auto-Complete bringt mehr Reibung als Schutz.

**Luecke 3 (IMPLEMENTIEREN):** `project.pbxproj` zu PROTECTED_FILE_PATTERNS + neues Script `scripts/add_file_to_project.py` als whitegelistete Alternative zum Python-Einzeiler.

### Empfehlung an Henning

- Luecke 1 + 3 fixen (3 Dateien, ~47 LoC)
- Luecke 2 bewusst offen lassen (bestehende Gates reichen)

### Dependencies
- Override-Token-Logik muss in workflow.py reimplementiert werden (~10 LoC, identisch zu edit_gate.py)
- CLAUDE.md-Anweisung fuer pbxproj muss nach Fix auf neues Script verweisen

### Risks & Considerations
- `/10-bug` ruft `set-affected-files` in `phase4_approved` auf — ist in der Allowlist, kein Breaking Change
- pbxproj-Blockierung ohne whitegelistetes Script wuerde den dokumentierten Prozess brechen → deshalb Script als atomare Einheit mit Gate
- Override-Token bleibt als Fallback immer funktional
