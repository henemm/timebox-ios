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
python3 .claude/hooks/workflow.py status
```

**If TDD RED artifacts are missing, the `tdd_enforcement` hook will BLOCK your edits!**

## Your Tasks

### Step 1: Verify RED Phase Complete

```bash
python3 .claude/hooks/workflow.py status
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

python3 .claude/hooks/workflow.py add-artifact test_output "docs/artifacts/[workflow]/test-green-output.txt" "All tests PASSED" phase6_implement
```

### Step 6: User-Freigabe der GREEN-Ergebnisse (PFLICHT)

**STOP! Du darfst NICHT weitermachen ohne User-Freigabe!**

Praesentiere dem User eine verstaendliche Zusammenfassung:

```markdown
## TDD GREEN Ergebnisse

### Was wurde getestet?
- [Feature/Bug in User-Sprache beschreiben]

### Test-Ergebnisse
- Unit Tests: [N] bestanden, [N] fehlgeschlagen
- UI Tests: [N] bestanden, [N] fehlgeschlagen

### Was die Tests pruefen
- [Beschreibung in User-Sprache, z.B. "Task wird erstellt und erscheint in der Liste"]
- [Nicht: "XCTAssertTrue(button.exists)" sondern: "Der Speichern-Button ist sichtbar"]

### Auffaelligkeiten / Warnungen
- [Alles was aufgefallen ist — auch wenn DU es fuer irrelevant haeltst]
- [Der USER entscheidet was relevant ist, nicht du!]

Sage "go" wenn du mit den Ergebnissen zufrieden bist.
```

**WICHTIG:**
- Du darfst NICHT selbst entscheiden ob Auffaelligkeiten relevant sind
- Du darfst NICHT "go" simulieren oder die Freigabe umgehen
- Der `tdd_green_gate` Hook BLOCKT /06-validate ohne User-Freigabe
- Der User gibt frei mit: "go", "weiter", "tests ok", "green ok"

### Step 7: Update Workflow State to Adversary Phase

```bash
python3 .claude/hooks/workflow.py phase phase6b_adversary
```

### Step 8: Run Adversary Dialog (MANDATORY)

**Du kannst NICHT direkt zu `/06-validate` springen. Der Adversary-Dialog muss zuerst stattfinden.**

#### 8a. Spec parsen — Checkliste erstellen

```bash
python3 .claude/hooks/adversary_dialog.py parse <spec-pfad>
```

Das zeigt dir die Expected-Behavior-Punkte die bewiesen werden muessen.

#### 8b. Adversary-Dialog fuehren

Starte den `implementation-validator` Agent mit der Checkliste:

```
Task (implementation-validator): "Pruefe den aktuellen Workflow gegen die Spec.
  Hier ist die Checkliste der zu beweisenden Punkte:
  [Punkte aus 8a einfuegen]

  REGELN:
  - Lies NUR die Spec (nicht den Code!)
  - Fordere fuer JEDEN Punkt einen Beweis (Screenshot, Test-Output, konkreter Code-Pfad)
  - Akzeptiere NICHT die erste Antwort — bohre nach, frage nach Edge Cases
  - Mindestens 2 Runden Dialog
  - Fuehre Tests aus → /tmp/adversary_test_output.txt
  - Mach Screenshots → /tmp/adversary_screenshot.png"
```

Der Dialog laeuft als Hin-und-Her zwischen dir (Implementierer) und dem Agent (Adversary):
1. Agent nennt naechsten offenen Punkt + was er sehen will
2. Du lieferst Beweis (Screenshot, Test-Output)
3. Agent bewertet: AKZEPTIERT oder NACHFRAGE
4. Wiederholen bis alle Punkte bewiesen ODER Defekt gefunden

#### 8c. Dialog-Protokoll speichern

Speichere das Protokoll als Artifact:
```
docs/artifacts/<workflow-name>/adversary-dialog.md
```

Format: Siehe `adversary_dialog.py render_dialog_artifact()` — mit Checkliste, Runden, Verdict.

Registriere das Artifact im Workflow:
```bash
python3 .claude/hooks/workflow.py add-artifact adversary_dialog "docs/artifacts/<workflow-name>/adversary-dialog.md" "Adversary Dialog Protokoll" phase6b_adversary
```

#### 8d. QA-Gate mit Checklist-Validierung

```bash
# Fuer App-Features (mit XCTest-Output):
python3 .claude/hooks/qa_gate.py /tmp/adversary_test_output.txt \
  --checklist docs/artifacts/<workflow-name>/adversary-dialog.md \
  --screenshot /tmp/adversary_screenshot.png

# Fuer Infra-Tickets (mit Python-unittest-Output, ohne UI):
python3 .claude/hooks/qa_gate.py /tmp/adversary_test_output.txt \
  --checklist docs/artifacts/<workflow-name>/adversary-dialog.md \
  --infra --no-visual "Infra-Ticket ohne UI"
```

Das Gate prueft zusaetzlich:
- Alle Checklisten-Punkte bewiesen ([x])
- Mindestens 2 Dialog-Runden dokumentiert
- Artifact ist aktuell (< 60 Min)

**Wenn BROKEN:**
- Fixen und Step 7 wiederholen (neuer Dialog!)

**Wenn VERIFIED:**
- Weiter zu Phase 7:
```bash
python3 .claude/hooks/workflow.py phase phase7_validate
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
- **Skipping User-Freigabe** -> tdd_green_gate BLOCKT validation
