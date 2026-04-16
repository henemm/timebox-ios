---
entity_id: adversary-findings-gate
type: module
created: 2026-04-16
updated: 2026-04-16
status: draft
version: "1.0"
tags: [workflow, adversary, gate, checkpoint]
---

# Adversary-Findings-Gate

## Approval

- [ ] Approved

## Purpose

Strukturelle Erzwingung, dass jedes Adversary-Finding einzeln von Henning beantwortet wird, bevor Checkpoint 3 freigegeben wird. Verhindert, dass Claude Findings runterspielt oder versteckt.

## Kernprinzip

Claude darf Findings **registrieren** (`add-finding`), aber **nicht auflösen** (`resolve-finding`). Nur phase_listener darf Findings auflösen — ausgelöst durch Hennings Antwort.

## Source

- **Files:**
  - `.claude/hooks/workflow.py` — neue Commands + Gate
  - `.claude/hooks/phase_listener.py` — Finding-Resolution
  - `.claude/hooks/bash_gate.py` — Commit-Block bei offenen Findings
  - `.claude/commands/adversary.md` — Strukturierte Findings im Report

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| workflow.py | hook | Workflow-State + Transitions |
| phase_listener.py | hook | User-Input → State-Änderungen |
| bash_gate.py | hook | Git-Commit-Schutz |
| adversary.md | command | Adversary-Prompt-Generierung |

## Datenstruktur

### Neues Feld in workflow_state: `adversary_findings`

```json
{
  "adversary_findings": [
    {
      "id": 1,
      "title": "Akzeptierte Tags bleiben in suggestedTags",
      "impact": "Keine sichtbare Auswirkung — UI-Filter kompensiert. Aber Daten sind unsauber.",
      "proof": "Unit Test: tag in suggestedTags nach Accept → true (sollte false sein)",
      "status": null,
      "resolved_at": null
    },
    {
      "id": 2,
      "title": "Nicht-angetippte Vorschläge gehen verloren",
      "impact": "Beim Erstellen: 2 Vorschläge, 1 angetippt, Save → zweiter weg. Enrichment generiert ggf. andere Tags.",
      "proof": "Test: createTask mit 2 suggestions, accept 1, save → suggestedTags hat nur 1 statt 2",
      "status": "fix",
      "resolved_at": "2026-04-16T14:30:00"
    }
  ]
}
```

**Status-Werte:** `null` (offen) → `"fix"` | `"accept"` | `"defer"`

## Implementation Details

### 1. workflow.py — Neue Commands

**`add-finding <title> <impact> <proof>`**
- Fügt ein Finding zur `adversary_findings`-Liste hinzu
- Auto-incrementing `id` (max vorhandener id + 1)
- `status: null`
- Kein Caller-Schutz nötig (Claude darf Findings registrieren)

**`resolve-finding <id> <status>`**
- Setzt `status` und `resolved_at` auf einem Finding
- **GESCHÜTZT:** Nur `WORKFLOW_CALLER=phase_listener` darf das aufrufen
- Erlaubte Status: `fix`, `accept`, `defer`

**`list-findings`**
- Zeigt alle Findings mit Status (für Debugging/Übersicht)

### 2. workflow.py — Gate in `_validate_transition()`

```python
# --- Gate: Adversary Findings müssen alle resolved sein ---
if tgt_idx >= PHASES.index("phase6_done"):
    findings = data.get("adversary_findings", [])
    unresolved = [f for f in findings if f.get("status") is None]
    if unresolved:
        titles = ", ".join(f["title"] for f in unresolved[:3])
        return (f"BLOCKED: {len(unresolved)} Adversary-Finding(s) noch offen: {titles}. "
                "Jedes Finding muss von Henning beantwortet werden.")
```

Platzierung: NACH dem Checkpoint-3-Gate (Zeile ~336), sodass BEIDE Bedingungen erfüllt sein müssen.

### 3. phase_listener.py — Finding-Resolution

Neue Keywords in phase5_implement:

```python
FINDING_FIX_PHRASES = ["fixen", "fix", "beheben", "reparieren"]
FINDING_ACCEPT_PHRASES = ["akzeptabel", "akzeptieren", "ok so", "passt so", "egal"]
FINDING_DEFER_PHRASES = ["zurückstellen", "später", "defer", "ticket"]
```

Logik: Wenn Henning eins dieser Keywords sagt UND es unresolved Findings gibt → das **erste unresolved Finding** wird aufgelöst.

```python
def _resolve_next_finding(wf_data: dict, wf_path: Path, status: str) -> None:
    findings = wf_data.get("adversary_findings", [])
    for f in findings:
        if f.get("status") is None:
            f["status"] = status
            f["resolved_at"] = datetime.now().isoformat()
            _save_workflow(wf_data, wf_path)
            print(f"Finding #{f['id']} '{f['title']}' → {status}", file=sys.stderr)
            return
```

### 4. bash_gate.py — Commit-Block

Im Abschnitt "6b. Checkpoint 3 Gate" (Zeile ~347):

```python
# 6c. Adversary-Findings Gate
if active_wf:
    findings = active_wf.get("adversary_findings", [])
    unresolved = [f for f in findings if f.get("status") is None]
    if unresolved:
        print(f"BLOCKED: {len(unresolved)} Adversary-Finding(s) noch offen. "
              "Jedes Finding muss von Henning beantwortet werden.",
              file=sys.stderr)
        sys.exit(2)
```

### 5. adversary.md — Strukturierte Findings

Am Ende des Adversary-Report-Formats einen neuen Block hinzufügen:

```markdown
## Strukturierte Findings (für Workflow-Gate)

Gib am Ende deines Reports ZUSÄTZLICH diesen JSON-Block aus:

\```json
{
  "findings": [
    {
      "title": "Kurzer Titel des Problems",
      "impact": "Was passiert wenn es NICHT gefixt wird? (In User-Sprache, nicht technisch)",
      "proof": "Konkreter Beweis: Test-Name, Screenshot-Pfad, oder Code-Stelle"
    }
  ]
}
\```

REGELN für Findings:
- NUR User-sichtbare Probleme (Workflow kaputt, falsches Verhalten, Datenverlust)
- KEINE Code-Style-Issues (Naming, Kommentare, Formatierung)
- KEINE "nice-to-have" Verbesserungen
- Jedes Finding MUSS einen konkreten Beweis haben
- "impact" in Hennings Sprache: "Der User sieht X wenn er Y macht"
```

### 6. Checkpoint 3 — Presentation Flow

Claude MUSS nach Adversary-Run:

1. Für jedes Finding `workflow.py add-finding` aufrufen
2. Jedes Finding einzeln via **AskUserQuestion** vorlegen:
   - Titel + Impact + Beweis
   - Claudes Empfehlung (als "(Empfohlen)" markiert)
   - Optionen: "Fixen" / "Akzeptabel" / "Zurückstellen"
3. Hennings Antwort wird von phase_listener erkannt → `resolve-finding`
4. Erst wenn alle resolved: Checkpoint 3 präsentieren

## Expected Behavior

- **Input:** Adversary-Agent produziert strukturierte Findings
- **Output:** Jedes Finding wird einzeln von Henning beantwortet
- **Side effects:**
  - Findings mit Status "fix" → werden zu GitHub Issues (manuell oder automatisch)
  - Findings mit Status "defer" → bleiben als Dokumentation im Workflow-Archiv

## Known Limitations

- Phase_listener erkennt Keywords sequenziell — wenn Henning mehrere Findings in einer Nachricht beantwortet, wird nur das erste aufgelöst
- Bei 0 Findings (Adversary findet nichts) greift das Gate nicht — Checkpoint 3 funktioniert wie bisher

## Changelog

- 2026-04-16: Initial spec created
