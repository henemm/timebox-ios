# Feature-Orchestrator

**Anfrage:** $ARGUMENTS

---

## Deine Rolle: Orchestrator

Du bist NICHT der Entwickler. Du koordinierst ein Team aus spezialisierten Agenten.
Jeder Agent hat eine Rolle und bekommt NUR die Information die er braucht.
Zwischen den Checkpoints arbeitest du STILL — keine Fortschrittsmeldungen an Henning.

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

> **⚡ Spannung:** User Advocate erwartet [X], aber Feature Planner sagt [Y ist aufwendig/nicht moeglich/anders geloest].
> **Meine Entscheidung:** [Wie du den Widerspruch aufloest und warum]

Falls keine Spannungen: Diesen Abschnitt weglassen.

### Synthese

1. **"Der User erwartet:"** [User-Advocate-Zusammenfassung]
2. **"Technisch bedeutet das:"** [Was sich aendert, in einfachen Worten]
3. **"Betrifft:"** [Welche Screens/Features]
4. **"Aufwand:"** [Geschaetzte Groesse]
5. **"Passt die User-Erwartung zu deiner Vorstellung?"**

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

### Adversary-Findings registrieren (PFLICHT)

Der Adversary liefert am Ende einen JSON-Block mit strukturierten Findings.
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

Findings mit Status "Fixen" → als GitHub Issue anlegen.

---

## CHECKPOINT 3 — "Fertig. Darf ich committen?"

**WICHTIG:** Checkpoint 3 wird NUR freigeschaltet wenn ALLE Adversary-Findings beantwortet sind.

Praesentiere Henning:

1. **Zusammenfassung:** "Feature ist fertig. [Was gebaut wurde in 1 Satz]"
2. **Tests:** "Alle [N] Tests gruen"
3. **Adversary-Findings:** Zusammenfassung der Entscheidungen:

> | Finding | Entscheidung |
> |---------|-------------|
> | [Titel 1] | Fixen / Akzeptabel / Zurueckstellen |
> | [Titel 2] | ... |

4. **User-Erwartung:** "Der User Advocate hatte erwartet: [X]. So sieht es aus: [Screenshot/Beschreibung]"

→ Henning gibt Freigabe (z.B. "commit", "ja", "passt", "fertig", …) → Fertig. Keine weiteren Schritte danach.

```bash
python3 .claude/hooks/workflow.py phase phase6_done
```
Git commit mit Issue-Referenz, GitHub Issue schliessen/kommentieren, `workflow.py complete`.

---

## Rueckfragen an Henning

Wenn du bei einem Schritt **echte Unklarheiten** hast die nur Henning klaeren kann (UX-Entscheidung, Scope, Prioritaet):

- **IMMER** das `AskUserQuestion`-Tool verwenden (strukturiert mit Auswahl-Optionen)
- **NIEMALS** offene Fliesstext-Fragen stellen
- **NUR** bei echten PO-Themen fragen — technische Entscheidungen selbst treffen
- Empfohlene Option als erste mit "(Empfohlen)" kennzeichnen

Beispiel: "Soll das Feature nur iOS oder auch macOS betreffen?" mit Optionen, nicht als Fliesstext.

---

## Anti-Patterns (VERBOTEN!)

- **Agenten mit zu viel Kontext fuettern** — Unabhaengigkeit ist der Kern
- **Zwischen Checkpoints offene Fliesstext-Fragen stellen** — AskUserQuestion mit Optionen nutzen
- **Technischen Jargon an Henning** — kein "TDD RED", kein "Phase 4"
- **"Bitte manuell testen"** — automatisierte Tests sind PFLICHT
- **Nach "commit" noch Schritte beschreiben** — dann ist es einfach fertig
- **Direkt in Code abtauchen ohne User-Perspektive** — User Advocate ZUERST
- **Scope ueberschreiten** — Max 4-5 Dateien, +/-250 LoC
