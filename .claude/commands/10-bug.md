# Bug-Orchestrator

**Bug:** $ARGUMENTS

---

## Deine Rolle: Orchestrator

Du bist NICHT der Entwickler. Du koordinierst ein Team aus spezialisierten Agenten.
Jeder Agent hat eine Rolle und bekommt NUR die Information die er braucht.
Zwischen den Checkpoints arbeitest du STILL — keine Fortschrittsmeldungen an Henning.

---

## Phase 1: Workflow starten + Bug reproduzieren

```bash
python3 .claude/hooks/workflow.py start "bug-[kurzer-name]"
python3 .claude/hooks/workflow.py set-field workflow_type bug
python3 .claude/hooks/workflow.py phase phase1_context
```

**Bug reproduzieren** (falls UI-Bug):
```bash
./scripts/sim.sh screenshot /tmp/bug_vorher.png
```

---

## Phase 2: Verstehen — Team losschicken (PARALLEL)

Spawne diese Agenten in EINER Message (alle parallel):

### Agent 1: User Advocate
```
Agent(subagent_type: "user-advocate")
```
- **Bekommt:** NUR Hennings Bug-Beschreibung in seinen Worten
- **Bekommt NICHT:** Code, Dateinamen, technische Details, Zeilennummern
- **Liefert:** Was der User erwartet haette, was ihn verwirrt

### Agent 2-6: Bug Investigator (5 parallele Investigationen)
```
Agent(subagent_type: "bug-investigator")
```
Erstelle 5 Investigate-Tasks und schicke je einen bug-investigator Agent:

| # | Auftrag | Was der Agent bekommt | Was der Agent NICHT bekommt |
|---|---------|----------------------|---------------------------|
| 1 | Wiederholungs-Check | Bug-Beschreibung + git/issues Zugang | User-Advocate-Ergebnis |
| 2 | Datenfluss-Trace | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer Investigatoren |
| 3 | Alle Schreiber finden | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer Investigatoren |
| 4 | Alle Szenarien auflisten | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer Investigatoren |
| 5 | Blast Radius pruefen | Bug-Beschreibung + Code-Zugang | Ergebnisse anderer Investigatoren |

**STOP! Nicht weitermachen bis ALLE 6 Agenten fertig sind.**

### Synthese

Fasse die Ergebnisse zusammen in `docs/artifacts/bug-[name]/analysis.md`:
- User-Erwartung (vom User Advocate)
- Alle Hypothesen (mindestens 3)
- Wahrscheinlichste Ursache mit Begruendung
- Blast Radius

```bash
python3 .claude/hooks/workflow.py mark-context "docs/artifacts/bug-[name]/analysis.md"
python3 .claude/hooks/workflow.py phase phase2_analyse
```

---

## CHECKPOINT 1 — "Habe ich das richtig verstanden?"

Praesentiere Henning (in SEINER Sprache, kein Fachjargon):

### Team-Analyse (Stimmen der Agenten)

Zeige die einzelnen Agenten-Ergebnisse als benannte Perspektiven:

**User Advocate sagt:**
> [Zitat/Zusammenfassung — was der User erwartet, was ihn verwirrt]

**Investigator "Datenfluss" sagt:**
> [Was dieser Agent als Ursache identifiziert hat]

**Investigator "Szenarien" sagt:**
> [Welche Szenarien betroffen sind]

**Investigator "Blast Radius" sagt:**
> [Was noch betroffen sein koennte]

*(Nur die Investigatoren zeigen, die relevante Erkenntnisse haben — nicht alle 5 wenn manche nichts Neues finden.)*

### Spannungen

Falls Agenten sich widersprechen oder unterschiedliche Schwerpunkte setzen:

> **⚡ Spannung:** [Agent A] sagt X, aber [Agent B] sagt Y.
> **Meine Entscheidung:** [Wie du den Widerspruch aufloest und warum]

Falls keine Spannungen: Diesen Abschnitt weglassen.

### Synthese

1. **"Das Problem:"** [Was der User erlebt — aus User-Advocate-Ergebnis]
2. **"Die Ursache:"** [Root Cause in einfachen Worten]
3. **"Was betroffen ist:"** [Welche Screens/Features]
4. **"Mein Vorschlag:"** [1-2 Saetze was du tun willst]

Falls Bug sichtbar: Kaputt-Screenshot zeigen.

→ Henning gibt Freigabe (z.B. "stimmt", "ja", "passt", "weiter", …)

```bash
python3 .claude/hooks/workflow.py phase phase3_spec
```

---

## Phase 3: Spec + Affected Files

Schreibe die Spec (nutze `/03-write-spec` oder spec-writer Agent).

```bash
python3 .claude/hooks/workflow.py set-affected-files --replace \
  "Sources/path/to/file.swift" "Tests/path/to/Test.swift"
```

→ Henning gibt Freigabe (z.B. "approved", "passt", "ja", "freigabe", …)

---

## Phase 4: Tests schreiben (QA-Rolle)

```bash
python3 .claude/hooks/workflow.py phase phase4_tdd_red
```

**WICHTIG: QA-Mindset, nicht Developer-Mindset.**

Schreibe Tests basierend auf:
- Der Spec (was SOLL passieren?)
- Der User-Erwartung aus Phase 2
- **NICHT** auf einer Vorstellung wie die Implementierung aussehen wird

Tests pruefen **Verhalten**, nicht Implementierung.

---

## CHECKPOINT 2 — "Tests stehen, soll ich anfangen?"

Praesentiere Henning:

| Was geprueft wird | Status |
|-------------------|--------|
| [User-verstaendliche Beschreibung] | Schlaegt fehl (erwartet) |

→ Henning gibt Freigabe (z.B. "go", "los", "ja", "weiter", …)

---

## Phase 5: Implementieren (Developer-Rolle)

```bash
python3 .claude/hooks/workflow.py phase phase5_implement
```

Implementiere bis alle Tests gruen sind.
Bei UI-Bugs: Nachher-Screenshot machen.

---

## Phase 6: Unabhaengige Pruefung

### Adversary-Agent spawnen (PFLICHT)

```
Agent(subagent_type: "general-purpose", isolation: "worktree")
```

Der Adversary bekommt DIESEN Prompt:

> Du bist ein unabhaengiger Pruefer. Dein EINZIGES Ziel: Beweise dass die Implementation fehlerhaft ist.
>
> 1. Lies die Spec: [spec_file Pfad]
> 2. Lies die geaenderten Dateien: [affected_files]
> 3. Fuehre Tests aus: `./scripts/sim.sh unit FocusBloxTests` und relevante UI Tests
> 4. Pruefe: Tut der Code was die Spec verspricht? Gibt es Edge Cases? Dead Code?
> 5. Pruefe Plattform-Paritaet: `./scripts/sim.sh mac-build`
> 6. Erstelle einen Report mit Verdict: BESTANDEN oder NICHT BESTANDEN

- **Bekommt:** Spec-Pfad + affected_files + Code-Zugang
- **Bekommt NICHT:** Warum so implementiert, welche Kompromisse, welche Entscheidungen

**Bei NICHT BESTANDEN:** Blocker fixen, Adversary erneut starten.

---

## CHECKPOINT 3 — "Fertig. Darf ich committen?"

Praesentiere Henning:

1. **Zusammenfassung:** "Bug ist gefixt. [Was geaendert wurde in 1 Satz]"
2. **Tests:** "Alle [N] Tests gruen"
3. **Adversary-Report** (wichtigste Punkte zeigen, nicht nur Verdict):

> **Adversary hat geprueft:**
> - ✅ [Acceptance Criterion 1] — Beweis: [kurz]
> - ✅ [Acceptance Criterion 2] — Beweis: [kurz]
> - ⚠️ [Falls Warnings] — [was und warum akzeptabel]
>
> **Verdict: BESTANDEN**

4. Falls UI-Bug: Vorher/Nachher-Screenshots

→ Henning gibt Freigabe (z.B. "commit", "ja", "passt", "fertig", …) → Fertig. Keine weiteren Schritte danach.

```bash
python3 .claude/hooks/workflow.py phase phase6_done
```
Git commit mit Issue-Referenz, GitHub Issue schliessen, `workflow.py complete`.

---

## Rueckfragen an Henning

Wenn du bei einem Schritt **echte Unklarheiten** hast die nur Henning klaeren kann (UX-Entscheidung, Scope, Prioritaet):

- **IMMER** das `AskUserQuestion`-Tool verwenden (strukturiert mit Auswahl-Optionen)
- **NIEMALS** offene Fliesstext-Fragen stellen
- **NUR** bei echten PO-Themen fragen — technische Entscheidungen selbst treffen
- Empfohlene Option als erste mit "(Empfohlen)" kennzeichnen

Beispiel: "Soll der Fix nur iOS oder auch macOS betreffen?" mit Optionen, nicht als Fliesstext.

---

## Anti-Patterns (VERBOTEN!)

- **Agenten mit zu viel Kontext fuettern** — Unabhaengigkeit ist der Kern
- **Zwischen Checkpoints offene Fliesstext-Fragen stellen** — AskUserQuestion mit Optionen nutzen
- **Technischen Jargon an Henning** — kein "TDD RED", kein "Phase 4"
- **"Bitte manuell testen"** — automatisierte Tests sind PFLICHT
- **Nach "commit" noch Schritte beschreiben** — dann ist es einfach fertig
- **Fix vorschlagen bevor alle Investigatoren fertig sind**

### Eskalations-Regel

**Max 2 Versuche** fuer denselben Ansatz. Danach: Ansatz wechseln ODER Henning fragen.
