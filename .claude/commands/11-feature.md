# Feature planen oder aendern

Starte den `feature-planner` Agenten aus `.agent-os/agents/feature-planner.md`.

**Anfrage:** $ARGUMENTS

---

## Modus erkennen

| Formulierung | Modus |
|--------------|-------|
| "Neues Feature...", "Fuege hinzu...", "Implementiere..." | **NEU** |
| "Aenderung an...", "Passe an...", "Erweitere...", "Modifiziere..." | **AENDERUNG** |

---

**Befolge den Workflow aus `.agent-os/workflows/feature-workflow.md`**

**Injizierte Standards:**
- `.agent-os/standards/global/analysis-first.md`
- `.agent-os/standards/global/scoping-limits.md`
- `.agent-os/standards/global/documentation-rules.md`
- `.agent-os/standards/swiftui/state-management.md`

---

## ⛔ ZWINGENDE CHECKPOINTS

Der Feature-Workflow hat **BLOCKING Checkpoints**. Diese MUESSEN erfuellt sein:

| Checkpoint | Wann | Hook/Gate | Blockiert |
|------------|------|-----------|-----------|
| ⛔ User-Erwartung | VOR technischer Analyse | `feature_understanding_gate.py` | Alle Task-Agents |
| ⛔ Tests definieren | VOR Implementierung | `tdd_enforcement.py` | Code-Edits |
| ⛔ Fresh-Eyes Inspektion | NACH Implementierung | `result_inspection_done` | Adversary |
| ⛔ Adversary | NACH Fresh-Eyes | `adversary_gate.py` | Validate-Phase |
| ⛔ Unit + UI Tests | NACH Adversary | `workflow_gate.py` | Commit |

---

## Anweisung

### Schritt 0: User-Perspektive ZUERST — Was soll der User erleben?

**PFLICHT VOR ALLEM ANDEREN!**

Bevor du auch nur eine Zeile Code liest oder Architektur-Entscheidungen triffst:

**1. User-Advocate Agent starten — NUR mit Feature-Beschreibung:**
```
Task: user-advocate Agent
Input: NUR Hennings Feature-Beschreibung in seinen eigenen Worten
KEIN Code-Kontext! KEINE Architektur! KEINE bestehenden Specs!
```

Der Agent denkt ausschliesslich aus User-Perspektive:
- Was erwarte ich als User zu sehen?
- Wie fuehlt sich die Interaktion an?
- Was wuerde mich verwirren?
- Woran merke ich dass es funktioniert hat?

**2. User-Erwartung als Massstab festhalten:**
```bash
python3 .claude/hooks/workflow_state_multi.py set-field user_expectation_notes "Zusammenfassung der User-Erwartung"
python3 .claude/hooks/workflow_state_multi.py set-field user_expectation_done true
```

**OHNE `user_expectation_done=true` werden alle technischen Agents BLOCKIERT!**

**3. Henning die User-Erwartung zeigen:**
- "So stellt sich der User-Advocate das Feature vor: [Zusammenfassung]"
- "Passt das zu deiner Vorstellung?"
- Erst nach Bestätigung → weiter zur technischen Analyse

> Warum? Weil Claude sonst direkt in Code abtaucht und ein Feature baut das
> technisch funktioniert aber an der User-Erwartung vorbeigeht.

---

### Danach: Technische Planung

1. **Modus bestimmen:** NEU oder AENDERUNG?
2. Feature-Intent verstehen (WAS, WARUM, Kategorie)
3. **Bei AENDERUNG:** Aktuellen Zustand dokumentieren, Delta identifizieren
4. Bestehende Systeme pruefen (KRITISCH!)
5. Scoping (Max 4-5 Dateien, +/-250 LoC)
6. ⛔ **Affected Files registrieren** (PFLICHT — Code Gate blockiert sonst!):
   ```bash
   python3 .claude/hooks/workflow_state_multi.py set-affected-files --replace \
     "Sources/path/to/file.swift" "Tests/path/to/Test.swift"
   ```
7. ⛔ **ERST Tests definieren** in `openspec/changes/[feature-name]/tests.md`
8. Dokumentiere in DOCS/ACTIVE-roadmap.md
9. **NEU:** Erstelle OpenSpec Proposal in `openspec/changes/[feature-name]/`
10. **AENDERUNG:** Aktualisiere bestehende Spec in `openspec/specs/`
11. Implementieren

---

### Nach Implementation: Ergebnis-Inspektion

**PFLICHT NACH JEDER FEATURE-IMPLEMENTIERUNG!**

**1. Screenshot des Ergebnisses machen:**
```bash
xcrun simctl io booted screenshot /tmp/feature_result.png
```

**2. Fresh-Eyes Agent losschicken — OHNE Feature-Kontext:**
```
Task: fresh-eyes-inspector Agent
Input: NUR den Screenshot-Pfad (/tmp/feature_result.png)
KEIN Feature-Name! KEINE Spec! NICHT was gebaut werden sollte!
```

**3. Abgleich mit User-Erwartung:**
- Was hat der Fresh-Eyes Agent gesehen?
- Was hatte der User-Advocate sich vorgestellt?
- **Passt das zusammen?**

| Ergebnis | Aktion |
|----------|--------|
| Fresh-Eyes sieht was User-Advocate erwartet hat | Weiter zu Tests |
| Fresh-Eyes sieht etwas anderes | STOP — was stimmt nicht? |
| Fresh-Eyes findet UX-Probleme | STOP — nachbessern |

```bash
python3 .claude/hooks/workflow_state_multi.py set-field result_inspection_notes "Fresh-Eyes: [Was gesehen]. Abgleich mit Erwartung: [Vergleich]"
python3 .claude/hooks/workflow_state_multi.py set-field result_inspection_done true
```

---

### Nach Fresh-Eyes: Adversary — Beweisen dass es kaputt ist

**PFLICHT! Gilt fuer Features genauso wie fuer Bugs.**

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase6b_adversary
```

**1. Implementation-Validator Agent starten:**
```
Task: implementation-validator Agent
Input: Spec-Pfad des aktuellen Workflows
Der Agent liest NUR die Spec (nicht den Code!) und versucht zu beweisen
dass das Feature NICHT funktioniert.
```

Der Agent:
- Liest die Spec (was wurde versprochen?)
- Fuehrt ALLE Tests aus (Unit + UI)
- Macht Screenshots
- Sucht Edge Cases
- Ruft `adversary_gate.py` auf mit Beweis

**2. Ergebnis:**

| Verdict | Aktion |
|---------|--------|
| BROKEN — Agent hat Fehler gefunden | STOP — fixen, DANN erneut validieren |
| HAELT — Agent konnte nichts kaputt machen | Weiter zu Validate |

**KEIN Commit ohne bestandene Adversary-Pruefung!**

Der `adversary_gate.py` setzt das Verdict im Workflow-State.
Ohne `VERIFIED` Verdict blockiert `workflow_gate.py` die Validation-Phase.

---

### Dann: Validate

12. ⛔ **Adversary bestanden** (siehe oben)
13. ⛔ **Alle Tests gruen** (Unit + UI)

```bash
python3 .claude/hooks/workflow_state_multi.py phase phase7_validate
```

**KEINE direkte Implementierung ohne User-Erwartung!**
