# Phase 4: TDD RED - Write Failing Tests

You are in **Phase 4 - TDD RED Phase**.

## Purpose

Write tests BEFORE implementation. Tests MUST FAIL because the functionality doesn't exist yet.

**If tests pass → you're not doing TDD, you're testing existing code.**

## ⛔ STOP — Verstehst du das Problem?

**Bevor du einen einzigen Test schreibst, beantworte diese Fragen:**

1. **Was genau ist das gewuenschte Verhalten?** (Nicht die Implementierung — das VERHALTEN.)
2. **Welche Eingaben fuehren zu welchen Ausgaben?** (Konkret, nicht abstrakt.)
3. **Fuer jeden geplanten Test: Welche EINE Zeile in der Implementierung muesste ich aendern, damit dieser Test fehlschlaegt?**

Wenn du Frage 3 nicht beantworten kannst → der Test ist wertlos. Schreib ihn nicht.

**Verbotene Tests:**
- `XCTAssertEqual(x, x)` — Tautologie
- `task.prop = 5; XCTAssertEqual(task.prop, 5)` — testet Swift-Assignment
- Tests die nur Swift-Defaults pruefen (nil, 0, false)
- Tests die keine echte Funktion aufrufen

## Prerequisites

- Spec approved
- Checkpoint 1 approved (Henning said "stimmt")
- Test plan defined in spec

Check status:
```bash
python3 .claude/hooks/workflow.py status
```

## Your Tasks

### 1. Enter TDD RED Phase

```bash
python3 .claude/hooks/workflow.py phase phase4_tdd_red
```

### 1b. Inspect-UI (PFLICHT vor UI-Tests)

**⛔ Gate-enforced:** Der edit_gate Hook blockiert UI-Test-Writes ohne vorheriges `/inspect-ui`.

Fuehre `/inspect-ui` aus fuer den Ziel-Screen um AccessibilityIdentifier zu finden.
Danach wird `inspect_ui_done` automatisch im Workflow registriert.

### 2. QA-Agent dispatchen (PFLICHT fuer Swift-Features/Bugs)

**Spawne den QA-Agent der Tests UNABHAENGIG schreibt — nur basierend auf Spec + User-Erwartung:**

```
Agent(subagent_type: "qa-writer", model: "sonnet")
```

Prompt:
> Du bist QA. Schreibe Tests die beweisen dass das Feature/der Fix funktioniert.
>
> Spec: [spec_file Pfad]
> User-Erwartung: [Zusammenfassung aus Phase 2]
> inspect-ui Output: [falls vorhanden, einfuegen]
>
> Regeln:
> - Tests MUESSEN FEHLSCHLAGEN (TDD RED)
> - Unit Tests PFLICHT bei Business-Logik
> - UI Tests PFLICHT fuer jedes Feature/Bug
> - Tests pruefen VERHALTEN, nicht Implementation

**Ausnahme:** Bei reinen Infrastruktur-Aenderungen (Python Hooks, Scripts) schreibt der Orchestrator die Tests selbst — der QA-Agent ist fuer Swift-Code gedacht.

### 3. Tests ausfuehren

Nachdem der QA-Agent die Test-Dateien geschrieben hat:

```bash
./scripts/sim.sh unit [FeatureName]Tests 2>&1 | tee docs/artifacts/[workflow]/unit-test-red-output.txt
./scripts/sim.sh test [FeatureName]UITests 2>&1 | tee docs/artifacts/[workflow]/ui-test-red-output.txt
```

### 4. Alle Tests ausfuehren — MUESSEN FEHLSCHLAGEN (RED)

**EXPECTED:** Alle Tests FAIL mit klaren Fehlermeldungen.

```bash
grep -E "(passed|failed|error:)" docs/artifacts/[workflow]/unit-test-red-output.txt
grep -E "(passed|failed|error:)" docs/artifacts/[workflow]/ui-test-red-output.txt
```

### 5. RED-Artefakte registrieren

```bash
# Register artifacts
python3 .claude/hooks/workflow.py add-artifact test_output "docs/artifacts/[workflow]/unit-test-red-output.txt" "Unit Test FAILED: [describe what failed]" phase4_tdd_red
python3 .claude/hooks/workflow.py add-artifact ui_test_output "docs/artifacts/[workflow]/ui-test-red-output.txt" "UI Test FAILED: [describe what failed]" phase4_tdd_red

# Set mandatory RED flags
python3 .claude/hooks/workflow.py mark-red "failed: [describe what failed]"
python3 .claude/hooks/workflow.py mark-ui-red "failed: [describe what failed]"
```

### 6. Test-Snapshot erstellen (Regressions-Schutz)

**PFLICHT:** Snapshot aller Test-Methoden speichern. Der `test_regression_guard` Hook
blockt spaeter jedes Entfernen von Tests ohne PO-Genehmigung.

```bash
python3 .claude/hooks/workflow.py snapshot-tests
```

## RED Phase Checklist

- [ ] Ich kann fuer JEDEN Test sagen welche Zeile ihn brechen wuerde
- [ ] Unit Tests geschrieben — PFLICHT bei Business-Logik
- [ ] Unit Tests ausgefuehrt und FEHLGESCHLAGEN
- [ ] UI Tests geschrieben in `FocusBloxUITests/`
- [ ] UI Tests ausgefuehrt und FEHLGESCHLAGEN
- [ ] `mark-red` und `mark-ui-red` gesetzt
- [ ] Alle Artefakte registriert
- [ ] **CHECKPOINT 2 praesentieren** — Henning sagt "go"

## Next Step

```bash
python3 .claude/hooks/workflow.py phase phase5_implement
```

## Common Mistakes

❌ **Test schreiben ohne das Problem verstanden zu haben** → STOP, zurueck zu Frage 1-3
❌ **Tautologie-Tests** (`x == x`, Property-Assignment) → Test ist wertlos
❌ **Tests that pass** → You're not doing TDD
❌ **No UI tests** → Hook will block implementation
❌ **Unit Tests "optional"** → PFLICHT bei Business-Logik
