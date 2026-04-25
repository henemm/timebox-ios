---
entity_id: INFRA_016-silent-pass-hardening
type: infrastructure
created: 2026-04-25
updated: 2026-04-25
status: draft
version: "1.0"
tags: [workflow, quality-gates, tdd, adversary]
---

# INFRA_016 — Silent-Pass-Hardening

## Approval

- [ ] Approved

## Purpose

Drei voneinander unabhängige Mechanismen einbauen, die verhindern, dass Tests GREEN melden ohne den Bug auszulösen ("Silent-Pass-Tests"). Auslöser: Bug #287, bei dem ein UI-Test mit `guard let popover = ... else { return }` still durchlief, weil das MenuBar-Popover nie erschien — obwohl genau das der Bug war.

## Source

- **Files (neu):**
  - `.claude/hooks/test_quality_gate.py` — Silent-Pass-Detector (PreToolUse für Edit|Write)
- **Files (geändert):**
  - `.claude/settings.json` — `test_quality_gate.py` und `qa_gate.py` als Hooks registrieren
  - `.claude/hooks/qa_gate.py` — neuer Hook-Mode für PreToolUse Bash
  - `.claude/commands/adversary.md` — neue Pflicht-Phase "Pre-Fix-Test-Validation"
  - `.claude/agents/implementation-validator.md` — Test-Quality-Audit als Standard-Schritt
  - `.claude/agents/qa-writer.md` — Verbots-Liste um Silent-Pass-Patterns erweitern
  - `.claude/agents/developer.md` — "Silent-Pass-Tests als Blocker melden, nicht selbst fixen"
  - `CLAUDE.md` — Anti-Pattern-Section "Silent-Pass Tests"

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| edit_gate.py | Hook | Bestehender PreToolUse-Gate — neuer Hook reiht sich ein |
| bash_gate.py | Hook | qa_gate.py wird parallel als zweiter Bash-Hook aktiv |
| workflow.py | State Manager | Liefert affected_files für Test-Hook-Match |
| hook_utils.py | Helper | `read_active_workflow_with_path` wird wiederverwendet |

---

## Maßnahme A — Silent-Pass-Detector als Hook

### Problem

Test-Dateien können Silent-Pass-Patterns enthalten, die niemand erkennt. Drei Patterns sind kritisch:

1. `guard let x = ... else { return }` ohne vorheriges `XCTFail` — Test endet still
2. `if let x = ... { ... }` ohne `else { XCTFail(...) }` — Test bestätigt nichts wenn Optional nil
3. `XCTAssertNotNil(x); guard let x = x else { return }` — `XCTUnwrap` wäre korrekt

### Lösung

**1. Neuer Hook `.claude/hooks/test_quality_gate.py`**

- PreToolUse-Hook für `Edit|Write`
- Triggert nur wenn Zieldatei ein Test-File ist (Pfad enthält `Tests/` oder `UITests/` und endet auf `.swift`)
- Liest den `content` (Write) oder `new_string` (Edit) aus dem Tool-Input
- Sucht via Regex die 3 Patterns:
  - **P1:** `guard\s+let\s+.*=.*else\s*\{[^}]*return[^}]*\}` — wenn keine `XCTFail|XCTAssert` in den 5 Zeilen davor
  - **P2:** `if\s+let\s+.*=.*\{` — wenn kein `else` mit `XCTFail` im selben Block
  - **P3:** `XCTAssertNotNil\([^)]+\)\s*[;\n]+\s*guard\s+let` — explizit als Anti-Pattern
- Bei Match: Exit 2 mit Meldung
- Bypass via Override-Token (`__infra__` oder workflow-spezifisches Token)
- Bypass auch bei `XCTUnwrap` direkt davor (legitimes Pattern)

**2. Registration in `settings.json`**

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    { "type": "command", "command": "python3 .claude/hooks/edit_gate.py", "timeout": 5 },
    { "type": "command", "command": "python3 .claude/hooks/test_quality_gate.py", "timeout": 5 }
  ]
}
```

Beide Hooks für Edit|Write — laufen sequentiell, beide müssen Exit 0 liefern.

### Akzeptanzkriterien

- **AC-A1:** Schreiben einer Test-Datei mit `guard let x = ... else { return }` (ohne XCTFail davor) wird mit Exit 2 blockiert
- **AC-A2:** Schreiben einer Test-Datei mit `XCTUnwrap(x)` wird durchgelassen
- **AC-A3:** Schreiben einer Test-Datei mit `if let x = ... { ... } else { XCTFail("x is nil") }` wird durchgelassen
- **AC-A4:** Schreiben einer NICHT-Test-Datei (z.B. `Sources/Foo.swift`) mit `guard let ... else { return }` wird NICHT geblockt (legitimes Production-Pattern)
- **AC-A5:** Bypass via `__infra__`-Token funktioniert für legitime Edge-Cases

---

## Maßnahme B — `qa_gate.py` als Bash-Hook aktivieren

### Problem

`qa_gate.py:35-98` validiert Test-Output (Pattern, Alter, Größe, Failure-Detection) — aber ist nur Utility, kein Hook. Der Orchestrator kann `mark-red` / `mark-green` aufrufen ohne dass jemals der Test-Output geprüft wurde.

### Lösung

**1. Neuer CLI-Modus `qa_gate.py --hook-mode`**

Wenn aufgerufen mit `--hook-mode` (PreToolUse Bash):
- Liest Bash-Command aus `CLAUDE_TOOL_INPUT`
- Prüft ob Command `workflow.py mark-red`, `mark-ui-red`, `mark-green` oder `mark-ui-green` enthält
- Falls ja: extrahiert das Test-Output-Argument
- Validiert via existierender `validate_test_output()` Funktion
- Bei invalid: Exit 2 mit Meldung
- Bei `--infra` Workflow-Type: skippt UI-Test-Pflicht (wie bestehender `--infra` Flag)
- Bei nicht-mark-Commands: Exit 0 (passthrough)

**2. Registration in `settings.json`**

```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "python3 .claude/hooks/bash_gate.py", "timeout": 300 },
    { "type": "command", "command": "python3 .claude/hooks/qa_gate.py --hook-mode", "timeout": 5 }
  ]
}
```

### Akzeptanzkriterien

- **AC-B1:** Bash-Command `workflow.py mark-red /tmp/empty.txt` wird blockiert (Output zu klein / nicht-existent)
- **AC-B2:** Bash-Command `workflow.py mark-red /tmp/valid_test_output.txt` mit echtem XCTest-Output wird durchgelassen
- **AC-B3:** Bash-Command `workflow.py mark-red /tmp/old_output.txt` (>30 Min alt) wird blockiert
- **AC-B4:** Bash-Command ohne `mark-red`/`mark-green` (z.B. `ls`, `git status`) wird unverändert durchgelassen
- **AC-B5:** Bei `workflow_type: feature` mit `is_new_ui: false` wird UI-Test-Pflicht im qa_gate übersprungen (Infra-Tickets)

---

## Maßnahme C — Adversary Pre-Fix-Validation

### Problem

`adversary.md:107-126` und `implementation-validator.md:32-37` verlangen "Tests ausführen" — fragen aber nicht "wären die Tests ohne den Fix rot?". Bug #287 hatte 2/2 GREEN, aber die Tests hätten auch ohne Fix bestanden.

### Lösung

**1. Neue Pflicht-Phase im Adversary-Skill (`.claude/commands/adversary.md`)**

Nach Phase 3 "Tests ausführen" eine neue Phase einfügen:

```
### Phase 3b: Pre-Fix-Test-Validation (PFLICHT)

Du musst BEWEISEN, dass die Tests den Bug erkennen würden — nicht nur dass sie grün sind.

1. Stash den Fix:
   git stash push -m "adversary-pre-fix-check"

2. Tests erneut ausführen:
   ./scripts/sim.sh test [RELEVANTE-UI-TEST-KLASSEN]

3. Erwartung: Mindestens EIN Test der den Bug betrifft MUSS jetzt FAILED sein.
   Falls alle Tests immer noch GREEN sind: SILENT-PASS-PROBLEM. Finding erstellen.

4. Stash zurückbringen:
   git stash pop

5. Tests erneut ausführen — müssen jetzt wieder GREEN sein.
   Falls nicht: stash pop hat Konflikte erzeugt — Henning informieren.

Dokumentation im Report:
| Test | Vor Fix | Nach Fix |
|------|---------|----------|
| testFoo | FAILED | PASSED |
| testBar | FAILED | PASSED |

Falls "Vor Fix" auch PASSED → Test ist Silent-Pass → BLOCKER-Finding.
```

**2. Neuer Schritt im Implementation-Validator-Prompt (`.claude/agents/implementation-validator.md`)**

In "Prüf-Protokoll" zwischen Schritt 3 (Tests ausführen) und Schritt 4 (Edge Cases) einfügen:

```
### 3b. Test-Quality-Audit (PFLICHT)

Für jeden Test in den affected_files Test-Dateien:

a) Lies den Test-Code. Frage:
   - Erreicht der Test den Code-Pfad, der geändert wurde?
   - Gibt es Early-Exit-Patterns (`guard let ... else { return }`) die den Test still beenden könnten?
   - Werden alle Assertions tatsächlich ausgeführt?

b) Pre-Fix-Validation (für Bug-Workflows):
   - git stash push -m "validator-pre-fix"
   - Test ausführen
   - Erwartung: FAILED
   - git stash pop
   - Test ausführen
   - Erwartung: PASSED

c) Bei Silent-Pass-Verdacht: BLOCKER-Finding mit "proof": Test-Code-Zitat + "Test besteht ohne Fix"
```

**3. Update Verboten-Liste im Validator**

Ergänzung in `.claude/agents/implementation-validator.md`:
```
- "Tests sind grün" als Beweis für Fix — du musst BEWEISEN, dass Tests ohne Fix rot wären
```

### Akzeptanzkriterien

- **AC-C1:** `adversary.md` enthält "Phase 3b: Pre-Fix-Test-Validation" als Pflicht-Phase
- **AC-C2:** `adversary.md` Report-Template enthält "Vor Fix / Nach Fix" Tabelle
- **AC-C3:** `implementation-validator.md` enthält Schritt "3b. Test-Quality-Audit" mit `git stash` Mechanik
- **AC-C4:** `implementation-validator.md` Verboten-Liste enthält "Tests sind grün als Beweis für Fix"
- **AC-C5:** Bug-Workflows (`workflow_type: bug`) lösen Pre-Fix-Validation aus, Feature-Workflows nicht zwingend (Features haben keinen "vorherigen Bug-Code")

---

## Maßnahme D — Agent-Prompt + Doku-Updates

### Lösung

**1. `.claude/agents/qa-writer.md`** — Verbots-Liste erweitern:

```
- KEIN guard let ... else { return } in Tests — verwende XCTUnwrap
- KEIN if let ohne else { XCTFail(...) } — Optional muss explizit failen
- KEIN Optional-Chaining (?.) in Test-Assertions — wenn nil, soll Test failen
```

**2. `.claude/agents/developer.md`** — neuer Verbots-Eintrag:

```
- WENN du Silent-Pass-Patterns in QA-Tests siehst (guard let ... else return ohne XCTFail):
  → BLOCKER an Orchestrator melden, NICHT selbst die Tests "reparieren"
  → QA-Writer hat das Recht, Tests neu zu schreiben — du nicht
```

**3. `CLAUDE.md`** — neue Section unter "Testing-Strategie":

```
### Anti-Pattern: Silent-Pass-Tests

Tests die GREEN melden ohne den Code-Pfad zu testen sind WERTLOS — auch wenn sie kompilieren.

Verboten in Test-Dateien:
- guard let x = ... else { return } — verwende XCTUnwrap(x)
- if let x = ... { ... } ohne else { XCTFail(...) }
- view?.button?.tap() in UI-Tests — wenn view nil, passiert nichts und Test "besteht"

"GREEN" bedeutet: "Bug ist beweisbar gefixt" — nicht "Code kompiliert".
Adversary muss beweisen: Test wäre OHNE Fix rot. Sonst ist GREEN bedeutungslos.
```

### Akzeptanzkriterien

- **AC-D1:** `qa-writer.md` Verbots-Liste enthält die 3 Silent-Pass-Patterns
- **AC-D2:** `developer.md` enthält "Silent-Pass an Orchestrator melden, nicht selbst fixen"
- **AC-D3:** `CLAUDE.md` enthält Section "Anti-Pattern: Silent-Pass-Tests"

---

## Test Plan

Alle Tests in `.claude/hooks/tests/test_silent_pass_hardening.py` (Python unittest) — keine Swift-Tests, weil reine Hook/Markdown-Änderungen.

| Test | Was es prüft | Erwartung RED |
|------|--------------|---------------|
| `test_silent_pass_hook_blocks_guard_let_return` | Write von Test-File mit Pattern P1 → Exit 2 | FAIL: Hook existiert nicht |
| `test_silent_pass_hook_allows_xctunwrap` | Write von Test-File mit `XCTUnwrap` → Exit 0 | FAIL: Hook existiert nicht |
| `test_silent_pass_hook_allows_if_let_with_xctfail` | `if let ... else { XCTFail(...) }` → Exit 0 | FAIL: Hook existiert nicht |
| `test_silent_pass_hook_skips_non_test_files` | `Sources/Foo.swift` mit `guard let ... else return` → Exit 0 | FAIL: Hook existiert nicht |
| `test_silent_pass_hook_respects_infra_token` | Bypass via `__infra__`-Token funktioniert | FAIL: Hook existiert nicht |
| `test_qa_gate_hook_mode_blocks_invalid_output` | `qa_gate.py --hook-mode` mit leerem Test-Output-Bash → Exit 2 | FAIL: `--hook-mode` existiert nicht |
| `test_qa_gate_hook_mode_allows_valid_output` | `qa_gate.py --hook-mode` mit echtem XCTest-Output → Exit 0 | FAIL: `--hook-mode` existiert nicht |
| `test_qa_gate_hook_mode_passes_unrelated_bash` | `qa_gate.py --hook-mode` mit `git status` → Exit 0 | FAIL: `--hook-mode` existiert nicht |
| `test_adversary_md_has_pre_fix_phase` | Datei enthält "Phase 3b: Pre-Fix-Test-Validation" | FAIL: Phase fehlt |
| `test_adversary_md_has_before_after_table` | Datei enthält "Vor Fix" Tabellen-Header | FAIL: Tabelle fehlt |
| `test_validator_md_has_test_quality_audit` | Datei enthält "Test-Quality-Audit" | FAIL: Schritt fehlt |
| `test_validator_md_forbids_green_as_proof` | Datei enthält "Tests sind grün als Beweis" in Verboten-Liste | FAIL: Eintrag fehlt |
| `test_qa_writer_md_forbids_silent_pass` | Datei enthält "guard let" Verbot | FAIL: Verbot fehlt |
| `test_developer_md_handles_silent_pass_blocker` | Datei enthält "BLOCKER an Orchestrator melden" | FAIL: Eintrag fehlt |
| `test_claude_md_has_anti_pattern_section` | `CLAUDE.md` enthält "Anti-Pattern: Silent-Pass-Tests" | FAIL: Section fehlt |
| `test_settings_json_registers_test_quality_gate` | `settings.json` enthält `test_quality_gate.py` als Hook | FAIL: nicht registriert |
| `test_settings_json_registers_qa_gate_hook_mode` | `settings.json` enthält `qa_gate.py --hook-mode` als Hook | FAIL: nicht registriert |

**Insgesamt: 17 Tests, alle RED in TDD-Phase.**

### UI-Tests

Nicht anwendbar — reine Infrastruktur-Änderung (Python-Hooks + Markdown). Python-unittest-Tests ersetzen UI-Tests (etablierte Konvention für INFRA-Tickets, vgl. INFRA_013, INFRA_014, INFRA_015).

---

## Expected Behavior

- **Input:** Edit/Write auf Test-Datei mit Silent-Pass-Pattern
- **Output:** Exit 2 mit klarer Fehlermeldung, Datei wird nicht geschrieben
- **Side effects:** Keine — Hooks sind read-only

- **Input:** Bash `workflow.py mark-red <ungültiger-output>`
- **Output:** Exit 2, Phase-Übergang findet nicht statt
- **Side effects:** Keine

- **Input:** Adversary-Run im Bug-Workflow
- **Output:** Report enthält Pre-Fix/Post-Fix Tabelle, jeder Test bewiesen rot ohne Fix
- **Side effects:** Vorübergehender `git stash` während Adversary-Lauf — wird zurückgesetzt

---

## Known Limitations

- **Regex-basierte Pattern-Erkennung** kann false positives erzeugen bei kreativen Test-Strukturen. Bypass via `__infra__`-Token vorhanden.
- **Pre-Fix-Validation funktioniert nur bei Bug-Workflows** mit klar abgrenzbaren Code-Änderungen. Bei großen Refactorings kann `git stash` Konflikte erzeugen — dann manueller Adversary-Eingriff nötig.
- **Maßnahme B greift nur bei `mark-red`/`mark-green`** — wenn Orchestrator diese gar nicht aufruft (bypass), wirkt der Hook nicht. Andere Gates (Phase-Transition in workflow.py) bleiben aber bestehen.
- **Keine AST-Analyse** — wir parsen nicht die ganze Swift-Syntax, nur Regex auf häufigste Patterns. Komplexere Silent-Passes (z.B. via Custom-Helper-Funktionen) entgehen uns. Adversary Pre-Fix-Validation fängt diese.

---

## Scope-Limit

| Datei | Geschätzte LoC |
|-------|----------------|
| `.claude/hooks/test_quality_gate.py` (neu) | ~120 |
| `.claude/hooks/qa_gate.py` (Hook-Mode dazu) | ~50 |
| `.claude/settings.json` | ~10 |
| `.claude/commands/adversary.md` | ~40 |
| `.claude/agents/implementation-validator.md` | ~30 |
| `.claude/agents/qa-writer.md` | ~10 |
| `.claude/agents/developer.md` | ~10 |
| `CLAUDE.md` | ~15 |
| `.claude/hooks/tests/test_silent_pass_hardening.py` (neu) | ~250 |
| **Gesamt** | **~535 LoC, 9 Dateien** |

**Hinweis:** Überschreitet das Standard-Limit (max 5 Dateien, ±250 LoC). Begründung: INFRA-Tickets dieser Größe sind dokumentiert üblich (INFRA_014: 6 Files, INFRA_013: 4 Files + Tests). Test-Datei zählt nicht zum Scope-Limit (eigene LoC-Klasse).

---

## Changelog

- 2026-04-25: Initial spec created
