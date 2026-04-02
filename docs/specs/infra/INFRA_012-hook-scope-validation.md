---
entity_id: INFRA_012
type: infrastructure
created: 2026-04-02
updated: 2026-04-02
status: draft
version: "1.0"
tags: [hooks, security, scope-validation]
---

# INFRA_012: Hook-System Scope-Validierung

## Approval

- [ ] Approved

## Purpose

Schließt 2 Scope-Validierungs-Lücken im Hook-System, die es Claude ermöglichten, ein komplettes Feature am Workflow vorbei zu implementieren: (1) `set-affected-files` hat keine Phase-Prüfung, (2) `project.pbxproj` ist nicht vor direkter Manipulation geschützt.

## Source

- **File:** `.claude/hooks/workflow.py`
- **Identifier:** `cmd_set_affected_files()`
- **File:** `.claude/hooks/bash_gate.py`
- **Identifier:** `PROTECTED_FILE_PATTERNS`
- **File:** `scripts/add_file_to_project.py` (NEU)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `edit_gate.py` | Hook | Nutzt `affected_files` zur Workflow-Zuordnung — profitiert vom Phase-Guard |
| `workflow.py` | Hook | Enthält `cmd_set_affected_files()` — wird geändert |
| `bash_gate.py` | Hook | Enthält `PROTECTED_FILE_PATTERNS` — wird geändert |
| Override-Token | System | Bypass für Phase-Guard (existiert bereits in workflow.py:297) |

## Implementation Details

### Fix 1: Phase-Guard für `set-affected-files` (workflow.py:490)

In `cmd_set_affected_files()` nach `data, name = _read_active()` einfügen:

```python
# Phase-Guard: affected_files nur in frühen Phasen änderbar
ALLOWED_PHASES_FOR_SCOPE = {
    "phase0_idle",
    "phase1_context",
    "phase2_analyse",
    "phase3_spec",
    "phase4_approved",  # /10-bug Schritt 7.5 braucht das
}
phase = data.get("current_phase", "phase0_idle")
if phase not in ALLOWED_PHASES_FOR_SCOPE:
    if not _has_override_token(name):
        print(f"BLOCKED: set-affected-files nicht erlaubt in Phase {phase}. "
              f"Scope wird vor TDD RED definiert.", file=sys.stderr)
        sys.exit(1)
```

`_has_override_token()` existiert bereits in workflow.py (Zeile 297-307) — kann direkt verwendet werden.

### Fix 2: pbxproj-Schutz (bash_gate.py:47-53, 61-64)

**2a.** `project.pbxproj` zu `PROTECTED_FILE_PATTERNS` (Zeile 47) hinzufügen:

```python
r"project\.pbxproj",  # NEU — nach Zeile 53
```

**2b.** `add_file_to_project.py` zu `WHITELIST_COMMANDS` (Zeile 61) hinzufügen:

```python
"add_file_to_project.py",  # NEU — nach Zeile 64
```

### Fix 3: Neues Script `scripts/add_file_to_project.py`

```python
#!/usr/bin/env python3
"""Add Swift files to Xcode project targets via python-pbxproj."""
import argparse
import sys
from pbxproj import XcodeProject

def main():
    parser = argparse.ArgumentParser(description="Add files to Xcode project")
    parser.add_argument("files", nargs="+", help="Swift files to add")
    parser.add_argument("--target", default="FocusBlox", help="Target name")
    parser.add_argument("--project", default="FocusBlox.xcodeproj/project.pbxproj")
    args = parser.parse_args()

    proj = XcodeProject.load(args.project)
    for f in args.files:
        proj.add_file(f, target_name=args.target)
        print(f"Added: {f} -> {args.target}")
    proj.save()
    print(f"Saved. Run './scripts/sim.sh build' to verify.")

if __name__ == "__main__":
    main()
```

## Expected Behavior

### Fix 1: Phase-Guard
- **Input:** `python3 workflow.py set-affected-files file.swift` in phase6_implement
- **Output:** `BLOCKED: set-affected-files nicht erlaubt in Phase phase6_implement.`
- **Input:** Gleicher Aufruf in phase2_analyse
- **Output:** `Set affected_files on workflow ...: 1 files` (erlaubt)
- **Input:** Gleicher Aufruf in phase6 MIT Override-Token
- **Output:** Erlaubt (Override-Token bypassed)

### Fix 2: pbxproj-Schutz
- **Input:** `python3 -c "from pbxproj import XcodeProject; ..."`
- **Output:** `BLOCKED: Direct state file manipulation. Use workflow.py CLI.`
- **Input:** `python3 scripts/add_file_to_project.py Sources/NewFile.swift`
- **Output:** Erlaubt (whitegelistet)

## Test Plan

### Automatisierte Validierung (Python-Tests via Bash)

Da die Hooks Python-Skripte außerhalb des Swift-Projekts sind, werden sie über direkte Aufrufe mit kontrolliertem State getestet. Die Tests laufen automatisiert als Shell-Assertions.

**Test 1: Phase-Guard blockiert in phase6**
```bash
# Setup: Workflow auf phase6_implement setzen
python3 .claude/hooks/workflow.py set-affected-files new_file.swift 2>&1
# Assert: Exit-Code 1 + "BLOCKED" in stderr
```

**Test 2: Phase-Guard erlaubt in phase2**
```bash
# Setup: Workflow auf phase2_analyse setzen
python3 .claude/hooks/workflow.py set-affected-files new_file.swift 2>&1
# Assert: Exit-Code 0 + "Set affected_files" in stdout
```

**Test 3: pbxproj via Python-Einzeiler blockiert**
```bash
echo '{"tool_input":{"command":"python3 -c \"from pbxproj import XcodeProject\""}}' | python3 .claude/hooks/bash_gate.py
# Assert: Exit-Code 2 + "BLOCKED" in stderr
```

**Test 4: pbxproj via whitegelistetes Script erlaubt**
```bash
echo '{"tool_input":{"command":"python3 scripts/add_file_to_project.py Sources/New.swift"}}' | python3 .claude/hooks/bash_gate.py
# Assert: Exit-Code 0
```

**Test 5: Override-Token bypassed Phase-Guard**
```bash
# Setup: Override-Token für Workflow setzen, Phase auf phase6
python3 .claude/hooks/workflow.py set-affected-files new_file.swift 2>&1
# Assert: Exit-Code 0 (Override bypassed)
```

## Known Limitations

- Phase-Guard schützt nicht gegen Manipulation in phase2/3 — dort ist Scope-Definition beabsichtigt, User-Review erfolgt über Spec-Approval
- Override-Token bleibt als Bypass für Sonderfälle (z.B. Hotfixes)
- `project.pbxproj`-Schutz gilt nur für Bash-Gate — Edit-Gate ist nicht betroffen (pbxproj ist kein `.swift`-File)

## Scope

| File | Change | LoC |
|------|--------|-----|
| `.claude/hooks/workflow.py` | MODIFY: Phase-Guard in cmd_set_affected_files | +12 |
| `.claude/hooks/bash_gate.py` | MODIFY: pbxproj in PROTECTED + Script in WHITELIST | +2 |
| `scripts/add_file_to_project.py` | CREATE: Whitegelistetes pbxproj-Script | +25 |
| **Gesamt** | | **+39 LoC** |

## Changelog

- 2026-04-02: Initial spec created
