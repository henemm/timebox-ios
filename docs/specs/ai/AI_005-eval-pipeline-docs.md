---
entity_id: AI_005-eval-pipeline-docs
type: feature
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [ai, eval, tooling, documentation]
---

# AI_005 — Python Eval-Pipeline dokumentieren & erweitern

## Approval

- [ ] Approved

## Purpose

Erweitert das Python-Eval-Script um CLI-Flags (`--json`, `--compare`), speichert Baseline-Scores, und dokumentiert Setup + Nutzung. Ermöglicht schnelles Prompt-Tuning mit maschinenlesbarem Output und A/B-Vergleich.

## Source

- **File:** `scripts/eval_prompts.py`
- **Identifier:** `main()`, `eval_categorization()`, `eval_enrichment()`, `eval_duration()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| apple-fm-sdk | python-package | Apple Foundation Models Python SDK |
| .venv-fm/ | venv | Python Virtual Environment |

## Implementation Details

### 1. CLI-Flags mit argparse

```python
parser = argparse.ArgumentParser()
parser.add_argument("--json", action="store_true", help="Output als JSON")
parser.add_argument("--compare", metavar="MODULE", help="A/B-Vergleich: aktuell vs. MODULE")
parser.add_argument("--only", choices=["cat", "dur", "enrich"], help="Nur eine Eval ausführen")
```

### 2. `--json` Output

Gibt die Ergebnisse als JSON-Objekt auf stdout aus (statt formatierter Text):

```json
{
  "timestamp": "2026-03-31T15:00:00",
  "categorization": {"correct": 29, "total": 30, "pct": 97, "errors": 0},
  "duration": {"correct": 11, "total": 16, "pct": 69, "errors": 0},
  "enrichment": {"correct": 24, "total": 24, "pct": 100, "errors": 0},
  "elapsed_seconds": 25.5
}
```

### 3. `--compare` A/B-Modus

Lädt alternative INSTRUCTIONS aus einem Python-Modul und vergleicht:

```bash
# Erstelle alternatives Prompt-File
cat > scripts/prompt_v2.py << 'EOF'
CATEGORIZATION_INSTRUCTIONS = "..."
ENRICHMENT_INSTRUCTIONS = "..."
EOF

# Vergleiche
python3 scripts/eval_prompts.py --compare prompt_v2
```

Output: Tabelle mit Score A vs. Score B pro Kategorie.

### 4. Baseline-Scores speichern

```bash
python3 scripts/eval_prompts.py --json > docs/artifacts/ai-eval/baseline-2026-03-31.json
```

Initiale Baseline mit aktuellen Scores (nach AI_002 + AI_003).

### 5. scripts/README.md

Setup-Anleitung, Nutzungsbeispiele, Erklärung der Test-Cases.

### Betroffene Dateien

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `scripts/eval_prompts.py` | MODIFY | argparse, --json, --compare, --only |
| `scripts/README.md` | CREATE | Dokumentation |
| `docs/artifacts/ai-eval/baseline-2026-03-31.json` | CREATE | Initiale Baseline |

**Scope:** 3 Dateien, ~80 LoC (Python) | **Risk:** LOW

## Expected Behavior

- **`python3 scripts/eval_prompts.py`** — wie bisher, formatierte Konsolenausgabe
- **`python3 scripts/eval_prompts.py --json`** — JSON auf stdout
- **`python3 scripts/eval_prompts.py --compare prompt_v2`** — A/B-Vergleich
- **`python3 scripts/eval_prompts.py --only cat`** — nur Kategorisierung

## Acceptance Criteria

- README-Abschnitt in scripts/ erklärt Setup und Nutzung
- `--json` Flag gibt Ergebnisse als JSON aus
- `--compare` Flag testet zwei Prompt-Varianten nebeneinander
- Baseline-Scores in docs/artifacts/ai-eval/ gespeichert

## Known Limitations

- `--compare` lädt Module dynamisch — Pfad muss relativ zu scripts/ sein
- Scores sind nicht-deterministisch (On-Device-Modell schwankt ±3%)
- Python SDK hat kein tokenCount — Token-Analyse bleibt best-effort

## Changelog

- 2026-03-31: Initial spec created (workflow AI_005, GitHub Issue #154)
