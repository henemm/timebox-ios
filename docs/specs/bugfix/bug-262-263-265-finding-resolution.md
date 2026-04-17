---
entity_id: bug-262-263-265
type: bugfix
created: 2026-04-17
updated: 2026-04-17
status: draft
version: "1.0"
tags: [hooks, phase-listener, adversary]
---

# Bug #262 + #263 + #265 — Finding-Resolution + Adversary Worktree

## Approval

- [ ] Approved

## Fixes

### #262 — AskUserQuestion-Antworten nicht erkannt

Debug-Logging in `_get_user_message()` hinzufügen, damit wir in der nächsten Session sehen welches Format AskUserQuestion-Antworten haben. Zusätzlich breitere Feld-Extraktion.

```python
def _get_user_message(hook_input: dict) -> str:
    msg = hook_input.get("prompt", hook_input.get("content", hook_input.get("message", "")))
    if not msg:
        # Fallback: Durchsuche alle String-Werte im Input
        for key, val in hook_input.items():
            if isinstance(val, str) and len(val) > 1 and key not in ("session_id", "cwd", "transcript_path", "permission_mode", "hook_event_name"):
                msg = val
                break
    return msg
```

### #263 — Kombinierte Finding-Antworten

Statt if/elif: Alle 3 Keyword-Gruppen prüfen. Pro Match ein Finding auflösen.

```python
# Finding resolution: alle Keywords prüfen, mehrere Findings pro Nachricht
if phase == "phase5_implement":
    findings = wf_data.get("adversary_findings", [])
    has_unresolved = any(f.get("status") is None for f in findings)
    if has_unresolved:
        for phrases, status in [
            (FINDING_FIX_PHRASES, "fix"),
            (FINDING_ACCEPT_PHRASES, "accept"),
            (FINDING_DEFER_PHRASES, "defer"),
        ]:
            if _matches(message, phrases):
                _resolve_next_finding(wf_data, wf_path, status, session_id=session_id)
                # Re-read wf_data for next iteration
                wf_data, wf_path = _read_active_workflow(session_id)
                if not wf_data:
                    break
```

### #265 — Adversary Worktree sieht Changes nicht

`isolation: "worktree"` entfernen aus `10-bug.md` und `11-feature.md`. Adversary läuft im gleichen Arbeitsverzeichnis und sieht uncommitted Changes.

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `.claude/hooks/phase_listener.py` | #262: Breitere Feld-Extraktion, #263: Mehrfach-Resolution |
| `.claude/commands/10-bug.md` | #265: isolation: "worktree" entfernen |
| `.claude/commands/11-feature.md` | #265: isolation: "worktree" entfernen |

## Test Plan

1. **test_get_user_message_fallback**: Unknown field name → still extracts message
2. **test_multiple_findings_resolved**: "fixen zurückstellen" → 2 Findings resolved
3. **test_single_finding_still_works**: "fixen" allein → 1 Finding resolved
4. **test_adversary_no_worktree**: 10-bug.md und 11-feature.md enthalten kein "worktree"
