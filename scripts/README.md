# FocusBlox Scripts

## eval_prompts.py — AI Prompt Evaluation

Testet die AI-Prompts (Kategorisierung, Zeitschätzung, Enrichment) direkt gegen das On-Device Apple Intelligence Modell — ohne Xcode/Simulator.

### Setup

```bash
# Python venv aktivieren (einmalig erstellt mit apple-fm-sdk)
source .venv-fm/bin/activate

# Voraussetzung: macOS 26.4+ mit Apple Intelligence aktiviert
```

### Nutzung

```bash
# Standard-Eval (alle 3 Bereiche, formatierte Ausgabe)
python3 scripts/eval_prompts.py

# Nur Kategorisierung testen
python3 scripts/eval_prompts.py --only cat

# Nur Enrichment testen
python3 scripts/eval_prompts.py --only enrich

# JSON-Output (maschinenlesbar, für Tracking)
python3 scripts/eval_prompts.py --json

# Baseline speichern
python3 scripts/eval_prompts.py --json > docs/artifacts/ai-eval/baseline-$(date +%Y-%m-%d).json

# A/B-Vergleich: aktueller Prompt vs. Alternative
python3 scripts/eval_prompts.py --compare prompt_v2
```

### A/B-Vergleich

Erstelle ein alternatives Prompt-Modul in `scripts/`:

```python
# scripts/prompt_v2.py
CATEGORIZATION_INSTRUCTIONS = "Dein alternativer Prompt..."
ENRICHMENT_INSTRUCTIONS = "..."
# Nicht definierte Instructions fallen auf den aktuellen Prompt zurück
```

Dann vergleichen:

```bash
python3 scripts/eval_prompts.py --compare prompt_v2
```

### Test-Cases

- **Kategorisierung:** 30 deutsche Tasks in 5 Kategorien (income, maintenance, recharge, learning, giving_back)
- **Zeitschätzung:** 16 Tasks mit erwarteten Dauer-Ranges
- **Enrichment:** 8 Tasks mit erwarteten Importance/Urgency/Energy-Werten

### Aktuelle Scores (2026-03-31)

| Bereich | Score | Ziel |
|---------|-------|------|
| Kategorisierung | 97% (29/30) | ≥90% |
| Zeitschätzung | 56-69% | ≥85% |
| Enrichment | 100% (24/24) | ≥85% |
