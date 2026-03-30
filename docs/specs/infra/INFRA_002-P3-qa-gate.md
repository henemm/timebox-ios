---
entity_id: INFRA_002-P3
type: infrastructure
created: 2026-03-30
status: draft
version: "1.0"
tags: [hooks, qa, adversary]
---

# INFRA_002-P3: QA-Gate für Workflow v3

## Approval
- [ ] Approved

## Purpose
Ersetzt das gelöschte `adversary_gate.py` durch ein v3-kompatibles `qa_gate.py`. Fixt gleichzeitig kaputte Referenzen in `implementation-validator.md` und `/05-implement`.

## Affected Files

| Datei | Typ | Beschreibung |
|-------|-----|-------------|
| `.claude/hooks/qa_gate.py` | CREATE | Neues QA-Gate (~100 LoC) |
| `.claude/hooks/bash_gate.py` | MODIFY | Whitelist: adversary_gate → qa_gate |
| `.claude/agents/implementation-validator.md` | MODIFY | workflow_state_multi → workflow.py, adversary_gate → qa_gate |
| `.claude/commands/05-implement.md` | MODIFY | adversary_gate → qa_gate |

## qa_gate.py Logik

```
1. Test-Output-File lesen
2. Validieren:
   a. File existiert + ist < 30 Min alt
   b. Enthält Test Suite / Test Case Patterns
   c. Enthält FocusBloxTests UND FocusBloxUITests (oder --infra Flag)
   d. Keine Failures
3. Verdict in aktives Workflow-File schreiben (via workflow.py)
4. Screenshot validieren (oder --no-visual mit Begründung)
```

Unterschied zum alten adversary_gate.py:
- Liest/schreibt `.claude/workflows/<name>.json` statt `workflow_state.json`
- Nutzt `workflow.py set-field` statt direkten JSON-Write
- `--infra` Flag für reine Infrastruktur-Tickets (kein FocusBloxTests/UITests nötig)
- Kein Import von workflow_state_multi mehr

## Test Plan
Python Unit Tests:
1. qa_gate.py existiert
2. Blockiert bei leerem/altem Test-Output
3. Blockiert bei fehlenden Test-Patterns
4. Setzt Verdict bei gültigem Output
5. --infra Flag akzeptiert Python-Tests
