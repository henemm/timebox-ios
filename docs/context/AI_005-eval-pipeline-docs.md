# Context: AI_005 — Python Eval-Pipeline dokumentieren & erweitern

## Request Summary
Das Python-Eval-Script (`scripts/eval_prompts.py`) braucht Dokumentation, `--json` Output, `--compare` Modus für A/B-Tests, und gespeicherte Baseline-Scores.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/eval_prompts.py` | Hauptscript — wird erweitert (407 LoC) |

## Acceptance Criteria (aus Issue #154)
1. README-Abschnitt in scripts/ erklärt Setup und Nutzung
2. `--json` Flag gibt Ergebnisse als JSON aus
3. `--compare` Flag testet zwei Prompt-Varianten nebeneinander
4. Baseline-Scores in docs/artifacts/ gespeichert

## Existing Patterns
- Script hat bereits argparse-fähige Struktur (aber noch keine CLI-Flags)
- Ergebnisse werden als Tupel (correct, total, errors) zurückgegeben
- Aktuelle Baseline nach AI_002+AI_003: Kat 97%, Enrichment 100%

## Risks & Considerations
- Reines Python-Tooling — kein iOS/macOS App-Code betroffen
- `--compare` braucht zwei Prompt-Varianten — wie übergeben? (Datei vs. inline)
- Baseline-Scores sind nicht-deterministisch (On-Device-Modell schwankt ±3%)
