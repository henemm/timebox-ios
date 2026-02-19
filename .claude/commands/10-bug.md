# Bug analysieren und fixen

**Bug:** $ARGUMENTS

---

## STRUKTURELLER ZWANG: Tasks + Agenten

**Dieses Skill erzwingt gruendliche Analyse durch PARALLELE Agenten.**
**Du sammelst ZUERST alle Fakten, DANN bewertest du.**
**KEIN Fix-Vorschlag bevor ALLE Investigate-Tasks COMPLETED sind.**

---

## Schritt 1: Workflow starten

```bash
python3 .claude/hooks/workflow_state_multi.py start "bug-[kurzer-name]"
python3 .claude/hooks/workflow_state_multi.py phase phase1_context
```

## Schritt 2: Investigate-Tasks erstellen

Erstelle mit `TaskCreate` diese 5 Tasks (ALLE PFLICHT):

| # | Task Subject | Description |
|---|-------------|-------------|
| 1 | **Wiederholungs-Check** | Git-History, ACTIVE-todos.md und Memory nach verwandten Bugs durchsuchen. ALLE bisherigen Fixes + warum sie nicht gehalten haben. |
| 2 | **Datenfluss-Trace** | KOMPLETTEN Datenfluss der betroffenen Daten tracen: Wo erstellt, wo transformiert, wo gespeichert, wo gelesen. JEDE Funktion die die Daten anfasst mit Datei+Zeile. |
| 3 | **Alle Schreiber finden** | JEDE Stelle im Code finden die das betroffene Feld/Objekt SCHREIBT (direkt oder indirekt). Grep nach Feldnamen, Property-Zuweisungen, init-Aufrufen. |
| 4 | **Alle Szenarien auflisten** | ALLE Szenarien in denen das Problem auftreten kann: User-Flows, Sync, Timer, Background, Edge Cases, Race Conditions, Geraete-Neustart, Offline. |
| 5 | **Blast Radius pruefen** | Welche anderen Features/Flows nutzen denselben Code? Gibt es aehnliche Patterns die das gleiche Problem haben koennten? |

## Schritt 3: Agenten PARALLEL losschicken

Schicke fuer Task 1-5 jeweils einen `Task`-Agenten (subagent_type: `Explore` oder `bug-investigator`) los.
**ALLE 5 PARALLEL** — nicht sequentiell!

```
Task 1: Explore-Agent -> Git-History + Todos + Memory durchsuchen
Task 2: Explore-Agent -> Datenfluss von Quelle bis Anzeige tracen
Task 3: Explore-Agent -> Grep nach allen Schreibzugriffen auf betroffene Felder
Task 4: Explore-Agent -> Alle Szenarien die das Problem ausloesen koennten
Task 5: Explore-Agent -> Blast Radius + aehnliche Patterns
```

## Schritt 4: WARTEN bis ALLE Agenten fertig sind

**STOP!** Nicht weitermachen bis alle 5 Tasks COMPLETED sind.
Markiere jeden Task als `completed` wenn der Agent sein Ergebnis liefert.

Pruefe mit `TaskList` ob alle 5 Tasks completed sind.
**Wenn NEIN -> WARTEN. Wenn JA -> weiter zu Schritt 5.**

## Schritt 5: Synthese — Analyse-Dokument erstellen

Erst JETZT — mit ALLEN Fakten aus den 5 Agenten — das Analyse-Dokument schreiben.

Erstelle `docs/artifacts/bug-[name]/analysis.md` mit:

### 5a. Zusammenfassung der Agenten-Ergebnisse
- Was hat jeder Agent gefunden?
- Wo ueberlappen sich die Ergebnisse?

### 5b. ALLE moeglichen Ursachen auflisten

Liste JEDE moegliche Ursache auf die aus den Agenten-Ergebnissen hervorgeht.
**Mindestens 3 Hypothesen.** Fuer jede:
- Hypothese beschreiben
- Beweis DAFUER (Code-Stellen, Datenfluss)
- Beweis DAGEGEN (warum es doch nicht diese Ursache sein koennte)
- Wahrscheinlichkeit (hoch/mittel/niedrig)

### 5c. Wahrscheinlichste Ursache(n) waehlen

Erst NACH dem Auflisten aller Hypothesen die wahrscheinlichste(n) waehlen.
**Mit Begruendung warum die anderen weniger wahrscheinlich sind.**

### 5d. Blast Radius
- Welche anderen Features/Flows koennten betroffen sein?
- Gibt es aehnliche Patterns die das gleiche Problem haben?

## Schritt 6: Henning die Analyse praesentieren

Zeige Henning:
1. Die Anzahl gefundener Hypothesen
2. Die wahrscheinlichste Ursache mit Beweis
3. Den Blast Radius
4. Frage: "Soll ich auf dieser Basis einen Fix vorschlagen?"

**WARTE auf Hennings Bestaetigung.**

## Schritt 7: Fix vorschlagen (NICHT implementieren!)

Erst nach OK:
1. Fix-Ansatz beschreiben (Dateien, Aenderungen)
2. Erklaeren WARUM dieser Fix ALLE identifizierten Ursachen adressiert (nicht nur eine)
3. Erklaeren WARUM dieser Fix keine neuen Probleme verursacht
4. **Warte erneut auf Freigabe**

## Schritt 8: TDD RED + Implementierung

Nach Freigabe — normaler TDD-Zyklus:
```bash
python3 .claude/hooks/workflow_state_multi.py phase phase5_tdd_red
```

Nutze `/tdd-red` — leite Tests aus der Analyse ab:
- **Root Cause** → Regressions-Test (Input der den Bug ausloest → korrektes Ergebnis)
- **Blast Radius** → Tests fuer betroffene Flows
- Fuer jeden Test: "Welche Zeile bricht diesen Test?" — wenn nicht beantwortbar, Test streichen

## Schritt 9: Dokumentation
- `docs/ACTIVE-todos.md` aktualisieren
- Memory-Files aktualisieren falls neues Pattern entdeckt

---

## Anti-Patterns (VERBOTEN!)

- **Agenten sequentiell statt parallel schicken** — IMMER alle 5 gleichzeitig!
- **Fix vorschlagen bevor alle Tasks completed** — STRUKTURELL blockiert
- **Nur 1 Hypothese aufstellen** — mindestens 3 Hypothesen PFLICHT
- **"Ich hab die Root Cause nach 5 Minuten"** — bei komplexen Bugs nie
- **"Bitte manuell testen"** — UI Tests sind PFLICHT
- **Bisherige Fixes ignorieren** — Wiederholungs-Check ist Task 1

---

**Injizierte Standards:**
- `.agent-os/standards/global/analysis-first.md`
- `.agent-os/standards/global/scoping-limits.md`
