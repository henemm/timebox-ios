---
entity_id: execution-log-310
type: module
created: 2026-05-10
updated: 2026-05-10
status: draft
version: "1.0"
tags: [infra, workflow, audit]
---

# Execution Log + /06-validate (Feature #310)

## Approval

- [ ] Approved

## Purpose

Erweitert `workflow.py` um einen automatischen Audit Trail (Phase-Transitions, Fix-Loop-Zähler) und schreibt beim Workflow-Abschluss selbständig ein maschinenlesbares Execution Log nach `.claude/workflows/_logs/`. Dadurch ist retrospektiv nachvollziehbar, wie viele Adversary-Runden ein Workflow benötigte und wie viel Code geändert wurde — ohne manuellen Zusatzschritt.

## Source

- **File:** `.claude/hooks/workflow.py`
- **Identifier:** `_new_workflow()`, `cmd_phase()`, `cmd_status()`, `cmd_complete()`

Neue Hilfsdatei (kein Gate, kein Code):
- **File:** `.claude/commands/06-validate.md`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `_new_workflow()` | function | Workflow-State initialisieren — erhält 3 neue Felder |
| `cmd_phase()` | function | Phase-Wechsel — schreibt Transition-Eintrag + aktualisiert Fix-Loop-Count |
| `cmd_status()` | function | Statusausgabe — zeigt `fix_loop_count` an |
| `cmd_complete()` | function | Abschluss — schreibt Execution Log automatisch vor Archivierung |
| `_atomic_write()` | function | Atomares Schreiben — wird für Log-Datei wiederverwendet |
| `git diff HEAD --numstat` | subprocess | LoC-Delta berechnen — Pattern aus `_validate_transition()` |
| `.claude/workflows/_logs/` | directory | Zielverzeichnis für Execution Logs — wird bei Bedarf angelegt |

## Implementation Details

### A) Drei neue Felder in `_new_workflow()` (ca. Zeile 253)

```python
"phase_transitions": [],       # Audit Trail: [{from, to, at}]
"fix_loop_count": 0,           # Anzahl BROKEN → phase5_implement-Iterationen
"execution_log_written": False, # Guard gegen Doppelschreiben
```

### B) Phase Transition Audit Trail in `cmd_phase()` (nach Zeile 497)

Nach dem Setzen von `data["current_phase"] = target` wird angehängt:

```python
old_phase = data.get("current_phase")  # vor dem Überschreiben lesen
# ...
data.setdefault("phase_transitions", []).append({
    "from": old_phase,
    "to": target,
    "at": datetime.now().isoformat(),
})
```

Fix-Loop-Counter-Logik (ebenfalls in `cmd_phase()`): wenn `target == "phase5_implement"` UND das letzte `adversary_verdict` im State `"BROKEN"` ist → `fix_loop_count += 1`.

```python
if target == "phase5_implement" and data.get("adversary_verdict") == "BROKEN":
    data["fix_loop_count"] = data.get("fix_loop_count", 0) + 1
```

### C) Log-Schreiben in `cmd_complete()`

`cmd_complete()` ruft intern eine neue Hilfsfunktion `_write_execution_log(data)` auf, bevor die Archivierung stattfindet. Kein separater `write-log`-Command nötig.

Log-Format (JSON):

```json
{
  "workflow": "<name>",
  "workflow_type": "<bug|feature>",
  "outcome": "success",
  "phases_completed": ["phase1_context", "phase2_analyse", "phase3_spec",
                       "phase4_tdd_red", "phase5_implement", "phase6_adversary"],
  "tdd_red_confirmed": true,
  "adversary_verdict": "VERIFIED",
  "adversary_run_count": 2,
  "fix_loop_count": 1,
  "scope_loc_delta": 90,
  "completed_at": "<iso-timestamp>"
}
```

`phases_completed` wird aus `phase_transitions` abgeleitet (unique `to`-Werte in Reihenfolge).

`scope_loc_delta` via `git diff HEAD --numstat` (Addition + Deletion aller geänderten Zeilen).

Speicherort: `.claude/workflows/_logs/<workflow-name>-<YYYYMMDD-HHMMSS>.json`

Das Verzeichnis wird mit `mkdir(parents=True, exist_ok=True)` angelegt wenn es nicht existiert.

### D) `cmd_status()` — Fix-Loop-Count anzeigen

Neue Zeile nach dem Adversary-Block:

```
Fix-Loop-Count: 1
```

### E) `.claude/commands/06-validate.md`

Markdown-Leitfaden (kein Code, kein Gate) — erklärt was `workflow.py complete` automatisch tut und wo das Log zu finden ist.

## Expected Behavior

- **Input:** `workflow.py phase <target>` — beliebiger Phase-Wechsel
- **Output:** `phase_transitions[]` enthält neuen Eintrag `{from, to, at}`; bei BROKEN→phase5 wird `fix_loop_count` inkrementiert
- **Input:** `workflow.py complete`
- **Output:** Execution Log JSON in `.claude/workflows/_logs/`, danach Archivierung wie bisher
- **Side effects:** `_logs/`-Verzeichnis wird angelegt falls nicht vorhanden; `execution_log_written` wird auf `True` gesetzt (Guard)

## Acceptance Criteria

**AC-1** — Phase Transition Audit Trail wird befüllt: Nach jedem `cmd_phase()`-Aufruf enthält `phase_transitions[]` einen Eintrag `{from, to, at}` mit korrektem ISO-Timestamp.

**AC-2** — Fix-Loop-Count bei BROKEN → phase5 erhöht: Wenn `adversary_verdict == "BROKEN"` und danach `phase phase5_implement` aufgerufen wird, steigt `fix_loop_count` von 0 auf 1 (und bei erneutem Durchlauf auf 2).

**AC-3** — Fix-Loop-Count bei VERIFIED → phase5 NICHT erhöht: Wenn `adversary_verdict == "VERIFIED"` und danach `phase phase5_implement` aufgerufen wird (z.B. im Rerun-Szenario), bleibt `fix_loop_count` unverändert.

**AC-4** — Execution Log wird automatisch bei `complete` geschrieben: `workflow.py complete` schreibt ohne weiteren manuellen Schritt eine `.json`-Datei nach `.claude/workflows/_logs/<name>-<timestamp>.json`.

**AC-5** — Log-Inhalt ist vollständig: Die geschriebene JSON-Datei enthält alle Pflichtfelder: `workflow`, `workflow_type`, `outcome`, `phases_completed`, `tdd_red_confirmed`, `adversary_verdict`, `adversary_run_count`, `fix_loop_count`, `scope_loc_delta`, `completed_at`.

**AC-6** — `workflow.py status` zeigt `fix_loop_count` an: Die Statusausgabe enthält eine Zeile `Fix-Loop-Count: <n>`.

**AC-7** — `_logs/`-Verzeichnis wird bei Bedarf angelegt: Existiert `.claude/workflows/_logs/` noch nicht, legt `cmd_complete()` es automatisch an (kein Fehler, kein manueller `mkdir` nötig).

## Known Limitations

- `scope_loc_delta` basiert auf `git diff HEAD --numstat` zum Zeitpunkt von `complete` — bei Multi-Commit-Workflows kann dies mehr als den Feature-Scope erfassen wenn zwischendurch unrelated commits entstanden sind.
- `phases_completed` wird aus `phase_transitions` abgeleitet; bei Workflows die vor diesem Feature gestartet wurden ist `phase_transitions` leer und das Feld enthält eine leere Liste.

## Changelog

- 2026-05-10: Initial spec created
