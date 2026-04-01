---
entity_id: BUG_session_isolation
type: bugfix
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [hooks, workflow, session, bugfix, infrastructure]
parent_spec: INFRA_003
---

# BUG: Session-Isolation funktioniert nicht

## Approval

- [ ] Approved

## Purpose

Fix für die nicht funktionierende Session-Isolation aus INFRA_003. Zwei Defekte verhindern, dass parallele Claude-Sessions isolierte Workflows haben: (1) SessionStart-Hook nicht registriert, (2) Hooks lesen session_id aus os.environ statt aus stdin-JSON.

## Source

- **Files:** `.claude/hooks/bash_gate.py`, `.claude/hooks/edit_gate.py`, `.claude/hooks/post_bash.py`, `.claude/settings.json`
- **Analysis:** `docs/artifacts/bug-session-isolation/analysis.md`
- **Parent Spec:** `docs/specs/infra/INFRA_003-session-aware-workflows.md`

## Root Cause

### Defekt 1: SessionStart-Hook nicht registriert
`session_start.py` existiert (korrekt implementiert), aber `.claude/settings.json` hat keinen `SessionStart`-Eintrag. Der Hook wird nie aufgerufen → `CLAUDE_SESSION_ID` wird nie als env-var gesetzt.

### Defekt 2: Hooks ignorieren session_id aus stdin-JSON
Claude Code sendet `session_id` in JEDEM Hook-Input (stdin-JSON). Aber `bash_gate.py`, `edit_gate.py`, `post_bash.py` lesen session_id nur aus `os.environ.get("CLAUDE_SESSION_ID")`. Nur `phase_listener.py` liest korrekt aus dem Hook-Input.

**Kritisch:** Die Hooks lesen stdin bereits für `tool_input` — aber werfen `session_id` dabei weg.

### Defekt 3: .active Symlink wird IMMER überschrieben
`_set_active()` in `workflow.py` schreibt den `.active`-Symlink bei JEDEM Workflow-Start, unabhängig davon ob session_id vorhanden ist. Bei parallelen Sessions überschreiben sie sich gegenseitig.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| INFRA_003 | spec | Parent-Spec (Session-Aware Workflows) |
| bash_gate.py | hook | PreToolUse Gate für Bash-Befehle |
| edit_gate.py | hook | PreToolUse Gate für Edit/Write |
| post_bash.py | hook | PostToolUse für Build-Lock Release |
| settings.json | config | Hook-Registrierung |
| workflow.py | hook | Workflow-Engine (CLI) |

## Implementation Details

### Fix A: session_id beim ersten stdin-Read extrahieren (3 Dateien)

**Pattern (identisch in allen 3 Hooks):**

```python
# Modul-Level Variable
_STDIN_SESSION_ID = ""

# Im bestehenden stdin-Parse (wo tool_input extrahiert wird):
data = json.load(sys.stdin)
tool_input = json.dumps(data.get("tool_input", {}))
_STDIN_SESSION_ID = data.get("session_id", "")  # NEU

# _get_session_id() anpassen:
def _get_session_id() -> str:
    sid = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID
    if sid:
        return f"session:{sid}"
    return f"ppid:{os.getppid()}"
```

**Betroffene Stellen:**

| Datei | stdin-Read Zeile | _get_session_id Zeile |
|-------|-----------------|----------------------|
| bash_gate.py | 115-116 | 175-180 |
| edit_gate.py | 226-227 | Neu (nutzt os.environ in _read_active_workflow Z.116) |
| post_bash.py | 108-109 | 130 (inline os.environ.get) |

### Fix B: SessionStart-Hook registrieren (1 Datei)

In `.claude/settings.json` hinzufügen:

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "python3 .claude/hooks/session_start.py",
        "timeout": 5
      }
    ]
  }
]
```

### Fix C: .active Symlink nur bei fehlender session_id (1 Datei)

In `workflow.py:_set_active()`:

```python
def _set_active(name: str) -> None:
    session_id = _get_session_id()
    if session_id:
        with _locked_sessions() as sessions:
            sessions[session_id] = name

    # .active Symlink nur als Fallback wenn KEINE session_id
    if not session_id:
        link = _active_link()
        target = f"{name}.json"
        if link.is_symlink() or link.exists():
            link.unlink()
        os.symlink(target, str(link))
```

## Expected Behavior

- **Vorher:** Alle Sessions sehen denselben Workflow (aus `.active` Symlink)
- **Nachher:** Jede Session sieht nur ihren eigenen Workflow (aus `.sessions.json` per session_id)
- **Fallback:** Sessions ohne session_id (z.B. manuelle CLI-Aufrufe) nutzen weiterhin `.active`

## Affected Files

| Datei | Änderung | LoC |
|-------|----------|-----|
| `.claude/hooks/bash_gate.py` | session_id aus stdin extrahieren + _get_session_id erweitern | ~8 |
| `.claude/hooks/edit_gate.py` | session_id aus stdin extrahieren + in _read_active_workflow nutzen | ~8 |
| `.claude/hooks/post_bash.py` | session_id aus stdin extrahieren + bei Lock-Release nutzen | ~8 |
| `.claude/settings.json` | SessionStart-Hook registrieren | ~8 |
| `.claude/hooks/workflow.py` | _set_active: .active nur ohne session_id schreiben | ~5 |

**Gesamt: 5 Dateien, ~37 LoC** (innerhalb Scoping-Limits)

## Test Plan

### Automatisierte Tests (Python)

| # | Test | Prüft |
|---|------|-------|
| 1 | bash_gate extrahiert session_id aus stdin-JSON | Fix A funktioniert |
| 2 | edit_gate extrahiert session_id aus stdin-JSON | Fix A funktioniert |
| 3 | post_bash extrahiert session_id aus stdin-JSON | Fix A funktioniert |
| 4 | _get_session_id bevorzugt env-var, fällt auf stdin zurück | Priorität korrekt |
| 5 | _set_active schreibt .active NICHT wenn session_id vorhanden | Fix C funktioniert |
| 6 | _set_active schreibt .active wenn session_id FEHLT | Backward-compat |

### Integrations-Verifikation

1. Neue Session starten → `workflow.py status` zeigt KEINEN fremden Workflow
2. Zwei Sessions parallel → jede sieht nur ihren eigenen Workflow
3. Session A: Workflow starten → Session B: `workflow.py status` zeigt NICHT A's Workflow

## Known Limitations

- `workflow.py` wird via Bash aufgerufen (nicht als Hook) → bekommt session_id nur über env-var, nicht über stdin. Daher ist Fix B (SessionStart-Hook) für workflow.py CLI-Aufrufe notwendig.
- CLAUDE_ENV_FILE ist nur für SessionStart/CwdChanged/FileChanged dokumentiert. Ob die darin gesetzten Variablen in nachfolgenden Bash-Befehlen verfügbar sind, hängt von Claude Code Runtime ab.

## Changelog

- 2026-03-31: Initial spec created from bug analysis
