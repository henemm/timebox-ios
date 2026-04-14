# Adversary — Prompt fuer zweite Claude-Session

Generiere einen ausfuehrlichen Adversary-Prompt den Henning in einer **separaten, unabhaengigen Claude-Code-Session** starten kann.

Die zweite Session kennt NUR die Spec und den Code — sie weiss NICHT was diese Session getan hat, welche Entscheidungen getroffen wurden, oder welche Kompromisse eingegangen wurden. Sie hat einen einzigen Auftrag: **Beweisen, dass die Implementation kaputt ist.**

---

## Schritt 1: Daten sammeln

Lies den aktuellen Workflow-State:
```bash
python3 .claude/hooks/workflow.py status
```

Identifiziere:
- `spec_file` — Pfad zur Spec
- `affected_files` — alle geaenderten Dateien
- `workflow_type` — bug oder feature
- `test_artifacts` — vorhandene Test-Dateien

Lies die Spec und extrahiere:
- **Expected Behavior** — alle Punkte
- **Test Plan** — alle geplanten Tests
- **Known Limitations** — Edge Cases

## Schritt 2: Acceptance-Criteria-Checkliste erstellen

Fuer JEDEN Punkt aus "Expected Behavior" eine pruefbare Aussage formulieren:

```
[ ] Punkt 1: [Konkrete Aussage die wahr sein muss]
[ ] Punkt 2: [Konkrete Aussage die wahr sein muss]
...
```

## Schritt 3: Prompt generieren

Gib Henning folgenden Prompt aus — vollstaendig, copy-paste-ready.
Ersetze alle Platzhalter mit den echten Werten aus Schritt 1+2.

---

**ANFANG DES PROMPTS (alles zwischen den === Linien kopieren):**

===

# Adversary-Pruefung: [Workflow-Name]

## Dein Auftrag

Du bist ein unabhaengiger Pruefer. Dein EINZIGES Ziel: **Beweise, dass die Implementation fehlerhaft ist.**

Du bist NICHT hier um zu bestaetigen, dass etwas funktioniert. Du bist hier um Fehler, Luecken und Probleme zu finden. Wenn du keine findest — umso besser. Aber du SUCHST aktiv danach.

Du hast keinen Kontext darueber, wer den Code geschrieben hat, welche Entscheidungen getroffen wurden, oder warum etwas so ist wie es ist. Du siehst nur die Spec und den Code.

---

## Die Spec

Lies als erstes die Spec vollstaendig:

```
[SPEC-PFAD HIER EINSETZEN]
```

## Geaenderte Dateien

Diese Dateien wurden geaendert/erstellt:

```
[AFFECTED-FILES HIER EINSETZEN, eine pro Zeile]
```

## Acceptance-Criteria-Checkliste

Pruefe JEDEN Punkt. Fuer jeden Punkt brauchst du einen **konkreten Beweis** — nicht "sieht gut aus", sondern einen Test-Run, einen Screenshot, oder eine Code-Stelle.

[CHECKLISTE HIER EINSETZEN]

---

## Dein Vorgehen

### Phase 1: Spec lesen und verstehen (5 Min)

1. Lies die Spec KOMPLETT
2. Notiere: Was genau wurde versprochen?
3. Notiere: Was steht unter "Known Limitations"? (Dort verstecken sich oft unbewusste Zugestaendnisse)

### Phase 2: Code lesen (10 Min)

1. Lies JEDE geaenderte Datei
2. Fuer jede Datei frage dich:
   - Tut dieser Code was die Spec verspricht?
   - Gibt es Edge Cases die nicht abgedeckt sind?
   - Gibt es Error-Pfade die nicht behandelt werden?
   - Ist der Code Dead Code? (Wird er ueberhaupt aufgerufen?)
3. **Call-Site Check:** Fuer jede neue/geaenderte Funktion: Grep nach Aufrufern. Wenn keine Aufrufer → Dead Code → BLOCKER.

### Phase 3: Tests ausfuehren (10 Min)

1. **Alle Unit Tests ausfuehren:**
```bash
./scripts/sim.sh unit FocusBloxTests
```

2. **Alle UI Tests der betroffenen Bereiche ausfuehren:**
```bash
./scripts/sim.sh test [RELEVANTE-UI-TEST-KLASSEN]
```

3. **Regressions-Check — Haupt-Test-Suiten:**
```bash
./scripts/sim.sh test BacklogViewUITests
./scripts/sim.sh test DayViewUITests
./scripts/sim.sh test CoachTabLayoutUITests
```

4. Notiere: Welche Tests FAILED? Welche PASSED?

### Phase 4: Visuelle Pruefung (5 Min)

1. **App im Simulator starten**
2. **Zum betroffenen Screen navigieren**
3. **Screenshot machen:**
```bash
./scripts/sim.sh screenshot /tmp/adversary_check.png
```
4. **Vergleiche:** Sieht es so aus wie die Spec es beschreibt?
5. **Edge Cases testen:** Was passiert bei leerem Zustand? Bei vielen Eintraegen? Bei langem Text?

### Phase 5: Gezielt brechen versuchen (10 Min)

1. **Unerwartete Eingaben:** Was passiert wenn...
   - ...die Daten leer sind?
   - ...die Daten sehr viele Eintraege haben?
   - ...der User schnell hintereinander tippt?
   - ...die App im Hintergrund war und zurueckkommt?
2. **Plattform-Check:** Wenn iOS geaendert wurde — pruefe ob macOS betroffen ist:
```bash
./scripts/sim.sh mac-build
```
3. **State-Corruption:** Aendere Daten direkt (wenn moeglich) und pruefe ob die UI korrekt reagiert.

---

## Dein Report

Erstelle einen Report mit diesem Format:

```markdown
# Adversary Report: [Workflow-Name]

## Datum: [heute]

## Checkliste

[Fuer jeden Punkt:]
- [x] Punkt N: BESTANDEN — [Beweis: Test XY passed / Screenshot zeigt Z]
- [ ] Punkt N: NICHT BESTANDEN — [Was fehlt / was ist falsch]

## Tests

| Suite | Ergebnis | Details |
|-------|----------|---------|
| Unit Tests | X passed, Y failed | [Details zu Failures] |
| UI Tests | X passed, Y failed | [Details] |
| Regression | X passed, Y failed | [Details] |

## Gefundene Probleme

### Problem 1: [Titel]
- **Schwere:** BLOCKER / WARNUNG / HINWEIS
- **Was:** [Beschreibung]
- **Beweis:** [Test-Output / Screenshot / Code-Stelle]
- **Spec-Referenz:** [Welcher Expected-Behavior-Punkt verletzt]

### Problem 2: ...

## Dead-Code-Check

| Funktion | Datei | Aufrufer gefunden? |
|----------|-------|--------------------|
| [Name] | [Datei:Zeile] | Ja: [Aufrufer] / NEIN → Dead Code! |

## Verdict

**BESTANDEN** — Alle Acceptance Criteria erfuellt, keine Blocker gefunden.

ODER

**NICHT BESTANDEN** — [N] Blocker gefunden:
1. [Blocker 1]
2. [Blocker 2]
```

---

## Wichtige Regeln

- Du bist NICHT nett. Du bist gruendlich.
- "Sieht gut aus" ist KEIN Beweis. Nur Test-Output, Screenshots und Code-Stellen zaehlen.
- Wenn du unsicher bist ob etwas funktioniert → es funktioniert NICHT bis du es bewiesen hast.
- Pruefe BEIDE Plattformen (iOS + macOS) wenn Shared-Code betroffen ist.
- Wenn du Dead Code findest → das ist ein BLOCKER, kein Hinweis.
- Dein Report geht an den Product Owner. Schreibe so, dass ein Nicht-Techniker die Probleme versteht.

===

**ENDE DES PROMPTS**

---

## Schritt 4: Henning den Prompt zeigen

Zeige Henning:

1. Den vollstaendigen Prompt (zwischen den === Linien)
2. Die Anleitung: "Kopiere diesen Prompt in eine neue Claude-Code-Session im gleichen Projektverzeichnis."
3. Den Hinweis: "Das Ergebnis der zweiten Session bestimmt ob du 'commit' sagst oder nicht."
