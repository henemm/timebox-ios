# Analyse: Feature #308 — Workflow-Verbesserungen aus agent-os-openspec v3.1

## User-Erwartung (User Advocate)

Die Verbesserungen sind für den App-User unsichtbar — sie betreffen ausschließlich Henning als Product Owner.

**Was jede Verbesserung in Hennings Sprache bedeutet:**

1. **LoC-Limit**: "Ich sage 'bau mir einen kleinen Button', und wenn ich zurückkomme wurden 500 Zeilen geändert. Die Verbesserung bedeutet: Wenn zu viel geändert wird, kommt automatisch eine Warnung — bevor es passiert."

2. **AC-Format-Check**: "Jemand hat angefangen zu arbeiten ohne dass klar war was fertig aussieht. Die Verbesserung bedeutet: Ohne genehmigte Beschreibung kommt man gar nicht ans Coden — der Startschuss ist gesperrt."

3. **Adversary-Verdict**: "Das fühlt sich an wie eine Qualitätsprüfung die man ignorieren kann. Die Verbesserung bedeutet: Ein 'BROKEN' ist eine echte Sperre, kein freundlicher Hinweis."

4. **Execution Log**: "Wenn ich drei Wochen später frage 'wie haben wir das damals gemacht' — keine Ahnung. Die Verbesserung bedeutet: Es gibt eine Aufzeichnung als Beweissicherung."

**Risiko vom User Advocate:** Strengere Regeln können langsamer machen. Kleinen Fix braucht nicht dieselben Schleusen wie ein großes Feature.

## Technische Analyse (Feature Planner)

### Empfehlung: 3 separate Workflows

Das 250 LoC Scope-Limit erzwingt eine Aufteilung. Die 3 Schritte sind logisch unabhängig:

**Workflow #308-A (jetzt, klein ~60 LoC):**
- LoC-Delta-Check in `workflow.py _validate_transition()` (Zeile 298-378)
- AC-Format-Check in `edit_gate.py` oder `workflow.py`
- AMBIGUOUS-Block + `override-ambiguous` in `bash_gate.py` (Zeile 358)
- Dateien: `workflow.py` + `bash_gate.py` (nur 2!)

**Workflow #308-B (danach, mittel):**
- `adversary_dialog.py` neu — strukturiertes Protokoll
- Prompts anpassen

**Workflow #308-C (zuletzt, klein):**
- `workflow.py write-log` — Execution Log
- `/06-validate` Command

### Betroffene Dateien gesamt
- `.claude/hooks/workflow.py`
- `.claude/hooks/bash_gate.py`
- `.claude/hooks/edit_gate.py` (ggf.)
- `.claude/hooks/adversary_dialog.py` (neu, #308-B)
- `.claude/prompts/adversary.md` (neu, #308-B)
- `.claude/prompts/fresh-eyes-inspector.md` (neu, #308-B)

## Scope-Schätzung

| Workflow | Dateien | LoC-Delta | Aufwand |
|----------|---------|-----------|---------|
| #308-A   | 2       | ~60       | Klein   |
| #308-B   | 3       | ~120      | Mittel  |
| #308-C   | 1-2     | ~80       | Klein   |

## Empfehlung des Orchestrators

Mit **#308-A starten** (Prio 1+2c). Diese Session implementiert nur #308-A.
#308-B und #308-C bekommen eigene Issues + Workflows.
