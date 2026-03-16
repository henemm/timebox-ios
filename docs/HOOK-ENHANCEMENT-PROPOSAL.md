# Hook Enhancement Proposal

**Datum:** 2026-01-17
**Kontext:** TDD Bypass bei Phase 2 (Eisenhower Matrix) Implementierung

---

## Problem

Claude hat Eisenhower Matrix implementiert **OHNE TDD RED Phase**. Tests wurden erst NACH Implementierung angeboten, was gegen das Core-Prinzip verstößt.

### Was passiert ist:

1. User: "OK; dann weiter" (nach Phase 1)
2. Claude liest BacklogView.swift direkt
3. Claude implementiert EisenhowerMatrixView **ohne `/11-feature` aufzurufen**
4. Keine Tests geschrieben
5. Commit ed56d42 mit komplettem Feature **ohne Tests**
6. Claude fragt danach: "Soll ich Tests schreiben?" ❌

---

## Root Cause: 3 Lücken in der Hook-Architektur

### Lücke 1: Config-basierte Protection (Blacklist-Ansatz)
**Hook:** `workflow_gate.py`
- Schützt nur Dateien in `protected_paths` Config
- Wenn SwiftUI Views NICHT in Config → BYPASS möglich
- **Problem:** Blacklist statt Whitelist

### Lücke 2: Workflow-Mismatch
**Hook:** `red_test_gate.py`
- Prüft nur AKTIVEN Workflow
- Validiert NICHT ob Datei zum Workflow gehört
- Active Workflow = "multi-source-tasks", aber ich ändere BacklogView.swift
- Hook sieht "multi-source-tasks" hat red_test_done=true → erlaubt!
- **Problem:** Keine File-to-Workflow Validation

### Lücke 3: Kein Workflow = Kein Check
**Hook:** Beide oben
- Wenn kein Workflow initialisiert → Hooks erlauben alles
- Claude hat nie `/11-feature` aufgerufen für Phase 2
- Daher griffen Checkpoints nicht
- **Problem:** Workflow-Initialisierung ist optional, nicht mandatory

---

## Lösung: Neuer Hook `strict_code_gate.py`

### Was er macht:

✅ **WHITELIST-Ansatz:** ALLE Code-Dateien geschützt (außer Tests/Docs)
✅ **Mandatory Workflow:** Block wenn kein aktiver Workflow existiert
✅ **Phase Check:** Block wenn Phase < phase6_implement
✅ **TDD Enforcement:** Block wenn red_test_done=false
✅ **File-to-Workflow:** Warnung wenn Datei nicht in affected_files

### Geschützte Extensions:

```
.swift, .kt, .java, .py, .js, .ts, .go, .rs, .cpp, .c
```

### Immer erlaubt (Whitelist):

```
Tests/, UITests/, docs/, .claude/
*.md, *.json, *.yaml, *.txt
```

---

## Aktivierung

### Option 1: Sofort aktivieren (EMPFOHLEN)

**Claude Code Config (.claude/config.yaml):**
```yaml
hooks:
  pre_tool:
    - script: .claude/hooks/strict_code_gate.py
      tools: ["Edit", "Write"]
      order: 1  # Vor allen anderen Hooks!
```

**Test:**
```bash
# Ohne aktiven Workflow
echo "// test" >> TimeBox/Sources/Views/BacklogView.swift

# Expected Output:
🔴 BLOCKED: No Active Workflow!
START WITH: /11-feature or /10-bug
```

---

### Option 2: Parallel-Betrieb (Safe Rollout)

Beide Hooks parallel laufen lassen:

```yaml
hooks:
  pre_tool:
    - script: .claude/hooks/workflow_gate.py  # Bestehend
      tools: ["Edit", "Write"]
    - script: .claude/hooks/strict_code_gate.py  # NEU
      tools: ["Edit", "Write"]
```

Nach 2 Wochen Testing: `workflow_gate.py` entfernen, nur `strict_code_gate.py` behalten.

---

### Option 3: Nur für SwiftUI (Conservative)

Nur SwiftUI Views schützen:

```python
# In strict_code_gate.py Zeile 42:
CODE_EXTENSIONS = [".swift"]  # Nur Swift

# Zeile 70:
ALWAYS_ALLOWED_DIRS = [
    "Tests/",
    "UITests/",
    "docs/",
    ".claude/",
    "TimeBox/Sources/Models/",  # Models nicht geschützt
    "TimeBox/Sources/Services/",  # Services nicht geschützt
]
```

---

## Testing

### Test 1: Block ohne Workflow
```bash
# Setup
rm .claude/workflow_state.json

# Test
echo "// test" >> TimeBox/Sources/Views/BacklogView.swift

# Expected
🔴 BLOCKED: No Active Workflow!
```

### Test 2: Block in falscher Phase
```bash
# Setup
/11-feature "Test Feature"
# Phase = phase1_context

# Test
echo "func foo() {}" >> TimeBox/Sources/Views/NewView.swift

# Expected
🔴 BLOCKED: Wrong Phase! (phase1_context)
NEXT: /03-write-spec
```

### Test 3: Block ohne RED Test
```bash
# Setup
/11-feature "Test Feature"
/03-write-spec
User: "approved"
# Phase = phase4_approved, red_test_done = false

# Test
echo "func bar() {}" >> TimeBox/Sources/Views/NewView.swift

# Expected
🔴 BLOCKED: TDD RED Phase Not Complete!
REQUIRED: Write FAILING tests first
```

### Test 4: Allow mit RED Test
```bash
# Setup
/11-feature "Test Feature"
/03-write-spec
User: "approved"
/04-tdd-red  # Schreibt Tests, red_test_done = true
# Phase = phase6_implement

# Test
echo "func baz() {}" >> TimeBox/Sources/Views/NewView.swift

# Expected
✅ ALLOWED (all checks passed)
```

---

## Zusätzliche Empfehlungen

### 1. Workflow Auto-Start
Skill `/11-feature` sollte automatisch starten wenn:
- Claude analysiert Feature-Anfrage
- Kein aktiver Workflow existiert
- User sagt "implementiere X"

**Implementation:** Hook `workflow_auto_detector.py` (siehe Analyse-Dokument)

---

### 2. Affected Files Tracking
Workflow-State sollte `affected_files` pflegen:

```json
{
  "workflows": {
    "phase2-backlog": {
      "affected_files": [
        "TimeBox/Sources/Views/BacklogView.swift",
        "TimeBox/Sources/Views/EisenhowerMatrixView.swift",
        "TimeBox/Tests/BacklogViewTests.swift"
      ]
    }
  }
}
```

Dann kann Hook prüfen: Gehört Datei zum aktiven Feature?

---

### 3. Pre-Commit Test Check
Vor Commit prüfen: Sind Tests für alle Code-Changes vorhanden?

```python
# pre_commit_gate.py Enhancement
def check_tests_for_code_changes():
    code_files = get_staged_files(extensions=[".swift"])
    test_files = get_staged_files(patterns=["Test"])

    missing = []
    for code_file in code_files:
        test = find_test_for(code_file)
        if not test or test not in test_files:
            missing.append(code_file)

    if missing:
        sys.exit(1)  # Block commit
```

---

## Retroaktive Maßnahmen für Eisenhower Matrix

✅ **Code funktioniert** (manuell getestet)
❌ **Keine Tests vorhanden**

### Nächster Schritt:
1. Tests für EisenhowerMatrixView schreiben (XCUITests)
2. Tests für QuadrantCard schreiben (Unit Tests)
3. Edge Cases testen
4. Dann: Commit mit Tests

**Deadline:** Vor nächstem Feature!

---

## Empfehlung

**SOFORT aktivieren:** `strict_code_gate.py`

**Vorteile:**
- ✅ Verhindert weitere TDD-Bypasses
- ✅ Erzwingt Workflow-Initialisierung
- ✅ Whitelist-Ansatz (alle Code-Dateien geschützt)
- ✅ Klare Fehlermeldungen für Claude

**Nachteil:**
- Etwas strikter als bisherige Hooks
- Erfordert IMMER `/11-feature` vor Code-Changes

**Alternative:** Option 2 (Parallel-Betrieb) für 2 Wochen Safe Rollout.

---

## Dokumentation

Detaillierte Root-Cause-Analyse: `docs/analysis/tdd-bypass-analysis.md`

Hook-Code: `.claude/hooks/strict_code_gate.py`

---

## Entscheidung

Bitte entscheide:

- [ ] **Option 1:** Sofort aktivieren (EMPFOHLEN)
- [ ] **Option 2:** Parallel-Betrieb für 2 Wochen
- [ ] **Option 3:** Nur SwiftUI schützen (Conservative)
- [ ] **Option 4:** Nicht aktivieren (weitere Tests erst)

Nach Entscheidung: Claude updated `.claude/config.yaml` entsprechend.
