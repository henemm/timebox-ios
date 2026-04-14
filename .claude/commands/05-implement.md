# Phase 5: Implementation (TDD GREEN)

You are in **Phase 5 - Implementation / TDD GREEN Phase**.

## Purpose

Write the **minimal code** to make failing tests pass. No more, no less.

## Prerequisites

- Spec approved
- TDD RED complete (`phase4_tdd_red`)
- Checkpoint 2 approved (Henning said "go")
- Test artifacts registered showing failures

Check status:
```bash
python3 .claude/hooks/workflow.py status
```

## Your Tasks

### Step 1: Verify RED Phase Complete

```bash
python3 .claude/hooks/workflow.py status
```

### Step 2: Kontext laden

Lies die Spec und betroffene Dateien. Verstehe was implementiert werden muss.

### Step 3: Implementieren

- Lies und befolge die approved Spec exakt
- Schreibe Code der die Tests gruen macht
- Halte dich an die Scoping-Limits

**TDD GREEN Rules:**
- Only write code that makes a test pass
- Don't add features not covered by tests
- Don't optimize prematurely
- Don't refactor yet

### Step 4: Tests ausfuehren

```bash
./scripts/sim.sh unit [TestClass]
./scripts/sim.sh test [UITestClass]
```

Bei Shared-Code-Aenderungen (`Sources/`): AUCH `./scripts/sim.sh mac-build` ausfuehren!

### Step 5: GREEN Artifacts erfassen

```bash
python3 .claude/hooks/workflow.py mark-green "[N] unit tests passed"
python3 .claude/hooks/workflow.py mark-ui-green "[M] UI tests passed"
```

### Step 6: Bug-Reproduktion wiederholen (NUR bei Bug-Workflows)

**Wenn `workflow_type == bug`:**

1. **Gleiche Schritte wie bei der urspruenglichen Reproduktion ausfuehren**
2. **Nachher-Screenshot machen:**
```bash
./scripts/sim.sh screenshot /tmp/bug_nachher.png
```
3. **Vergleich:** Ist der Bug weg? Sieht es korrekt aus?

Wenn der Bug immer noch auftritt → **Fix ueberarbeiten, NICHT zum Checkpoint!**

### Step 7: **CHECKPOINT 3** — Henning das Ergebnis praesentieren

**STOP! Ohne Hennings Freigabe kein Commit!**

Praesentiere:

```markdown
## Ergebnis

### Was wurde gebaut/gefixt?
- [In User-Sprache, 1-2 Saetze]

### Test-Ergebnisse
- Unit Tests: [N] bestanden
- UI Tests: [M] bestanden
- ALL GREEN ✓

### Visuelle Pruefung
- [Bei Bugs: Vorher-Screenshot + Nachher-Screenshot]
- [Bei Features: Screenshot des fertigen Features + Vergleich mit User-Erwartung]

### Auffaelligkeiten
- [Alles was aufgefallen ist — DU entscheidest NICHT was relevant ist]

Sage "commit" wenn du zufrieden bist.
Optional: Starte `/adversary` in einer zweiten Claude-Session fuer eine unabhaengige Pruefung.
```

**Henning sagt "commit" → Checkpoint 3 freigeschaltet → Commit erlaubt.**

### Step 7: Commit + Cleanup

```bash
python3 .claude/hooks/workflow.py phase phase6_done
# Git commit (mit Issue-Referenz!)
# GitHub Issue schliessen
python3 .claude/hooks/workflow.py complete
```

## Implementation Constraints

- **Max 4-5 files** per change
- **Max +/-250 LoC** total
- **Functions <= 50 LoC**
- **No side effects** outside spec scope

## Common Mistakes

- **Adding unrequested features** -> Scope creep
- **Skipping tests** -> Not TDD
- **Large functions** -> Hard to test/maintain
- **Not running tests** -> Might still be RED
