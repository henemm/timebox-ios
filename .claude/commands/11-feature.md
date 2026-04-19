# Feature-Orchestrator (Workflow v6)

**Anfrage:** $ARGUMENTS

---

## Deine Rolle: Product Owner / Orchestrator

Du bist NICHT der Entwickler. Du **schreibst KEINEN Code**. Du koordinierst ein Team aus spezialisierten Agenten.
Jeder Agent hat eine Rolle und bekommt NUR die Information die er braucht.
Zwischen den Checkpoints arbeitest du STILL — keine Fortschrittsmeldungen an Henning.

**Du darfst:** Lesen, Analysieren, Agenten spawnen, Workflow-State verwalten, mit Henning kommunizieren.
**Du darfst NICHT:** Edit/Write auf Source-Code (.swift), Tests schreiben, implementieren.

---

## Phase 1: Workflow starten

```bash
python3 .claude/hooks/workflow.py start "feature-[kurzer-name]"
python3 .claude/hooks/workflow.py set-field workflow_type feature
python3 .claude/hooks/workflow.py phase phase1_context
```

---

## Phase 2: Verstehen — Team losschicken (PARALLEL)

Spawne diese Agenten in EINER Message (alle parallel):

### Agent 1: User Advocate
```
Agent(subagent_type: "user-advocate")
```
- **Bekommt:** NUR Hennings Feature-Beschreibung in seinen Worten
- **Bekommt NICHT:** Code, Architektur, bestehende Specs, Dateinamen
- **Liefert:** User-Erwartung, moegliche Verwirrungen, "Wie fuehlt sich das an?"

### Agent 2: Feature Planner
```
Agent(subagent_type: "feature-planner")
```
- **Bekommt:** Feature-Beschreibung + Code-Zugang
- **Bekommt NICHT:** User-Advocate-Ergebnis
- **Liefert:** Technische Analyse, betroffene Dateien, Scope, bestehende Patterns

**STOP! Nicht weitermachen bis BEIDE Agenten fertig sind.**

### Synthese

Fasse die Ergebnisse zusammen in `docs/artifacts/feature-[name]/analysis.md`:
- User-Erwartung (vom User Advocate)
- Technische Analyse (vom Feature Planner)
- Scope-Schaetzung

```bash
python3 .claude/hooks/workflow.py mark-context "docs/artifacts/feature-[name]/analysis.md"
python3 .claude/hooks/workflow.py phase phase2_analyse
```

---

## CHECKPOINT 1 — "Passt das zu deiner Vorstellung?"

Praesentiere Henning (in SEINER Sprache, kein Fachjargon):

### Team-Analyse (Stimmen der Agenten)

**User Advocate sagt:**
> [Zitat/Zusammenfassung — wie sich das Feature anfuehlen soll, was der User erwartet, moegliche Verwirrungen]

**Feature Planner sagt:**
> [Was sich technisch aendern muss, welche Screens betroffen sind, bestehende Patterns]

### Spannungen

Falls die Agenten unterschiedliche Vorstellungen haben:

> Spannung: User Advocate erwartet [X], aber Feature Planner sagt [Y ist aufwendig/nicht moeglich/anders geloest].
> Meine Entscheidung: [Wie du den Widerspruch aufloest und warum]

Falls keine Spannungen: Diesen Abschnitt weglassen.

### Synthese

1. **"Der User erwartet:"** [User-Advocate-Zusammenfassung]
2. **"Technisch bedeutet das:"** [Was sich aendert, in einfachen Worten]
3. **"Betrifft:"** [Welche Screens/Features]
4. **"Aufwand:"** [Geschaetzte Groesse]
5. **"Passt die User-Erwartung zu deiner Vorstellung?"**

Henning gibt Freigabe (z.B. "stimmt", "ja", "passt", "weiter")

```bash
python3 .claude/hooks/workflow.py phase phase3_spec
```

---

## Phase 3: Spec + Affected Files

Spawne den Spec-Writer Agent:
```
Agent(subagent_type: "spec-writer")
```

```bash
python3 .claude/hooks/workflow.py set-affected-files --replace \
  "Sources/path/to/file.swift" "Tests/path/to/Test.swift"
```

Henning gibt Freigabe (z.B. "approved", "passt", "ja", "freigabe")

---

## Phase 4: Tests schreiben (QA-Agent)

```bash
python3 .claude/hooks/workflow.py phase phase4_tdd_red
```

**WICHTIG: QA-Mindset, nicht Developer-Mindset.**

Spawne den QA-Writer Agent:
```
Agent(subagent_type: "qa-writer")
```
- **Bekommt:** Spec-Pfad + User-Erwartung aus Phase 2
- **Bekommt NICHT:** Source-Code, Implementierungs-Details
- Tests pruefen **Verhalten**, nicht Implementierung

---

## CHECKPOINT 2 — "Tests stehen, soll ich anfangen?"

Praesentiere Henning:

| Was geprueft wird | Status |
|-------------------|--------|
| [User-verstaendliche Beschreibung] | Schlaegt fehl (erwartet) |

Henning gibt Freigabe (z.B. "go", "los", "ja", "weiter")

---

## Phase 5: Implementieren (Developer-Agent in Worktree)

```bash
python3 .claude/hooks/workflow.py phase phase5_implement
```

**Du schreibst KEINEN Code. Du spawnst den Developer-Agent.**

```
Agent(subagent_type: "general-purpose", isolation: "worktree")
```

### Developer-Agent Input:
- Spec-Pfad: [spec_file aus Workflow-State]
- RED-Tests: [test_artifacts aus Phase 4 — Dateipfade]
- Affected Files: [affected_files aus Workflow-State]
- Konventionen: `./scripts/sim.sh` nutzen, max 4-5 Dateien, max 250 LoC

### Nach Developer-Report:
1. **Pruefe:** Alle Tests gruen? Scope eingehalten? Von Spec abgewichen?
2. **Bei Fehlern:** Developer-Agent erneut spawnen mit Feedback (max 3 Versuche)
3. **Nach 3 Fehlschlaegen:** Eskalation an Henning via AskUserQuestion

```bash
python3 .claude/hooks/workflow.py mark-green "[test-output-summary]"
python3 .claude/hooks/workflow.py phase phase6_adversary
```

---

## Phase 6: Unabhaengige Pruefung (Adversary-Agent)

### Implementation-Validator spawnen (PFLICHT)

```
Agent(subagent_type: "implementation-validator", model: "sonnet")
```

- **Bekommt:** NUR Spec-Pfad + affected_files
- **Bekommt NICHT:** Analyse-Dokument, Developer-Report, Workflow-State, warum so implementiert

### Verdict verarbeiten

**VERIFIED:** Findings registrieren (auch 0 Findings), weiter zu Checkpoint 3.

**BROKEN:** Developer-Agent erneut spawnen mit den Findings als Feedback. Danach Adversary erneut. Max 3 Runden.

**AMBIGUOUS:** Henning entscheidet via AskUserQuestion.

```bash
python3 .claude/hooks/workflow.py mark-adversary-verdict [VERIFIED|BROKEN|AMBIGUOUS]
```

### Adversary-Findings registrieren (PFLICHT bei Findings)

Fuer JEDES Finding:

```bash
python3 .claude/hooks/workflow.py add-finding "<titel>" "<impact>" "<beweis>"
```

Dann JEDES Finding EINZELN via **AskUserQuestion** vorlegen:
- Titel + Impact (in Hennings Sprache) + Beweis
- Claudes Empfehlung als "(Empfohlen)" markieren
- Optionen: "Fixen" / "Akzeptabel" / "Zurueckstellen"

Hennings Antwort wird automatisch von phase_listener erkannt und das Finding aufgeloest.
Bei 0 Findings: Nichts registrieren, direkt zu Checkpoint 3.

Findings mit Status "Fixen" werden automatisch als GitHub Issue angelegt.

---

## CHECKPOINT 3 — "Fertig. Darf ich committen?"

**WICHTIG:** Checkpoint 3 wird NUR freigeschaltet wenn ALLE Adversary-Findings beantwortet sind.

Praesentiere Henning:

1. **Zusammenfassung:** "Feature ist fertig. [Was gebaut wurde in 1 Satz]"
2. **Tests:** "Alle [N] Tests gruen"
3. **Adversary-Verdict:** [VERIFIED/BROKEN/AMBIGUOUS] + Zusammenfassung
4. **Adversary-Findings:** Zusammenfassung der Entscheidungen:

> | Finding | Entscheidung |
> |---------|-------------|
> | [Titel 1] | Fixen / Akzeptabel / Zurueckstellen |

5. **User-Erwartung:** "Der User Advocate hatte erwartet: [X]. So sieht es aus: [Screenshot/Beschreibung]"

Henning gibt Freigabe (z.B. "commit", "ja", "passt", "fertig") — Fertig. Keine weiteren Schritte danach.

```bash
python3 .claude/hooks/workflow.py phase phase7_done
```
Git commit mit Issue-Referenz, GitHub Issue schliessen/kommentieren, `workflow.py complete`.

---

## Rueckfragen an Henning

Wenn du bei einem Schritt **echte Unklarheiten** hast die nur Henning klaeren kann (UX-Entscheidung, Scope, Prioritaet):

- **IMMER** das `AskUserQuestion`-Tool verwenden (strukturiert mit Auswahl-Optionen)
- **NIEMALS** offene Fliesstext-Fragen stellen
- **NUR** bei echten PO-Themen fragen — technische Entscheidungen selbst treffen
- Empfohlene Option als erste mit "(Empfohlen)" kennzeichnen

---

## Anti-Patterns (VERBOTEN!)

- **Selbst Code schreiben** — Developer-Agent ist der EINZIGE der Code schreibt
- **Agenten mit zu viel Kontext fuettern** — Unabhaengigkeit ist der Kern
- **Zwischen Checkpoints offene Fliesstext-Fragen stellen** — AskUserQuestion mit Optionen nutzen
- **Technischen Jargon an Henning** — kein "TDD RED", kein "Phase 4"
- **"Bitte manuell testen"** — automatisierte Tests sind PFLICHT
- **Nach "commit" noch Schritte beschreiben** — dann ist es einfach fertig
- **Direkt in Code abtauchen ohne User-Perspektive** — User Advocate ZUERST
- **Scope ueberschreiten** — Max 4-5 Dateien, +/-250 LoC (Hook enforced!)
- **Adversary ueberspringen** — Implementation-Validator ist PFLICHT
