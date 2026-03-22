# Phase 6: Implementation (TDD GREEN)

You are in **Phase 6 - Implementation / TDD GREEN Phase**.

## Purpose

Write the **minimal code** to make failing tests pass. No more, no less.

## Prerequisites

- Spec approved (`phase4_approved`)
- TDD RED complete (`phase5_tdd_red`)
- Test artifacts registered showing failures

Check status:
```bash
python3 .claude/hooks/workflow_state_multi.py status
```

**If TDD RED artifacts are missing, the `tdd_enforcement` hook will BLOCK your edits!**

## Your Tasks

### Step 1: Verify RED Phase Complete

```bash
python3 .claude/hooks/workflow_state_multi.py status
```

### Step 2: Kontext laden (Explore/Haiku)

Dispatche einen **Explore/Haiku Subagenten** um den Implementierungs-Kontext zu laden:

```
Task (Explore/haiku): "Lies folgende Dateien und fasse den relevanten Kontext
  zusammen:
  - Spec: [spec_file_path]
  - Betroffene Dateien: [affected_files]
  - Test-Dateien: [test_files]

  Fasse zusammen: Welche Interfaces existieren, welche Methoden muessen
  implementiert werden, welche Imports werden benoetigt."
```

### Step 3: Implementieren (Hauptkontext / Opus)

Die eigentliche Implementation passiert im **Hauptkontext** (Opus) fuer hoechste Qualitaet:

- Lies und befolge die approved Spec exakt
- Schreibe Code der die Tests gruen macht
- Halte dich an die Scoping-Limits

**TDD GREEN Rules:**
- Only write code that makes a test pass
- Don't add features not covered by tests
- Don't optimize prematurely
- Don't refactor yet

### Step 4: Parallele Side-Tasks

Dispatche parallel waehrend/nach der Implementation:

```
Task 1 (general-purpose/haiku): "Fuehre die Tests aus:
  xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
    -destination 'id=548B4A2F-FDFF-4F9E-8335-1A7A7B98E492'
  Fasse Ergebnisse zusammen: passed/failed/errors."

Task 2 (general-purpose/haiku): "Pruefe ob Konfigurationsdateien
  aktualisiert werden muessen fuer [Feature].
  Check: Info.plist, xcstrings, Assets.xcassets."
```

### Step 5: GREEN Artifacts erfassen

```bash
# Test output erfassen
xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
  -destination 'id=548B4A2F-FDFF-4F9E-8335-1A7A7B98E492' \
  2>&1 > docs/artifacts/[workflow]/test-green-output.txt

python3 .claude/hooks/workflow_state_multi.py add-artifact test_output "docs/artifacts/[workflow]/test-green-output.txt" "All tests PASSED" phase6_implement
```

### Step 6: Update Workflow State to Adversary Phase

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase6b_adversary
```

### Step 7: Run Adversary Verification (MANDATORY)

**Du kannst NICHT direkt zu `/06-validate` springen. Der Adversary muss zuerst pruefen.**

Starte den `implementation-validator` Agent:

```
Task (implementation-validator): "Pruefe den aktuellen Workflow.
  Lies die Spec, fuehre Tests aus, mach Screenshots, pruefe Edge Cases.
  Ruf am Ende adversary_gate.py auf."
```

Der Adversary-Agent:
1. Liest NUR die Spec (nicht den Code)
2. Fuehrt Tests aus → `/tmp/adversary_test_output.txt`
3. Macht Screenshots → `/tmp/adversary_screenshot.png`
4. Prueft Edge Cases
5. Ruft `adversary_gate.py` auf → setzt Verdict

**Wenn Adversary BROKEN meldet:**
- Fixen und Step 7 wiederholen

**Wenn Adversary VERIFIED meldet:**
- Weiter zu Phase 7:
```bash
python3 .claude/hooks/workflow_state_multi.py phase phase7_validate
```

## Implementation Constraints

Follow scoping limits:
- **Max 4-5 files** per change
- **Max +/-250 LoC** total
- **Functions <= 50 LoC**
- **No side effects** outside spec scope

## Next Step

After adversary verification:
> "Implementation complete. Adversary verified. Ready for `/06-validate`."

## Common Mistakes

- **Adding unrequested features** -> Scope creep
- **Skipping tests** -> Not TDD
- **Large functions** -> Hard to test/maintain
- **Not running tests** -> Might still be RED
- **Skipping adversary** -> Commit will be BLOCKED
