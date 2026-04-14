# Bug analysieren und fixen

**Bug:** $ARGUMENTS

---

## GRUNDANNAHME: ICH LIEGE FALSCH

Gehe bei JEDEM Schritt davon aus, dass deine Annahme falsch ist.

- Wenn du **ueberzeugt bist** die Ursache zu kennen → du brauchst TROTZDEM Beweis
- Wenn du denkst Debugging sei unnoetig → **genau dann ist es noetig**
- Wenn dein Fix "offensichtlich richtig" aussieht → pruefe ob er ueberhaupt aufgerufen wird
- Wenn du nur eine Plattform pruefst → **die andere ist wahrscheinlich auch betroffen**

---

## Schritt 0: TRIAGE — 3 Fragen BEVOR irgendetwas passiert

1. **Welche Plattform?** (iOS, macOS, oder beide?)
2. **Welcher Screen/View?** (Was siehst du gerade?)
3. **Was genau getan, was genau gesehen?**

**Kein naechster Schritt ohne Antworten.**

---

## Schritt 0.5: BUG REPRODUZIEREN — "So sieht es kaputt aus"

**BEVOR du in den Code schaust: Bug nachstellen!**

Ohne Reproduktion kannst du nie beweisen, dass dein Fix funktioniert hat.

1. **Simulator starten, zum betroffenen Screen navigieren**
2. **Bug ausloesen** (die Schritte aus der Beschreibung nachstellen)
3. **Screenshot machen:**
```bash
./scripts/sim.sh screenshot /tmp/bug_vorher.png
```
4. **Ergebnis festhalten:** Was genau ist sichtbar? Was fehlt? Was ist falsch?

### Bug nicht reproduzierbar?

| Situation | Aktion |
|-----------|--------|
| Bug tritt nicht auf | Henning fragen: "Ich kann den Bug nicht reproduzieren. Kannst du die Schritte praezisieren?" |
| Bug ist Timing-abhaengig | Notieren und in Analyse beruecksichtigen |
| Bug braucht bestimmte Daten | Mock-Daten/Launch-Arguments nutzen |

**KEIN naechster Schritt ohne Reproduktion oder Erklaerung warum nicht moeglich.**

---

## STRUKTURELLER ZWANG: Parallele Agenten mit verschiedenen Diagnosen

**KEIN Fix-Vorschlag bevor ALLE Investigate-Tasks COMPLETED sind.**
Die Agenten MUESSEN verschiedene Richtungen untersuchen — nicht alle die gleiche Hypothese bestaetigen.

---

## Schritt 1: Workflow starten

```bash
python3 .claude/hooks/workflow.py start "bug-[kurzer-name]"
python3 .claude/hooks/workflow.py set-field workflow_type bug
python3 .claude/hooks/workflow.py phase phase1_context
```

## Schritt 2: Investigate-Tasks erstellen

Erstelle mit `TaskCreate` diese 5 Tasks (ALLE PFLICHT):

| # | Task Subject | Description |
|---|-------------|-------------|
| 1 | **Wiederholungs-Check** | Git-History, GitHub Issues und Memory nach verwandten Bugs durchsuchen. |
| 2 | **Datenfluss-Trace** | KOMPLETTEN Datenfluss tracen: Wo erstellt, transformiert, gespeichert, gelesen. |
| 3 | **Alle Schreiber finden** | JEDE Stelle die das betroffene Feld/Objekt SCHREIBT. |
| 4 | **Alle Szenarien auflisten** | ALLE Szenarien: User-Flows, Sync, Timer, Background, Edge Cases. |
| 5 | **Blast Radius pruefen** | Welche anderen Features nutzen denselben Code? |

## Schritt 3: Agenten PARALLEL losschicken

**ALLE 5 PARALLEL** — nicht sequentiell!

## Schritt 4: WARTEN bis ALLE Agenten fertig sind

**STOP!** Nicht weitermachen bis alle 5 Tasks COMPLETED sind.

## Schritt 5: Synthese — Analyse-Dokument erstellen

Erstelle `docs/artifacts/bug-[name]/analysis.md` mit:

### 5a. Zusammenfassung der Agenten-Ergebnisse
### 5b. ALLE moeglichen Ursachen (mindestens 3 Hypothesen)
### 5c. Wahrscheinlichste Ursache(n) mit Begruendung
### 5d. Blast Radius

## Schritt 6: **CHECKPOINT 1** — Henning die Analyse praesentieren

**Zeige Henning:**
1. **Kaputt-Screenshot** (aus Schritt 0.5) — "So sieht der Bug aus"
2. Root Cause (in verstaendlicher Sprache)
3. Betroffene Stellen (welche Screens/Features)
4. Vorgeschlagener Ansatz (1-2 Saetze)
5. Blast Radius

**Henning sagt "stimmt" → Checkpoint 1 freigeschaltet.**

```bash
python3 .claude/hooks/workflow.py phase phase3_spec
```

## Schritt 7: Spec schreiben + Approval

Nutze `/03-write-spec` fuer die Spec.
**Henning sagt "approved" → Spec freigeschaltet.**

## Schritt 7.5: Affected Files registrieren

```bash
python3 .claude/hooks/workflow.py set-affected-files --replace \
  "Sources/path/to/affected1.swift" \
  "Tests/path/to/TestFile.swift"
```

## Schritt 8: TDD RED

```bash
python3 .claude/hooks/workflow.py phase phase4_tdd_red
```

Nutze `/04-tdd-red` — leite Tests aus der Analyse ab.

## Schritt 8.5: **CHECKPOINT 2** — Henning die Tests praesentieren

**Zeige Henning:**
| Test | Was er prueft | Status |
|------|--------------|--------|
| testXYZ | Prueft ob X passiert wenn Y | FAILED ✓ |

**Henning sagt "go" → Checkpoint 2 freigeschaltet.**

## Schritt 9: Implementation

```bash
python3 .claude/hooks/workflow.py phase phase5_implement
```

Nutze `/05-implement` — dort ist die Bug-Reproduktions-Wiederholung eingebaut (Step 6).

## Schritt 10: **CHECKPOINT 3** — Henning das Ergebnis praesentieren

**Zeige Henning:**
1. **Vorher-Screenshot** (aus Schritt 0.5) + **Nachher-Screenshot** (aus /05-implement Step 6)
2. ALL GREEN Test-Output
3. Kurze Zusammenfassung was sich geaendert hat

**Optional:** Henning kann jetzt `/adversary` in einer zweiten Claude-Session starten.

**Henning sagt "commit" → Checkpoint 3 freigeschaltet.**

## Schritt 11: Commit + Dokumentation

```bash
python3 .claude/hooks/workflow.py phase phase6_done
```

- Git commit mit Issue-Referenz
- GitHub Issue schliessen (`gh issue close <number>`)
- `python3 .claude/hooks/workflow.py complete`

---

## Anti-Patterns (VERBOTEN!)

- **Fix vorschlagen bevor alle Tasks completed**
- **Nur 1 Hypothese aufstellen** — mindestens 3 Hypothesen PFLICHT
- **"Bitte manuell testen"** — UI Tests sind PFLICHT
- **Bisherige Fixes ignorieren** — Wiederholungs-Check ist Task 1

### Eskalations-Regel

**Max 2 Versuche** fuer denselben Ansatz. Danach: Ansatz wechseln ODER Henning fragen.
