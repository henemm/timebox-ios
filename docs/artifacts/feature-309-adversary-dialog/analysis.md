# Analyse: Feature #309 — Adversary-Dialog strukturieren + Fresh-Eyes-Agent

## User-Erwartung (User Advocate)

Der Adversary soll sich wie eine echte Prüfung anfühlen, nicht wie ein Abnicken.

- Klares Verdict (VERIFIED / BROKEN / AMBIGUOUS) ganz oben, nicht im Fließtext versteckt
- Protokoll in normaler Sprache les- und nachvollziehbar für Henning
- Fresh-Eyes-Inspector muss wirklich ohne Vorwissen arbeiten — das ist sein Kern-Versprechen
- AMBIGUOUS braucht eine konkrete Entscheidungsfrage, nicht nur "irgendwas stimmt nicht"
- Wenn 3 Iterationen nicht ausreichen: klares Signal, kein stilles Hängen

**Risiko vom User Advocate:** Zwei erzwungene Runden können sich künstlich anfühlen wenn Runde 1 schon alles klärt. Struktur allein ersetzt keine Qualität — Checklisten können mechanisch abgehakt werden.

## Technische Analyse (Feature Planner)

### Wichtige Vorgeschichte

`adversary_dialog.py` und `fresh-eyes-inspector.md` existierten bereits (Commit `3fa19cd6`, April 2026), wurden aber im Workflow-v5-Refactor (`650b7057`) bewusst entfernt. Die aktuelle `adversary.md` ist ein Command der einen Prompt für eine manuelle zweite Session generiert.

Die INFRA_013-Spec (`docs/specs/infra/INFRA_013-adversary-dialog.md`) ist vollständig vorhanden und beschreibt genau was #309 will.

### Was entsteht

**Neu:**
- `.claude/hooks/adversary_dialog.py` — Spec-Parser + Checklisten-Generator + Artifact-Validator (~120 LoC Python)
- `.claude/agents/fresh-eyes-inspector.md` — Agent-Prompt für unabhängigen Screenshot-Beobachter (~30 LoC Markdown)

**Überarbeitet:**
- `.claude/commands/adversary.md` — strukturiertes Protokoll mit Checklisten-Format und Tri-State-Verdict

### Wichtige Architektur-Einschränkung

`adversary_dialog.py` kann als Python-Prozess keine Sub-Agenten spawnen. Das Skript ist ein Helfer:
1. Liest Spec → extrahiert Expected-Behavior → gibt Checkliste aus
2. Validiert ob das Dialog-Artifact alle Punkte abdeckt
Claude selbst orchestriert weiterhin den implementation-validator Agent.

### Scope

| Datei | Typ | Est. LoC (Code) |
|-------|-----|---------|
| `.claude/hooks/adversary_dialog.py` | NEU | ~120 |
| `.claude/commands/adversary.md` | ÜBERARBEITET | ~30 Delta |
| `.claude/agents/fresh-eyes-inspector.md` | NEU | Markdown (zählt nicht) |

2 Code-Dateien, ~150 LoC — deutlich unter dem 250-Limit.

## Empfehlung des Orchestrators

Umsetzen wie beschrieben. Die INFRA_013-Spec als Basis verwenden, aber einfacher als damals:
- Kein vollständiger Dialog-Orchestrator (war zu komplex und wurde deshalb entfernt)
- Nur Spec-Parser + Artifact-Validator als Python-Helper
- `adversary.md` wird strukturierter Prompt mit Checklisten-Pflicht + Tri-State-Verdict
