# Feature planen oder aendern

**Anfrage:** $ARGUMENTS

---

## Modus erkennen

| Formulierung | Modus |
|--------------|-------|
| "Neues Feature...", "Fuege hinzu...", "Implementiere..." | **NEU** |
| "Aenderung an...", "Passe an...", "Erweitere..." | **AENDERUNG** |

---

## Schritt 0: Workflow starten

```bash
python3 .claude/hooks/workflow.py start "feature-[kurzer-name]"
python3 .claude/hooks/workflow.py set-field workflow_type feature
python3 .claude/hooks/workflow.py phase phase1_context
```

## Schritt 1: User-Perspektive ZUERST — Was soll der User erleben?

**BEVOR du auch nur eine Zeile Code liest:**

**1. User-Advocate Agent starten — NUR mit Feature-Beschreibung:**
```
Agent: user-advocate
Input: NUR Hennings Feature-Beschreibung in seinen eigenen Worten
KEIN Code-Kontext! KEINE Architektur! KEINE bestehenden Specs!
```

Der Agent denkt ausschliesslich aus User-Perspektive:
- Was erwarte ich als User zu sehen?
- Wie fuehlt sich die Interaktion an?
- Was wuerde mich verwirren?
- Woran merke ich dass es funktioniert hat?

**2. User-Erwartung festhalten** (fuer Checkpoint 1)

## Schritt 2: Technische Analyse

1. **Modus bestimmen:** NEU oder AENDERUNG?
2. **Bei AENDERUNG:** Aktuellen Zustand dokumentieren, Delta identifizieren
3. Betroffene Dateien identifizieren
4. Bestehende Systeme/Patterns pruefen
5. Scoping (Max 4-5 Dateien, +/-250 LoC)

## Schritt 3: **CHECKPOINT 1** — Henning die Analyse praesentieren

**Zeige Henning:**
1. **User-Erwartung** (vom user-advocate): "So stellt sich der User das Feature vor: [...]"
2. Was das Feature technisch tun soll (User-Sprache)
3. Betroffene Stellen (welche Screens/Views)
4. Vorgeschlagener Ansatz (1-2 Saetze)
5. Scope-Schaetzung (Dateien, LoC)
6. Frage: "Passt die User-Erwartung zu deiner Vorstellung?"

**Henning sagt "stimmt" → Checkpoint 1 freigeschaltet.**

```bash
python3 .claude/hooks/workflow.py phase phase3_spec
```

## Schritt 4: Spec schreiben + Approval

Nutze `/03-write-spec`.

```bash
python3 .claude/hooks/workflow.py set-affected-files --replace \
  "Sources/path/to/file.swift" "Tests/path/to/Test.swift"
```

**Henning sagt "approved" → Spec freigeschaltet.**

## Schritt 5: TDD RED

```bash
python3 .claude/hooks/workflow.py phase phase4_tdd_red
```

Nutze `/04-tdd-red`.

## Schritt 5.5: **CHECKPOINT 2** — Henning die Tests praesentieren

**Zeige Henning:**
| Test | Was er prueft | Status |
|------|--------------|--------|
| testFeatureX | Prueft ob X sichtbar ist nach Y | FAILED ✓ |

**Henning sagt "go" → Checkpoint 2 freigeschaltet.**

## Schritt 6: Implementation

```bash
python3 .claude/hooks/workflow.py phase phase5_implement
```

Nutze `/05-implement`.

## Schritt 7: **CHECKPOINT 3** — Henning das Ergebnis praesentieren

**Zeige Henning:**
1. ALL GREEN Test-Output
2. Screenshot des fertigen Features
3. Vergleich mit User-Erwartung aus Schritt 1: "Der user-advocate hatte erwartet: [...]. So sieht es aus: [Screenshot]"
4. Kurze Zusammenfassung was sich geaendert hat

**Optional:** Henning kann jetzt `/adversary` in einer zweiten Claude-Session starten.

**Henning sagt "commit" → Checkpoint 3 freigeschaltet.**

## Schritt 8: Commit + Dokumentation

```bash
python3 .claude/hooks/workflow.py phase phase6_done
```

- Git commit mit Issue-Referenz
- GitHub Issue schliessen/kommentieren
- `python3 .claude/hooks/workflow.py complete`

---

## Anti-Patterns

- **Direkt in Code abtauchen ohne User-Perspektive** — user-advocate ZUERST
- **"Bitte manuell testen"** — UI Tests sind PFLICHT
- **Scope ueberschreiten** — Max 4-5 Dateien
- **User-Erwartung ignorieren** — bei Checkpoint 3 mit Ergebnis vergleichen
