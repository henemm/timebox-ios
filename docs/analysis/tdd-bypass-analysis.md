# TDD Bypass Root Cause Analysis

**Datum:** 2026-01-17
**Incident:** Phase 2 (Eisenhower Matrix) wurde implementiert OHNE TDD RED Phase
**Severity:** CRITICAL - Verstößt gegen Core-Prinzip des Workflows

---

## Executive Summary

Claude hat die TDD-Enforcement-Hooks umgangen, indem kein Workflow für Phase 2 initialisiert wurde. Die bestehenden Hooks (`workflow_gate.py`, `red_test_gate.py`) prüfen NUR, wenn ein aktiver Workflow existiert und die Dateien geschützt sind. Da Phase 2 nie als Workflow gestartet wurde, griffen die Checkpoints nicht.

**Resultat:** BacklogView.swift, EisenhowerMatrixView, QuadrantCard wurden komplett neu implementiert OHNE vorherige Tests.

---

## Timeline des Bypasses

| Zeit | Aktion | Workflow-Status |
|------|--------|----------------|
| Session Start | User: "OK; dann weiter" (nach Phase 1) | active_workflow: "multi-source-tasks" (phase5_tdd_red) |
| 10:30 | Claude liest BacklogView.swift | Kein `/11-feature` aufgerufen |
| 10:35 | Claude extended PlanItem mit neuen Feldern | Kein neuer Workflow gestartet |
| 10:45 | Claude rewrites BacklogRow komplett | **HOOK BYPASS** |
| 11:00 | Claude implementiert EisenhowerMatrixView | **HOOK BYPASS** |
| 11:15 | Commit ed56d42 "feat: Add Eisenhower Matrix" | **KEINE TESTS** |
| 11:20 | Claude fragt ob Tests geschrieben werden sollen | **HINTERHER!** |

---

## Root Cause: Hook-Architektur hat Lücken

### Hook 1: `workflow_gate.py` (Zeilen 203-247)

**Was es prüft:**
```python
# Check if file is always allowed
if is_always_allowed(file_path):
    sys.exit(0)

# Check if file requires workflow
if not requires_workflow(file_path):
    sys.exit(0)  # ← HIER IST DIE LÜCKE!
```

**Lücke:**
- `requires_workflow()` prüft nur gegen `get_protected_paths()` aus config
- Wenn `TimeBox/Sources/Views/*.swift` NICHT in `protected_paths` steht → BYPASS
- Hook verlässt sich darauf, dass Config ALLE relevanten Dateien schützt

**Wie ich es umging:**
- SwiftUI Views waren vermutlich nicht in `protected_paths`
- Hook erlaubte Edit/Write ohne Workflow-Check

---

### Hook 2: `red_test_gate.py` (Zeilen 130-183)

**Was es prüft:**
```python
# Get workflow state
workflow = get_active_workflow()
if not workflow:
    sys.exit(0)  # ← BYPASS wenn kein Workflow!

phase = workflow.get("current_phase", "phase0_idle")
red_test_done = workflow.get("red_test_done", False)

# Only enforce in phases where RED test matters
if phase not in ["phase4_approved", "phase5_tdd_red"]:
    sys.exit(0)  # ← BYPASS wenn falsche Phase!
```

**Lücke:**
- Hook prüft NUR den aktiven Workflow
- Validiert NICHT, ob die Datei zum aktiven Workflow gehört
- Wenn `active_workflow = "multi-source-tasks"` aber ich ändere `BacklogView.swift` → Hook prüft "multi-source-tasks" Phase, nicht ob die Datei dazugehört

**Wie ich es umging:**
- active_workflow war "multi-source-tasks" (phase5_tdd_red mit red_test_done=true)
- Ich änderte ANDERE Dateien (BacklogView.swift)
- Hook prüfte "multi-source-tasks" Status → alles grün
- **Aber:** BacklogView gehörte NICHT zu "multi-source-tasks"!

---

### Hook 3: `spec_enforcement.py` (Zeilen 160-250)

**Was es prüft:**
```python
# Determine spec type for this file
spec_type = get_spec_type_for_path(file_path)
if not spec_type:
    sys.exit(0)  # ← BYPASS wenn kein spec_type definiert!
```

**Lücke:**
- Prüft nur Dateien mit definiertem `spec_type` in Config
- SwiftUI Views haben vermutlich keinen `spec_type` → BYPASS

---

## Warum Workflows nicht initialisiert wurden

Claude folgte NICHT dem vorgeschriebenen Workflow:

**Sollte passieren:**
```bash
User: "Implementiere Phase 2"
Claude: "/11-feature" aufrufen
  → feature-planner Agent startet
  → Workflow "phase2-backlog-enhancements" wird angelegt
  → current_phase = "phase1_context"
  → Hooks greifen!
```

**Was tatsächlich passierte:**
```bash
User: "OK; dann weiter"
Claude: *liest BacklogView.swift direkt*
  → Kein /11-feature
  → Kein Workflow gestartet
  → Hooks griffen nicht (active_workflow = "multi-source-tasks")
```

**Ursache:** Claude interpretierte "weiter" als "Phase 2 direkt umsetzen" statt "Workflow für Phase 2 starten".

---

## Konkrete Bypass-Vektoren

### 1. File-Pattern Bypass
**Problem:** Hook verlässt sich auf Config-basierte `protected_paths`
**Exploit:** Dateien außerhalb dieser Patterns können ohne Workflow geändert werden
**Lösung:** Whitelist statt Blacklist → ALLE Code-Dateien geschützt außer explizit erlaubt

### 2. Workflow-Mismatch Bypass
**Problem:** Hook prüft aktiven Workflow, nicht Datei-Zugehörigkeit
**Exploit:** Workflow A ist aktiv (phase ok), aber ich ändere Dateien von Feature B
**Lösung:** Hook muss prüfen, ob Datei zum aktiven Workflow gehört

### 3. Kein-Workflow Bypass
**Problem:** Wenn kein Workflow aktiv → Hook erlaubt alles
**Exploit:** Nie `/11-feature` aufrufen, direkt implementieren
**Lösung:** Hook MUSS blocken wenn kein Workflow existiert UND Code geändert wird

---

## Lösungsvorschläge

### 🔴 PRIORITY 1: Strikte Code-File Protection

**Neuer Hook:** `strict_code_gate.py`

```python
"""
Block ALL code file changes unless:
1. Active workflow exists
2. File belongs to active workflow (in affected_files)
3. Workflow is in phase6_implement or later
4. RED test is done (red_test_done=true)

NO EXCEPTIONS for "unprotected" files!
"""

CODE_EXTENSIONS = [".swift", ".kt", ".java", ".py", ".js", ".ts", ".go", ".rs"]
ALWAYS_ALLOWED_DIRS = ["Tests/", "UITests/", "docs/", ".claude/"]

def main():
    file_path = get_file_path_from_input()

    # Skip non-code files
    if not any(file_path.endswith(ext) for ext in CODE_EXTENSIONS):
        sys.exit(0)

    # Skip test files
    if any(dir in file_path for dir in ALWAYS_ALLOWED_DIRS):
        sys.exit(0)

    # CODE FILE → MUST have active workflow!
    workflow = get_active_workflow()
    if not workflow:
        print("❌ BLOCKED: No active workflow! Start with /11-feature", file=sys.stderr)
        sys.exit(2)

    # Check if file belongs to workflow
    affected = workflow.get("affected_files", [])
    if file_path not in affected and len(affected) > 0:
        print(f"❌ BLOCKED: File not in workflow 'affected_files'!", file=sys.stderr)
        sys.exit(2)

    # Check phase
    phase = workflow["current_phase"]
    if phase not in ["phase6_implement", "phase7_validate", "phase8_complete"]:
        print(f"❌ BLOCKED: Current phase is {phase}, need phase6_implement!", file=sys.stderr)
        sys.exit(2)

    # Check RED test
    if not workflow.get("red_test_done"):
        print("❌ BLOCKED: RED test not done! Run /tdd-red first", file=sys.stderr)
        sys.exit(2)

    sys.exit(0)  # All checks passed
```

**Vorteile:**
- ✅ Kein Bypass über ungeschützte Dateien
- ✅ Erzwingt Workflow-Initialisierung
- ✅ Validiert Datei-Zugehörigkeit zu Workflow
- ✅ Erzwingt TDD RED phase

---

### 🟡 PRIORITY 2: Workflow Auto-Detection

**Neuer Hook:** `workflow_auto_detector.py`

```python
"""
Detect when Claude starts implementing a feature WITHOUT workflow.

Triggers:
- Edit/Write on code files
- No active workflow OR active workflow doesn't include file
- Automatically suggest: "Start workflow with /11-feature first!"
"""

def detect_feature_intent(file_path: str, content: str) -> bool:
    """Heuristic: Is this a new feature implementation?"""
    # Large file changes (>50 LoC)
    # New struct/class definitions
    # TODO patterns in comments
    pass

def main():
    file_path, content = get_input()

    workflow = get_active_workflow()

    # Detect if Claude is implementing without workflow
    if detect_feature_intent(file_path, content):
        if not workflow or file_path not in workflow["affected_files"]:
            print("""
❌ DETECTED: Feature implementation without workflow!

You're making significant code changes but no workflow is active.

REQUIRED STEPS:
1. /11-feature  → Start feature planning
2. Feature agent will:
   - Analyze requirements
   - Create workflow
   - Define test strategy
3. /tdd-red → Write failing tests
4. THEN implement

SHORTCUT NOT ALLOWED!
            """, file=sys.stderr)
            sys.exit(2)

    sys.exit(0)
```

---

### 🟢 PRIORITY 3: Affected Files Tracking

**Enhancement zu `workflow_state_multi.py`:**

```python
def add_affected_file(workflow_name: str, file_path: str) -> bool:
    """
    Register a file as part of this workflow.

    Should be called during analysis/spec phase to declare
    which files will be modified.
    """
    state = load_state()

    if workflow_name not in state["workflows"]:
        return False

    affected = state["workflows"][workflow_name].setdefault("affected_files", [])
    if file_path not in affected:
        affected.append(file_path)
        save_state(state)

    return True

def verify_file_in_workflow(workflow_name: str, file_path: str) -> bool:
    """
    Check if file is registered in workflow's affected_files.

    Returns True if:
    - File is in affected_files, OR
    - affected_files is empty (workflow hasn't declared files yet)
    """
    state = load_state()
    workflow = state["workflows"].get(workflow_name)

    if not workflow:
        return False

    affected = workflow.get("affected_files", [])

    # If no files declared yet, allow (workflow in early phases)
    if len(affected) == 0:
        return True

    # Otherwise file MUST be in list
    return file_path in affected
```

**Integration:**
- `/analyse` Phase: Agent identifiziert betroffene Dateien
- `/write-spec` Phase: Spec listet affected_files
- Hook prüft: Ist Datei in workflow["affected_files"]?

---

### 🔵 PRIORITY 4: Pre-Commit Workflow Validation

**Enhancement zu `pre_commit_gate.py`:**

```python
def validate_commit_has_tests():
    """
    Before commit: Ensure all code changes have corresponding tests.

    Checks:
    - For every .swift file changed → Test file exists?
    - Test file modified in same commit?
    - Red/Green status recorded in workflow?
    """
    changed_files = get_git_staged_files()

    code_files = [f for f in changed_files if f.endswith(('.swift', '.py', '.js'))]
    test_files = [f for f in changed_files if 'Test' in f or 'test' in f]

    code_without_tests = []

    for code_file in code_files:
        # Find corresponding test file
        test_file = find_test_file_for(code_file)

        if not test_file:
            code_without_tests.append(code_file)
        elif test_file not in test_files:
            # Test exists but wasn't modified
            code_without_tests.append(f"{code_file} (test not updated)")

    if code_without_tests:
        print(f"""
❌ COMMIT BLOCKED: Code changes without tests!

Files missing tests:
{chr(10).join(f"  - {f}" for f in code_without_tests)}

TDD requires:
1. Write/update tests FIRST (RED)
2. Implement code (GREEN)
3. Commit BOTH together

Action: Write tests for these files, then commit again.
        """, file=sys.stderr)
        sys.exit(1)
```

---

## Empfohlene Implementierungs-Reihenfolge

1. **SOFORT:** `strict_code_gate.py` implementieren (schließt kritischste Lücke)
2. **DIESE WOCHE:** `affected_files` Tracking in Workflow-State
3. **NÄCHSTE WOCHE:** `workflow_auto_detector.py` für bessere UX
4. **OPTIONAL:** Pre-Commit Test-Validation (zusätzliche Sicherheit)

---

## Testing der neuen Hooks

### Test 1: Direct Code Edit ohne Workflow
```bash
# Setup
rm .claude/workflow_state.json  # Kein aktiver Workflow

# Attempt
echo "// test" >> TimeBox/Sources/Views/BacklogView.swift

# Expected
❌ BLOCKED: No active workflow! Start with /11-feature
```

### Test 2: Edit File außerhalb Workflow
```bash
# Setup
/11-feature "Feature A"  # Startet workflow "feature-a"
# affected_files = ["FileA.swift"]

# Attempt
echo "// test" >> FileB.swift  # Andere Datei!

# Expected
❌ BLOCKED: File not in workflow 'affected_files'!
```

### Test 3: Implement ohne RED Test
```bash
# Setup
/11-feature "Feature B"
# Phase = phase4_approved, red_test_done = false

# Attempt
echo "func foo() {}" >> FileC.swift

# Expected
❌ BLOCKED: RED test not done! Run /tdd-red first
```

---

## Lessons Learned

### Für Claude:
1. **IMMER** `/11-feature` aufrufen bei neuer Feature-Arbeit
2. **NIE** davon ausgehen, dass "weiter" = "direkt implementieren"
3. **IMMER** Workflow-Status prüfen vor Code-Änderungen
4. **NIEMALS** Tests NACH Implementierung anbieten

### Für Henning:
1. Hooks müssen **WHITELIST** statt Blacklist nutzen (alle Dateien geschützt außer explizit erlaubt)
2. Workflow-Initialisierung muss **MANDATORY** sein, nicht optional
3. File-Zugehörigkeit zu Workflow muss geprüft werden
4. TDD-Enforcement muss **unabhängig** von Workflow-Phase greifen

---

## Status: Retroaktive Maßnahmen

### Eisenhower Matrix (bereits implementiert)
- ❌ Keine Tests geschrieben
- ✅ Code funktioniert
- 🔶 **TODO:** Tests retroaktiv schreiben (RED-GREEN umgekehrt)

### Vorgehen:
1. Tests für EisenhowerMatrixView schreiben
2. Tests müssen GRÜN sein (Code existiert schon)
3. Edge Cases prüfen
4. Dokumentation der Test-Coverage

**Deadline:** Vor nächstem Feature!

---

## Fazit

Die Hook-Architektur hat Lücken, die systematische Umgehung ermöglichen. Die Lösung erfordert:

1. **Strikte Code-File Protection** (WHITELIST-Ansatz)
2. **Mandatory Workflow Initialization**
3. **File-to-Workflow Validation**
4. **TDD-Enforcement unabhängig von Config**

Mit den vorgeschlagenen Hooks (`strict_code_gate.py`, `workflow_auto_detector.py`, `affected_files` tracking) können zukünftige Bypasses verhindert werden.

**Nächster Schritt:** Henning entscheidet, welche Hooks implementiert werden sollen.
