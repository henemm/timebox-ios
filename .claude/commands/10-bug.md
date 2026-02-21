# Bug analysieren und fixen

**Bug:** $ARGUMENTS

---

## GRUNDANNAHME: ICH LIEGE FALSCH

Gehe bei JEDEM Schritt davon aus, dass deine Annahme falsch ist.
Nicht als Checkliste, sondern als Denkweise:

- Wenn du **ueberzeugt bist** die Ursache zu kennen → du brauchst TROTZDEM Beweis (Logging, Reproduktion)
- Wenn du denkst Debugging sei unnoetig → **genau dann ist es noetig**, weil deine Ueberzeugung unbegründet ist
- Wenn dein Fix "offensichtlich richtig" aussieht → pruefe ob er ueberhaupt aufgerufen wird (Dead Code ist dein Muster)
- Wenn du nur eine Plattform pruefst → **die andere ist wahrscheinlich auch betroffen**

**Konsequenz:** Jede Hypothese muss BEWIESEN werden bevor sie zum Fix wird.
Beweisen = Logging einbauen, ausfuehren, Output lesen. Nicht: "Code lesen und fuer plausibel halten."

---

## Schritt 0: TRIAGE — 3 Fragen BEVOR irgendetwas passiert

1. **Welche Plattform?** (iOS, macOS, oder beide?)
2. **Welcher Screen/View?** (Was siehst du gerade?)
3. **Was genau getan, was genau gesehen?**

**Kein naechster Schritt ohne Antworten.** Kostet 30 Sekunden, spart Stunden.

> Negativbeispiel: Bug Feedback-Overlay — 200k+ Tokens verbrannt weil nie gefragt wurde ob iOS oder macOS.

---

## Schritt 0.5: EXISTENZ-CHECK — Gibt es das Feature ueberhaupt?

**Annahme: Das Feature wurde nie implementiert.**

1. `git log --oneline | grep -i [feature]`
2. `Grep` nach UI-Elementen (.searchable, Button-Identifier, etc.)
3. ACTIVE-todos.md — steht es noch als OFFEN?

Wenn nie implementiert → **kein Bug**. Henning informieren, `/implement` vorschlagen.

> Negativbeispiel: "Suche nicht sichtbar" — war nie gebaut worden, nur Spec existierte.

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

### 5d. WIE BEWEISE ICH DASS ICH RECHT HABE?

**Annahme: Deine Top-Hypothese ist falsch.**

Fuer die wahrscheinlichste Ursache beschreiben:
- **Welches Logging/Debugging wuerde die Hypothese BESTAETIGEN?** (z.B. "Wenn ich an Zeile X einen Logger setze, muesste Y im Output stehen")
- **Welches Logging wuerde die Hypothese WIDERLEGEN?** (z.B. "Wenn stattdessen Z im Output steht, ist meine Hypothese falsch")
- **Auf welcher Plattform muss ich pruefen?** (iOS? macOS? beide?)

Diesen Debugging-Plan Henning zeigen. Wenn Henning den Fix direkt will, kann er das Debugging ueberspringen.
Aber **DU** darfst es nicht ueberspringen nur weil du ueberzeugt bist.

### 5e. Blast Radius
- Welche anderen Features/Flows koennten betroffen sein?
- Gibt es aehnliche Patterns die das gleiche Problem haben?

## Schritt 5.5: Devil's Advocate — Analyse challengen

**PFLICHT vor Praesentation an Henning!**

Schicke einen `analysis-challenger` Agenten los mit:
- Pfad zur `docs/artifacts/bug-[name]/analysis.md`
- Die originale Bug-Beschreibung (Symptom)

```
Task: analysis-challenger Agent
Input: analysis.md Pfad + Bug-Beschreibung
Output: Challenge Report mit Verdict (SOLIDE / LUECKEN / SCHWACH)
```

### Nach dem Challenge Report:

| Verdict | Aktion |
|---------|--------|
| **SOLIDE** | Weiter zu Schritt 6 — Analyse Henning praesentieren |
| **LUECKEN** | Offene Fragen und uebersehene Hypothesen in die Analyse einarbeiten. Dann ERNEUT challengen lassen. |
| **SCHWACH** | Zurueck zu Schritt 2 — neue Investigate-Tasks fuer die gefundenen Luecken. NICHT mit schwacher Analyse weitermachen! |

**Max 2 Challenge-Runden.** Wenn nach 2 Runden immer noch SCHWACH → Henning informieren mit den offenen Fragen.

## Schritt 6: Henning die Analyse praesentieren

Zeige Henning:
1. Die Anzahl gefundener Hypothesen
2. Die wahrscheinlichste Ursache mit Beweis
3. Den Blast Radius
4. **Challenge-Verdict** (SOLIDE/LUECKEN) + wichtigste offene Frage falls vorhanden
5. Frage: "Soll ich auf dieser Basis einen Fix vorschlagen?"

**WARTE auf Hennings Bestaetigung.**

## Schritt 7: Fix vorschlagen (NICHT implementieren!)

**Annahme: Dein Fix adressiert nicht die echte Ursache. Oder er ist Dead Code.**

Erst nach OK:
1. Fix-Ansatz beschreiben (Dateien, Aenderungen)
2. Erklaeren WARUM dieser Fix ALLE identifizierten Ursachen adressiert (nicht nur eine)
3. Erklaeren WARUM dieser Fix keine neuen Probleme verursacht
4. **Call-Site benennen:** Wo wird der neue/geaenderte Code AUFGERUFEN? (Datei+Zeile)
   - Wenn keine Call-Site benennbar → **Fix ist Dead Code. Ueberarbeiten.**
5. **Plattform-Check:** Muss der Fix auf iOS UND macOS angewendet werden?
   - Bekannte Divergenz: BacklogView (iOS) vs. ContentView (macOS) — oft BEIDE betroffen
6. **Warte erneut auf Freigabe**

## Schritt 8: TDD RED + Implementierung

Nach Freigabe — normaler TDD-Zyklus:
```bash
python3 .claude/hooks/workflow_state_multi.py phase phase5_tdd_red
```

Nutze `/tdd-red` — leite Tests aus der Analyse ab:
- **Root Cause** → Regressions-Test (Input der den Bug ausloest → korrektes Ergebnis)
- **Blast Radius** → Tests fuer betroffene Flows
- Fuer jeden Test: "Welche Zeile bricht diesen Test?" — wenn nicht beantwortbar, Test streichen

### Nach Implementation: 4 Verifikationen (ALLE PFLICHT)

**Annahme: Dein Fix ist falsch, Dead Code, oder nur auf einer Plattform.**

| # | Check | Annahme die widerlegt werden muss |
|---|-------|----------------------------------|
| 1 | `xcodebuild build` (BEIDE Plattformen) | Code kompiliert nicht |
| 2 | `xcodebuild test` ausfuehren | Tests laufen nicht durch |
| 3 | `Grep` nach neuer Funktion → mind. 1 Aufrufer | Neuer Code ist Dead Code |
| 4 | Beide Plattformen (iOS + macOS Views) geaendert? | Fix nur auf einer Plattform |

Wenn ein Check scheitert → Fix ueberarbeiten, NICHT committen.

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

### Ueberzeugtheits-Anti-Patterns (NEU)

| Was ich denke | Was ich stattdessen tun muss | Historisches Beispiel |
|--------------|------------------------------|----------------------|
| "Ich weiss die Ursache, Logging ist unnoetig" | Logging GERADE DANN einbauen — Ueberzeugung ist kein Beweis | Import-Button: War "offensichtlich" ein Code-Problem, war ein Default-Wert |
| "Der Fix ist offensichtlich richtig" | Call-Site pruefen — wird er aufgerufen? | Bug 57: 10 Tests gruen, 0 Aufrufe = Dead Code |
| "Das ist ein iOS-Bug" | BEIDE Plattformen pruefen | Feedback-Overlay: macOS hatte das UI-Element gar nicht |
| "Das Feature ist kaputt" | Existiert es ueberhaupt? | Suche: War nie implementiert, nur Spec existierte |
| "Ein Versuch noch, dann klappts" | Nach 2 Versuchen: Ansatz wechseln oder Henning fragen | Screenshot-Gate: 4 Workaround-Versuche statt 1x fragen |

### Eskalations-Regel

**Max 2 Versuche** fuer denselben Ansatz. Danach: Ansatz wechseln ODER Henning fragen.
NIEMALS 5+ Versuche am selben Problem ohne Fortschritt.

---

**Injizierte Standards:**
- `.agent-os/standards/global/analysis-first.md`
- `.agent-os/standards/global/scoping-limits.md`
