---
entity_id: workflow-enforcement-308a
type: module
created: 2026-05-10
updated: 2026-05-10
status: draft
version: "1.0"
tags: [infra, workflow, enforcement, hooks]
---

# Workflow Enforcement #308-A

## Approval

- [ ] Approved

## Purpose

Drei Enforcement-Verbesserungen für die Workflow-Hook-Infrastruktur: ein kumulativer LoC-Delta-Check vor Phase 5, ein Pflicht-AC-Format-Check in Specs, und ein hartes Adversary-Verdict-Gate im Commit-Guard. Gemeinsames Ziel: Scope-Creep und ungeprüfte Commits werden zur Ausnahme, nicht zur Regel.

## Source

- **File:** `.claude/hooks/workflow.py`
- **Identifier:** `_validate_transition()` (Zeile 298), `cmd_override_ambiguous()` (neu)
- **File:** `.claude/hooks/bash_gate.py`
- **Identifier:** Commit-Gate (Zeile 313–375)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `workflow.py` | module | Enthält `_validate_transition()` — hier werden LoC-Check und AC-Check eingebaut |
| `bash_gate.py` | module | Commit-Gate — hier wird `adversary_verdict` als hartes Gate hinzugefügt |
| `workflow_state.json` / `<name>.json` | data | Enthält `adversary_verdict`, `workflow_type`, `spec_file`, `name` |
| `git diff HEAD --numstat` | cli | Liefert Additions + Deletions für den LoC-Delta-Check |

## Implementation Details

### A) Kumulativer LoC-Delta-Check

In `_validate_transition()`, im Block `if tgt_idx >= PHASES.index("phase5_implement")`, **nach** den bestehenden RED-artifact-Checks, folgender Check ergänzen:

```python
# --- Gate: Scope-Limit (kumulativer LoC-Delta) ---
loc_threshold = 150 if data.get("workflow_type") == "bug" else 250
try:
    result = subprocess.run(
        ["git", "diff", "HEAD", "--numstat"],
        capture_output=True, text=True, cwd=_project_root()
    )
    total_loc = 0
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            added = int(parts[0]) if parts[0].isdigit() else 0
            deleted = int(parts[1]) if parts[1].isdigit() else 0
            total_loc += added + deleted
    if total_loc > loc_threshold:
        return (
            f"BLOCKED: {total_loc} LoC geändert — Limit ist {loc_threshold} "
            f"({'bug' if data.get('workflow_type') == 'bug' else 'feature'}-Workflow). "
            f"Ticket aufteilen oder 'override-loc' ausführen."
        )
except Exception:
    pass  # Wenn git nicht verfügbar: Check überspringen
```

Zusätzlich neuer Command `override-loc`:
```python
def cmd_override_loc(args: list[str]) -> None:
    """Expliziter Override für das LoC-Limit (Henning muss den Command kennen)."""
    data, _ = _read_active()
    data["loc_limit_override"] = True
    _save_active(data)
    print("LoC-Limit Override gesetzt. Gültig für diese Phase-Transition.")
```

Der Check in `_validate_transition()` prüft zusätzlich: `if data.get("loc_limit_override"): return None`.

### B) AC-Format-Check

Im gleichen `phase5_implement`-Block, nach dem LoC-Check:

```python
# --- Gate: Spec muss Acceptance Criteria enthalten ---
spec_path = data.get("spec_file")
if spec_path:
    try:
        spec_content = Path(spec_path).read_text()
        has_ac_section = "## Acceptance Criteria" in spec_content
        has_ac_item = bool(
            re.search(r'\*\*AC-\d+\*\*|- AC-\d+:', spec_content)
        )
        if not has_ac_section or not has_ac_item:
            return (
                "BLOCKED: Spec enthält keinen gültigen ## Acceptance Criteria-Abschnitt "
                "mit mindestens einem 'AC-1' Item. Spec aktualisieren und neu genehmigen lassen."
            )
    except OSError:
        pass  # Wenn Spec nicht lesbar: Check überspringen
```

`import re` muss am Datei-Anfang ergänzt werden falls noch nicht vorhanden.

### C) Adversary-Verdict im Commit-Gate

In `bash_gate.py`, im Block `if active_wf:` (nach Zeile 352), nach dem bestehenden `checkpoint3_approved`-Check:

```python
# 6e. Adversary-Verdict Gate
verdict = active_wf.get("adversary_verdict")
ambiguous_override = active_wf.get("adversary_override_ambiguous", False)

if verdict is None:
    print(
        "BLOCKED: Kein Adversary-Lauf für diesen Workflow. "
        "Phase 6 (Adversary) muss vor dem Commit abgeschlossen sein.",
        file=sys.stderr
    )
    sys.exit(2)
elif verdict == "BROKEN":
    print(
        "BLOCKED: Adversary-Verdict ist BROKEN. "
        "Implementation muss korrigiert werden bevor ein Commit möglich ist.",
        file=sys.stderr
    )
    sys.exit(2)
elif verdict == "AMBIGUOUS" and not ambiguous_override:
    print(
        "BLOCKED: Adversary-Verdict ist AMBIGUOUS. "
        "Entweder Befunde klären oder 'override-ambiguous' ausführen "
        "(workflow.py override-ambiguous).",
        file=sys.stderr
    )
    sys.exit(2)
# VERIFIED oder AMBIGUOUS mit Override: Commit erlaubt
```

Neuer Command `override-ambiguous` in `workflow.py`:
```python
def cmd_override_ambiguous(args: list[str]) -> None:
    """Setzt adversary_override_ambiguous=True — erlaubt Commit trotz AMBIGUOUS-Verdict."""
    data, _ = _read_active()
    data["adversary_override_ambiguous"] = True
    _save_active(data)
    print("Adversary AMBIGUOUS Override gesetzt. Commit jetzt erlaubt.")
```

Beide Override-Felder werden in `_new_workflow()` initialisiert:
```python
"loc_limit_override": False,
"adversary_override_ambiguous": False,
```

## Expected Behavior

- **Input (LoC-Check):** Übergang nach `phase5_implement` mit mehr als 250 (Feature) bzw. 150 (Bug) geänderten LoC
- **Output (LoC-Check):** `BLOCKED: N LoC geändert — Limit ist X ...`
- **Input (AC-Check):** Übergang nach `phase5_implement` mit Spec ohne `## Acceptance Criteria` oder ohne `AC-1`-Zeile
- **Output (AC-Check):** `BLOCKED: Spec enthält keinen gültigen ## Acceptance Criteria-Abschnitt ...`
- **Input (Adversary-Gate):** `git commit` mit `fix:/feat:` ohne abgeschlossenen Adversary-Lauf
- **Output (Adversary-Gate):** `BLOCKED: Kein Adversary-Lauf ...` / `BLOCKED: Adversary-Verdict ist BROKEN ...` / `BLOCKED: Adversary-Verdict ist AMBIGUOUS ...`
- **Side effects:** Zwei neue Felder im Workflow-State (`loc_limit_override`, `adversary_override_ambiguous`); `import subprocess` und `import re` müssen in `workflow.py` verfügbar sein

## Acceptance Criteria

**AC-1** — LoC-Limit Feature-Workflow
Given ein aktiver Feature-Workflow (`workflow_type == "feature"`) mit 251+ geänderten LoC (gemessen via `git diff HEAD --numstat`),
When die Transition nach `phase5_implement` ausgelöst wird,
Then wird die Transition mit einer Meldung blockiert, die die genaue LoC-Zahl und den Threshold nennt.

**AC-2** — LoC-Limit Bug-Workflow (niedrigerer Threshold)
Given ein aktiver Bug-Workflow (`workflow_type == "bug"`) mit 151+ geänderten LoC,
When die Transition nach `phase5_implement` ausgelöst wird,
Then wird die Transition blockiert (Threshold 150, nicht 250).

**AC-3** — LoC-Limit Override
Given ein aktiver Workflow mit zu vielen LoC UND `loc_limit_override == True` (gesetzt via `workflow.py override-loc`),
When die Transition nach `phase5_implement` ausgelöst wird,
Then wird die Transition NICHT durch den LoC-Check blockiert.

**AC-4** — AC-Format-Check: Spec ohne Acceptance Criteria
Given eine genehmigte Spec ohne `## Acceptance Criteria`-Abschnitt oder ohne mindestens eine `AC-1`-Zeile,
When die Transition nach `phase5_implement` ausgelöst wird,
Then wird die Transition mit einer Meldung blockiert, die auf den fehlenden AC-Abschnitt hinweist.

**AC-5** — AC-Format-Check: Gültige Spec passiert
Given eine genehmigte Spec mit `## Acceptance Criteria` und mindestens einer Zeile im Format `**AC-1**` oder `- AC-1:`,
When die Transition nach `phase5_implement` ausgelöst wird (alle anderen Gates bestanden),
Then wird der AC-Check NICHT zur Blockade.

**AC-6** — Adversary-Verdict fehlt: Commit blockiert
Given ein aktiver Workflow mit `adversary_verdict == None` (kein Adversary-Lauf abgeschlossen),
When `git commit` mit `fix:` oder `feat:` in der Commit-Nachricht ausgeführt wird,
Then blockiert `bash_gate.py` den Commit mit einem Hinweis auf fehlenden Adversary-Lauf.

**AC-7** — Adversary-Verdict BROKEN: Commit blockiert
Given ein aktiver Workflow mit `adversary_verdict == "BROKEN"`,
When `git commit` mit `fix:` oder `feat:` ausgeführt wird,
Then blockiert `bash_gate.py` den Commit mit einer klaren BROKEN-Meldung.

**AC-8** — Adversary-Verdict AMBIGUOUS: Commit blockiert, Override möglich
Given ein aktiver Workflow mit `adversary_verdict == "AMBIGUOUS"` und `adversary_override_ambiguous == False`,
When `git commit` mit `fix:` oder `feat:` ausgeführt wird,
Then blockiert `bash_gate.py` den Commit und nennt `override-ambiguous` als Ausweg.

**AC-9** — Adversary-Verdict AMBIGUOUS mit Override: Commit erlaubt
Given ein aktiver Workflow mit `adversary_verdict == "AMBIGUOUS"` und `adversary_override_ambiguous == True` (gesetzt via `workflow.py override-ambiguous`),
When `git commit` mit `fix:` oder `feat:` ausgeführt wird,
Then wird der Commit vom Adversary-Gate NICHT blockiert.

**AC-10** — Adversary-Verdict VERIFIED: Commit erlaubt
Given ein aktiver Workflow mit `adversary_verdict == "VERIFIED"` und allen anderen Gates bestanden,
When `git commit` mit `fix:` oder `feat:` ausgeführt wird,
Then wird der Commit vom Adversary-Gate NICHT blockiert.

## Known Limitations

- Der LoC-Check basiert auf `git diff HEAD --numstat`. Wenn vor `phase5_implement` bereits Commits gemacht wurden, misst der Check nur noch den Diff zum letzten Commit, nicht zum Workflow-Start. Das ist eine bewusste Vereinfachung — in normalen Workflows gibt es vor Phase 5 keine Code-Commits.
- `override-loc` setzt kein Ablaufdatum. Der Override ist für die gesamte Laufzeit des Workflows aktiv. Bei missbräuchlicher Nutzung gibt es kein weiteres Gate.
- Bei nicht lesbarer Spec-Datei (z.B. falscher Pfad im `spec_file`-Feld) wird der AC-Check übersprungen statt zu blockieren — der Fehler fällt also nicht laut auf.

## Changelog

- 2026-05-10: Initial spec created
