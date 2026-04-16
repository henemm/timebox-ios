# Feature-Analyse: Adversary-Findings-Gate

## User-Erwartung (User Advocate)

Henning will ALLE Findings sehen und SELBST entscheiden. Kein Vorfiltern durch Claude.

Jedes Finding muss:
- In nicht-technischer Sprache beschrieben sein
- Einen Beweis haben (Test/Screenshot)
- Sagen: "Was passiert wenn ich es NICHT fixe?"
- Per Auswahl beantwortet werden (Fixen / Akzeptabel)
- Dokumentiert werden für spätere Nachvollziehbarkeit

Risiko: Zu viele Code-Quality-Findings (fehlende Kommentare etc.) nerven. Der Adversary soll nur User-relevante Findings vorlegen, keine Code-Reviews.

## Technische Analyse (Feature Planner)

### Betroffene Dateien (4 Dateien)
1. `.claude/hooks/workflow.py` — neue Commands `add-finding`, `resolve-finding` + Gate in `_validate_transition()`
2. `.claude/hooks/bash_gate.py` — Commit-Gate prüft offene Findings
3. `.claude/hooks/phase_listener.py` — minimale Erweiterung
4. `.claude/commands/adversary.md` — Prompt-Erweiterung für strukturierte Findings

### Bestehende Patterns
- `test_artifacts`-Liste als Vorlage für `adversary_findings`-Struktur
- `PROTECTED_FIELDS` + `WORKFLOW_CALLER`-Check für Schutz
- `_validate_transition()` Erweiterungs-Pattern

### Flow
1. Adversary schreibt Findings als JSON-Block
2. Claude überträgt via `workflow.py add-finding`
3. Claude legt jedes Finding via AskUserQuestion vor
4. Henning antwortet → Claude ruft `workflow.py resolve-finding <id> <status>`
5. Gate in `_validate_transition()` prüft: alle resolved? → Checkpoint 3 möglich
