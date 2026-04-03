---
entity_id: INFRA_013
type: infrastructure
created: 2026-04-03
status: draft
version: "1.0"
tags: [hooks, qa, adversary, dialog]
---

# INFRA_013: Adversary als Dialog-System

## Approval
- [ ] Approved

## Purpose

Wandelt den Adversary von einem Einmal-Check ("compiliert? Tests gruen?") in einen echten Dialog zwischen QA-Agent und Implementierer. Der QA-Agent prueft inhaltlich gegen die Spec, fordert Beweise fuer jeden Expected-Behavior-Punkt, bohrt nach, und setzt das Verdict erst wenn alle Punkte bewiesen sind.

## Kontext / Motivation

Bisheriges Problem (Coach-Tab-Layout-Vorfall, 2026-04-01):
- Adversary machte einen Einzeldurchlauf: Build ok? Tests gruen? Fertig.
- Keine inhaltliche Pruefung ob das Feature tut was die Spec verspricht
- Kein Dialog: Implementierer lieferte einen Beweis, Adversary akzeptierte sofort
- Tests prueften nur Existenz ("element.exists") statt echtes Verhalten

**Bereits geloest (NICHT im Scope):**
- P0 Verdict-Ownership: `adversary_verdict` ist protected, nur `qa_gate.py` kann es setzen
- P0 GREEN-Gate: `green_approved` wird nur per User-Input gesetzt (phase_listener.py)

**Im Scope: P1 Dialog-Protokoll + P2 Inhaltliche Pruefung**

## Affected Files

| Datei | Typ | Beschreibung |
|-------|-----|-------------|
| `.claude/hooks/adversary_dialog.py` | CREATE | Dialog-Orchestrator (~150 LoC) |
| `.claude/hooks/qa_gate.py` | MODIFY | Checklist-Validierung: Alle Spec-Punkte muessen bewiesen sein |
| `.claude/commands/05-implement.md` | MODIFY | Step 8: Dialog statt Einmal-Check |
| `.claude/commands/06-validate.md` | MODIFY | Dialog-Artifact als Pflicht-Check |

## Architektur

```
Implementierer (Claude Hauptkontext)
    |
    | startet
    v
adversary_dialog.py  ───────────────────────────────────
    |                                                    |
    | 1. Liest Spec → extrahiert Expected-Behavior       |
    | 2. Erstellt Checkliste (offene Beweispunkte)       |
    | 3. Startet implementation-validator Agent           |
    |         ↕ SendMessage (min. 2 Runden)              |
    | 4. Agent fordert Beweise (Screenshots, Tests)      |
    | 5. Implementierer liefert Beweise                  |
    | 6. Agent akzeptiert ODER bohrt nach                |
    | 7. Wenn alle Punkte bewiesen → qa_gate.py          |
    | 8. Protokoll als Artifact speichern                 |
    ─────────────────────────────────────────────────────
```

## Dialog-Protokoll Format

Gespeichert als: `docs/artifacts/<workflow-name>/adversary-dialog.md`

```markdown
# Adversary Dialog — <workflow-name>
Spec: <spec-pfad>
Datum: <timestamp>

## Checkliste
- [x] Punkt 1: <Beschreibung> — Beweis: <Screenshot/Test>
- [x] Punkt 2: <Beschreibung> — Beweis: <Screenshot/Test>
- [ ] Punkt 3: <Beschreibung> — OFFEN

## Dialog

### Runde 1
**Adversary:** "Zeig mir <Spec-Punkt X> mit echten Daten."
**Implementierer:** Screenshot: /tmp/adversary_r1.png
**Adversary:** "Akzeptiert. Aber was passiert bei leerem Zustand?"

### Runde 2
**Adversary:** "Zeig mir den leeren Zustand."
**Implementierer:** Screenshot: /tmp/adversary_r2.png
**Adversary:** "Die Spec sagt 'ermutigender Text bei leerem Tag' — ich sehe keinen Text."

### Runde 3
...

## Verdict
**VERIFIED** / **BROKEN: <Begruendung>**
Offene Punkte: 0 / N
```

## adversary_dialog.py — Logik

```
Eingabe:
  - Spec-Pfad (aus Workflow-State: spec_file)
  - Workflow-Name

Ablauf:
  1. Spec lesen → Expected-Behavior-Section parsen
  2. Checkliste erstellen: Jeder Bullet-Point = ein offener Beweis
  3. implementation-validator Agent starten mit:
     - Checkliste
     - Anweisung: "Fordere fuer JEDEN Punkt einen Beweis.
       Akzeptiere NUR: Screenshots, Test-Output, konkreten Code-Pfad.
       Bohre nach wenn der Beweis duenn ist.
       Mindestens 2 Runden."
  4. Dialog-Loop:
     a. Agent nennt naechsten offenen Punkt + was er sehen will
     b. Implementierer liefert Beweis (via SendMessage)
     c. Agent bewertet: AKZEPTIERT oder NACHFRAGE
     d. Wiederholen bis alle Punkte bewiesen ODER Defekt gefunden
  5. Protokoll als Markdown in Artifact-Verzeichnis speichern
  6. Ergebnis:
     - Alle Punkte bewiesen → qa_gate.py aufrufen → VERIFIED
     - Offene Punkte → BROKEN mit Liste der offenen Punkte
```

## Aenderung an qa_gate.py

Neuer Parameter `--checklist <pfad>`:
```
python3 qa_gate.py <test-output> --checklist <dialog-artifact-pfad>
```

Zusaetzliche Validierung:
1. Dialog-Artifact existiert und ist < 60 Min alt
2. Alle Checklisten-Punkte sind [x] (abgehakt)
3. Mindestens 2 Dialog-Runden dokumentiert
4. Erst dann VERIFIED setzen

## Aenderung an 05-implement.md

Step 8 wird von:
```
Starte den implementation-validator Agent...
```
zu:
```
Starte den Adversary-Dialog:
1. python3 .claude/hooks/adversary_dialog.py
2. Der Dialog laeuft automatisch (min. 2 Runden)
3. Ergebnis wird als Artifact gespeichert
4. Bei VERIFIED → weiter zu Phase 7
5. Bei BROKEN → fixen, dann Step 7 wiederholen
```

## Aenderung an 06-validate.md

Neuer Pflicht-Check:
```
- Dialog-Artifact vorhanden? (docs/artifacts/<name>/adversary-dialog.md)
- Alle Checklisten-Punkte bewiesen?
- Mindestens 2 Dialog-Runden?
```

## Expected Behavior

**Normaler Ablauf (Feature besteht):**
1. Implementierer ruft `adversary_dialog.py` auf
2. Script parst Spec → findet 4 Expected-Behavior-Punkte
3. Adversary-Agent fordert Beweis fuer Punkt 1 → Implementierer liefert Screenshot
4. Agent akzeptiert, fordert Punkt 2 → Implementierer liefert Test-Output
5. Agent bohrt nach bei Punkt 3: "Was passiert bei leerem Zustand?" → Implementierer liefert Screenshot
6. Agent akzeptiert alle 4 Punkte nach 3 Runden
7. Protokoll gespeichert, qa_gate.py → VERIFIED

**Fehlerhafter Ablauf (Feature hat Defekt):**
1. Wie oben, aber bei Punkt 3 zeigt Screenshot falsches Verhalten
2. Agent: "Spec sagt X, Screenshot zeigt Y → BROKEN"
3. Protokoll gespeichert mit offenem Punkt
4. qa_gate.py wird NICHT aufgerufen → Verdict bleibt null
5. Implementierer muss fixen und Dialog erneut starten

**Edge Cases:**
- Spec hat keine Expected-Behavior-Section → Warnung, Fallback auf altes Verhalten
- Infra-Tickets ohne UI → `--no-visual` Flag bleibt, aber Checkliste trotzdem Pflicht
- Agent-Timeout → Dialog abbrechen, BROKEN mit Timeout-Grund

## Scoping

- **4 Dateien** (1 neu, 3 modifiziert)
- **~200 LoC** geschaetzt (150 neu + 50 Modifikationen)
- **Keine Seiteneffekte** auf bestehende Tests oder Workflows
- **Bestehende Unit/UI-Tests bleiben unberuehrt**

## Known Limitations

- Dialog-Qualitaet haengt von der Spec-Qualitaet ab (schlecht formulierte Expected-Behavior → schwache Checkliste)
- Agent-zu-Agent-Kommunikation via SendMessage ist sequentiell (kein echter Parallelismus)
- Screenshots sind Moment-Aufnahmen — dynamisches Verhalten schwer zu beweisen

## Test Plan

Python Unit Tests fuer `adversary_dialog.py`:
1. Spec-Parsing: Extrahiert Expected-Behavior-Punkte korrekt
2. Checklisten-Erzeugung: Jeder Punkt wird zu einem offenen Item
3. Dialog-Artifact-Format: Markdown ist valide, enthaelt Runden + Checkliste
4. qa_gate.py mit `--checklist`: Blockiert bei offenen Punkten
5. qa_gate.py mit `--checklist`: Blockiert bei < 2 Runden
6. qa_gate.py mit `--checklist`: VERIFIED bei vollstaendiger Checkliste

## Changelog

- 2026-04-03: Initial spec created
