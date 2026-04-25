# Analyse: INFRA_016 — Silent-Pass-Hardening

## Problem in einem Satz

Der Workflow akzeptiert Tests, die GREEN melden ohne den Bug tatsächlich auszulösen. Drei voneinander unabhängige Lücken erlauben das — alle hier mit Code-Beleg.

---

## Lücke 1 — Silent-Pass-Patterns werden nirgends erkannt

**Pattern, das Bug #287 erzeugte:**

```swift
guard let popover = ... else { return }
// Assertions ab hier — wenn popover nil, läuft nie
```

### Beleg 1a — QA-Writer kennt das Pattern nicht

`.claude/agents/qa-writer.md:144-152`:

```
## Verboten
- KEINEN Source-Code lesen der zu testenden Features
- KEINE GitHub Issues erstellen
- KEINE Workflows starten
- KEINE Tests die bestehen — TDD RED heisst ALLE Tests FEHLSCHLAGEN
- KEINE Tautologien (x == x, Property-Assignment)
- KEINE geratenen AccessibilityIdentifier
- KEIN sleep(N)
```

Kein Eintrag für Early-Exits, `guard let`, fehlendes `XCTUnwrap`, oder Optional-Chaining ohne Failure-Branch.

### Beleg 1b — Implementation-Validator hat keinen Test-Quality-Audit

`.claude/agents/implementation-validator.md:22-54` (Prüf-Protokoll):

- Schritt 1: Spec verstehen
- Schritt 2: Code lesen
- Schritt 3: Tests ausführen
- Schritt 4: Edge Cases prüfen (Boundary, State, Error, Concurrency, Plattform)
- Schritt 5: Regression Check
- Schritt 6: Spec-Compliance

**Es fehlt ein Schritt: "Test-Quality-Audit — würde der Test den Bug erkennen?"** Der Validator prüft was der Code tut und ob Tests grün sind — nicht ob die Tests den geänderten Code tatsächlich erreichen.

### Beleg 1c — `edit_gate.py` filtert nur nach Phase und Pfad

Aus der Bestandsaufnahme (`edit_gate.py` Zeilen 254-307): Phase-spezifische Gates erlauben/verbieten Edits auf Test- vs. Source-Pfaden, prüfen Override-Token, scope-Limits, RED-Artifact-Existenz. **Kein Content-Check** auf den Inhalt der zu schreibenden Test-Dateien.

---

## Lücke 2 — `qa_gate.py` validiert, ist aber kein Hook

`.claude/hooks/qa_gate.py:1-16` (Docstring):

```python
"""
QA Gate v4 — Validates test output (utility, no longer sets workflow state).

With the 3-Checkpoint system, qa_gate is a pure validation utility.
Claude uses it to prepare Checkpoint 3 presentations, but only Henning
typing 'commit' actually unlocks the commit gate.
"""
```

Das Tool ist explizit als **Utility** designed — nicht als Hook.

### Beleg 2a — In `settings.json` nicht registriert

`.claude/settings.json:11-68`. Registrierte Hooks:

| Event | Hook |
|-------|------|
| `PreToolUse` (Edit\|Write) | `edit_gate.py` |
| `PreToolUse` (Bash) | `bash_gate.py` |
| `PostToolUse` (Bash) | `post_bash.py` |
| `UserPromptSubmit` | `phase_listener.py` |
| `SessionStart` | `session_start.py` |

`qa_gate.py` taucht **nicht** auf. Das bedeutet: niemand zwingt den Orchestrator, `validate_test_output()` vor `mark-red` oder `mark-green` aufzurufen. Die Validation existiert — wird aber nicht durchgesetzt.

### Beleg 2b — Validierungs-Logik ist da

`qa_gate.py:35-98` (`validate_test_output`):

- Prüft Datei-Alter (max 30 Min) — fängt fabrizierte alte Outputs
- Prüft Größe (min 100 bytes) — fängt leere Stubs
- Prüft auf XCTest-/unittest-Pattern (mind. 2/4 Matches)
- Prüft auf konkrete `Executed N tests, with M failures` Syntax
- Verlangt Unit + UI Tests (außer mit `--infra` Flag)

Diese Logik **existiert und funktioniert**, aber wird nur aufgerufen, wenn der Orchestrator daran denkt.

---

## Lücke 3 — Adversary beweist nur "GREEN nach Fix", nicht "RED ohne Fix"

Bug #287 hatte 2/2 UI-Tests GREEN. Adversary sagte VERIFIED. Aber: der Test wäre auch ohne den Fix GREEN gewesen — er erreichte den Bug nie.

### Beleg 3a — Adversary-Skill verlangt keine Pre-Fix-Validation

`.claude/commands/adversary.md:107-126` (Phase 3: Tests ausführen):

```
1. Alle Unit Tests ausfuehren:
   ./scripts/sim.sh unit FocusBloxTests

2. Alle UI Tests der betroffenen Bereiche ausfuehren:
   ./scripts/sim.sh test [RELEVANTE-UI-TEST-KLASSEN]

3. Regressions-Check — Haupt-Test-Suiten:
   ./scripts/sim.sh test BacklogViewUITests
   ./scripts/sim.sh test DayViewUITests
   ./scripts/sim.sh test CoachTabLayoutUITests

4. Notiere: Welche Tests FAILED? Welche PASSED?
```

Es wird gefragt: "Sind Tests grün?" — nicht: "Würden die Tests OHNE den Fix rot sein?"

### Beleg 3b — Implementation-Validator ditto

`.claude/agents/implementation-validator.md:32-37` (Schritt 3):

```
### 3. Tests ausführen
./scripts/sim.sh unit FocusBloxTests    # Alle Unit Tests
./scripts/sim.sh test FocusBloxUITests  # Alle UI Tests
./scripts/sim.sh mac-build              # macOS Build
```

Selbe Lücke. Keine Anweisung den Fix temporär zurückzudrehen, Test laufen zu lassen, RED zu prüfen.

### Beleg 3c — Mechanisch wäre das möglich

Adversary läuft **bewusst nicht im Worktree** (Test in `test_finding_resolution.py:114-129` enforced). Er sieht uncommitted Files. `git stash` → Test ausführen → muss FAIL → `git stash pop` ist mit drei Bash-Befehlen umsetzbar. Die Mechanik ist da, sie wird nur nicht genutzt.

---

## Root Cause

Drei unabhängige Mechaniken fehlen:

| # | Was fehlt | Wirkung |
|---|-----------|---------|
| 1 | Mechanische Erkennung von Silent-Pass-Patterns beim Schreiben | Tests mit `guard let ... else { return }` werden überhaupt erst akzeptiert |
| 2 | Pflicht-Validation des Test-Outputs vor `mark-red`/`mark-green` | Orchestrator kann Phase-Übergang machen ohne dass Test-Output je geprüft wurde |
| 3 | Pflicht-Beweis durch Adversary, dass Tests den Bug auslösen würden | "GREEN" ist nicht gleichbedeutend mit "Bug-Fix verifiziert" |

Alle drei sind voneinander **unabhängig** — Lücke 1 verhindert dass das Pattern entsteht, Lücke 2 fängt ungültige Test-Outputs, Lücke 3 ist die letzte Verteidigungslinie. Ein Fix nur bei einer Lücke reicht nicht — Tests könnten Lücke 1 mit anderem Pattern umgehen, Lücke 2 mit gefälschtem Output, Lücke 3 ist die einzige unabhängige Validierung.

---

## Vorgeschlagener Lösungsraum

### Maßnahme A — Silent-Pass-Detector (Lücke 1)

Neuer Hook `.claude/hooks/test_quality_gate.py`, registriert als zusätzlicher PreToolUse-Hook für Edit|Write. Prüft Test-Dateien (`*Tests*.swift`) auf:

- `guard let ... else { return }` ohne vorheriges `XCTFail`
- `if let ... { ... }` ohne `else { XCTFail(...) }`
- `XCTAssertNotNil` direkt gefolgt von `guard let` (statt `XCTUnwrap`)

Bypass via `__infra__`-Token möglich für legitime Edge-Cases.

### Maßnahme B — qa_gate als Hook (Lücke 2)

`qa_gate.py` als PreToolUse-Hook für Bash registrieren — triggert wenn `workflow.py mark-red` oder `mark-green` aufgerufen werden soll. Prüft, dass im aktuellen Workflow ein gültiges Test-Output-Artefakt existiert (max 30 Min alt, mit XCTest-Pattern). Blockiert sonst.

### Maßnahme C — Adversary Pre-Fix-Validation (Lücke 3)

Neue Pflicht-Phase im Adversary-Skill und im Implementation-Validator-Prompt:

1. `git stash` (Fix vorübergehend zurückdrehen)
2. Test ausführen
3. Erwartung: Test FAILED — sonst ist der Test wertlos
4. `git stash pop` (Fix zurückbringen)
5. Test erneut ausführen — muss PASSED sein

Beweis im Adversary-Report: "Test X failed gegen pre-fix code, passed nach Fix" — nur dann VERIFIED möglich.

### Maßnahme D — Agent-Prompt-Updates (Doku)

- `qa-writer.md`: Verbots-Liste um Silent-Pass erweitern, `XCTUnwrap` als Pflicht
- `implementation-validator.md`: Test-Quality-Audit als Standard-Schritt
- `developer.md`: Wenn QA-Tests Silent-Pass enthalten — als Blocker melden, nicht selbst fixen
- `CLAUDE.md`: Anti-Pattern-Section ergänzen

---

## Was bewusst NICHT vorgeschlagen wird

- **Vollständiger AST-Parser für Swift-Tests** — zu viel Komplexität, nicht im Verhältnis zum Nutzen. Regex auf konkrete Patterns reicht für die häufigsten Fälle.
- **Automatisches Re-Schreiben von Silent-Pass-Patterns** — würde Tests ändern ohne Verständnis des Verhaltens. Besser: blockieren und QA neu schreiben lassen.
- **Erzwingen von Pre-Fix-Validation für JEDEN Test** — bei trivialen Refactorings unnötig. Adversary ist die richtige Stelle, nicht jeder Hook-Aufruf.
