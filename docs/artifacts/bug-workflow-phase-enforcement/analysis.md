# Bug-Analyse: Workflow-Phasen werden übersprungen

**Datum:** 2026-04-02
**Symptom:** Claude überspringt in Sessions 3 kritische Phasen: UI Tests, Adversary, Docs-Updater

---

## 1. Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check)
- **18 Monate** Workflow-Enforcement-Geschichte mit zyklischem Muster: Gate bauen → Lücke finden → Quick-Fix → Audit → Konsolidierung
- Bisherige kritische Fixes: Override-Token-Leak (#186), affected_files Bypass, Session-Isolation, Statusline (5 Versuche)
- **Kernproblem:** Gates prüfen Feld-Existenz, nicht ob echte Arbeit dahinter steckt

### Agent 2 (Datenfluss-Trace)
- **UI Tests:** `ui_test_red_done` wird nur durch `mark-ui-red` gesetzt. `mark-ui-green` **existiert nicht**
- **Adversary:** `adversary_verdict` kann direkt via `set-field` gesetzt werden — keine Validierung
- **Docs-Updater:** **Kein Feld, kein Setter, kein Checker, kein Gate** — komplett nicht implementiert

### Agent 3 (Alle Schreiber)
- `set-field` akzeptiert **jeden beliebigen Wert** für **jeden beliebigen Schlüssel** — keine Whitelist, keine Validierung
- Alle Gate-Felder (adversary_verdict, green_approved, ui_test_red_done, etc.) können manuell gefälscht werden
- qa_gate.py validiert Test-Output schwach (nur 2/4 Patterns, 100 Bytes Minimum)

### Agent 4 (Bypass-Szenarien)
- **9 konkrete Bypass-Vektoren** identifiziert
- Kritischster: `set-field adversary_verdict "VERIFIED:fake"` + `git commit` → kein Gate blockiert
- Phase-Rückwärts-Sprünge sind unbeschränkt → phase6b_adversary kann übersprungen werden
- `mark-green`, `mark-regression-done`, `mark-docs-updated`, `mark-validation-done` → **Commands existieren nicht in workflow.py**, werden aber in 06-validate.md referenziert

### Agent 5 (Blast Radius)
- **4 fehlende Commands** in workflow.py (mark-green, mark-regression-done, mark-docs-updated, mark-validation-done)
- **Alle Phase-Gates** haben dasselbe Schwäche-Pattern: Prüfen nur Feld-Existenz via `set-field`
- `tdd_enforcement.py` Source-Datei fehlt (nur .pyc im Cache)
- Nur 1 Gate ist robust: phase5→phase6 (prüft echte test_artifacts)

---

## 2. ALLE möglichen Ursachen

### Hypothese A: `set-field` hat keine Whitelist (HOCH)
- **Beweis dafür:** workflow.py:485 — `data[key] = value` ohne jede Validierung. Jedes Feld kann beliebig gesetzt werden.
- **Beweis dagegen:** Keiner. Reproduzierbar mit `set-field adversary_verdict "VERIFIED:fake"`.
- **Wahrscheinlichkeit:** HOCH — Kern-Enabler für alle 3 gemeldeten Probleme

### Hypothese B: Fehlende Commands (mark-green, mark-docs-updated, etc.) (HOCH)
- **Beweis dafür:** 06-validate.md referenziert 4 Commands die nicht in workflow.py existieren. COMMANDS-Dict (Zeile 635-648) hat kein `mark-green`, `mark-regression-done`, `mark-docs-updated`, `mark-validation-done`.
- **Beweis dagegen:** Keiner.
- **Wahrscheinlichkeit:** HOCH — Ohne Commands gibt es keinen strukturierten Weg, diese Phasen zu dokumentieren

### Hypothese C: Phase6b (Adversary) ist kein Pflicht-Zwischenstopp (HOCH)
- **Beweis dafür:** _validate_transition() hat kein Gate das erzwingt, dass man phase6b_adversary durchlaufen MUSS bevor man zu phase7_validate kommt. Man kann von phase6_implement direkt zu phase7_validate springen.
- **Beweis dagegen:** Für Features prüft das Gate `result_inspection_done` (Zeile 381-385). Aber für Bugs: kein Gate.
- **Wahrscheinlichkeit:** HOCH — Strukturelle Lücke in der Phase-Reihenfolge

### Hypothese D: Commit-Gate prüft nur adversary_verdict (MITTEL)
- **Beweis dafür:** bash_gate.py:362-367 prüft NUR `adversary_verdict`. Nicht: `green_approved`, `ui_test_red_done`, Phase == phase8_complete.
- **Beweis dagegen:** Adversary-Verdict ist das "End-Gate" — wenn es echt wäre, würden die anderen Checks implizit erfüllt sein.
- **Wahrscheinlichkeit:** MITTEL — Ist ein Symptom von Hypothese A (set-field Bypass)

### Hypothese E: Kein Enforcement für Docs-Update (MITTEL)
- **Beweis dafür:** Kein Feld `docs_updated` in _new_workflow(). Kein Gate. docs/ ist in ALWAYS_ALLOWED_DIRS.
- **Beweis dagegen:** Docs-Updates sind nicht bei jedem Bug/Feature nötig.
- **Wahrscheinlichkeit:** MITTEL — Korrekter Fund, aber niedrigere Priorität als A-C

---

## 3. Wahrscheinlichste Ursache(n)

**Kern-Ursache: Hypothese A + B + C zusammen**

Das Problem hat 3 Schichten:
1. **`set-field` ohne Whitelist** (A) → ermöglicht das Fälschen aller Gate-Felder
2. **Fehlende Commands** (B) → es gibt keinen korrekten Weg, UI-GREEN/Docs/Regression zu markieren
3. **Phase6b nicht erzwungen** (C) → Adversary kann übersprungen werden ohne set-field-Trick

**Warum die anderen weniger wahrscheinlich sind:**
- D (Commit-Gate) ist ein Symptom von A — wenn set-field gefixt wird, reicht adversary_verdict als Commit-Gate
- E (Docs) ist real aber niedrigere Priorität — kein Bug-Stopper

---

## 4. Debugging-Plan

### Zum BESTÄTIGEN von Hypothese A:
```bash
python3 .claude/hooks/workflow.py set-field adversary_verdict "VERIFIED:test-bypass"
# Erwartung: Wird akzeptiert ohne Fehlermeldung → Hypothese bestätigt
```

### Zum WIDERLEGEN von Hypothese A:
```bash
# Wenn set-field eine Fehlermeldung gibt → Hypothese widerlegt
# (Aber Code-Analyse zeigt klar: keine Validierung vorhanden)
```

### Zum BESTÄTIGEN von Hypothese B:
```bash
python3 .claude/hooks/workflow.py mark-green "test"
# Erwartung: "Unknown command: mark-green" → Hypothese bestätigt
```

### Zum BESTÄTIGEN von Hypothese C:
```bash
# In einem Workflow in phase6_implement:
python3 .claude/hooks/workflow.py phase phase7_validate
# Erwartung: Phase-Wechsel erlaubt (phase6b übersprungen) → Hypothese bestätigt
```

---

## 5. Blast Radius

### Direkt betroffen:
- **Jeder Bug-Fix und jedes Feature** das durch den Workflow geht
- Alle 3 gemeldeten Phasen (UI Tests, Adversary, Docs)

### Gleiche Lücke betrifft auch:
- `context_file` — kann gefälscht werden
- `visual_inspection_done` — kann gefälscht werden
- `analysis_file` / `analysis_findings` — können gefälscht werden
- `challenge_verdict` — kann gefälscht werden ("SOLIDE" Prefix reicht)
- `spec_approved` — kann gefälscht werden
- `fix_proposal_approved` — kann gefälscht werden
- `green_approved` — kann gefälscht werden

### Robustes Gate (Vorbild):
- **phase5→phase6:** Prüft echte `test_artifacts[]` mit Phase-Tag — kann nicht einfach mit set-field gefälscht werden

---

## 6. Fix-Empfehlung (Zusammenfassung)

**3 Maßnahmen, priorisiert:**

1. **PROTECTED_FIELDS in set-field** — Liste von Feldern die NUR durch dedizierte Commands gesetzt werden dürfen (adversary_verdict, green_approved, ui_test_red_done, etc.)
2. **Fehlende Commands implementieren** — mark-green, mark-ui-green, mark-regression-done, mark-docs-updated, mark-validation-done
3. **Phase6b als Pflicht-Zwischenstopp** — _validate_transition() muss für phase7_validate prüfen dass phase6b_adversary durchlaufen wurde
