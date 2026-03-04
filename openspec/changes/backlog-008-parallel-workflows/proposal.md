# BACKLOG-008: Workflow-System — Echte Parallelitaet

**Modus:** AENDERUNG
**Status:** Geplant
**Prioritaet:** P2 (blockiert aktiv die Arbeit)
**Aufwand:** Klein (Phase 1 MVP)
**Kategorie:** Support Feature (internes Tooling)

---

## Problem (aktueller Zustand)

Das Workflow-System kennt nur EIN `active_workflow` gleichzeitig. Alle Hooks
(`strict_code_gate.py`, `tdd_enforcement.py`) fragen immer nur diesen einen ab.

**Konkrete Fehlerszenarien:**

1. **Override-Token landet beim falschen Workflow:** User schreibt "override" im
   Chat. `override_token_listener.py` erstellt den Token fuer `active_workflow`.
   Wenn die editierte Datei zu einem anderen Workflow gehoert, verweigert der
   Guard den Zugriff — oder genehmigt den falschen Workflow.

2. **`complete_workflow()` setzt zufaelligen Naechsten:** Nach Abschluss eines
   Workflows sucht die Funktion `remaining[0]` aus allen nicht-abgeschlossenen
   Workflows. Bei 100+ Eintraegen im State ist das ein beliebiger alter Eintrag,
   nicht der gerade aktive Task.

3. **Kein echter Parallelbetrieb:** Zwei Bugs gleichzeitig bearbeiten ist nicht
   moeglich, da Hooks immer nur den active_workflow kennen.

---

## Gewuenschtes Verhalten (Delta)

### Primaere Aenderung: File-basierte Workflow-Zuweisung

Statt `get_active_workflow()` soll eine neue Funktion `find_workflow_for_file(file_path)`
den zustaendigen Workflow anhand der `affected_files` ermitteln.

Ablauf:
1. Alle Workflows in `phase6_implement`, `phase7_validate` oder `phase8_complete`
   durchsuchen
2. Welcher hat die editierte Datei in `affected_files`?
3. Genau einer gefunden → diesen verwenden
4. Keiner gefunden → Fallback auf `active_workflow` (Legacy-Kompatibilitaet)
5. Mehrere gefunden → zuletzt geupdateter Workflow gewinnt

### Sekundaere Aenderung: `complete_workflow()` Fix

Nach Abschluss KEIN automatisches Wechseln auf irgendeinen anderen Workflow.
`active_workflow` bleibt auf dem gerade abgeschlossenen oder wird auf `None`
gesetzt — aber nie auf einen zufaelligen Eintrag.

### Override-Token: Expliziter Workflow-Name

`override_token_listener.py` soll `"override [workflow-name]"` unterstuetzen.
Wenn kein Name angegeben: Fallback auf active_workflow (bestehend).

---

## Betroffene Dateien (Phase 1 MVP)

| Datei | Aenderungstyp | Geschaetzte LoC |
|-------|---------------|-----------------|
| `.claude/hooks/workflow_state_multi.py` | Neue Funktion + complete_workflow fix | +30 |
| `.claude/hooks/strict_code_gate.py` | File-basierte Suche als primaerer Pfad | ~25 geaendert |
| `.claude/hooks/tdd_enforcement.py` | Gleiches Muster wie Code-Gate | ~15 geaendert |
| `.claude/hooks/override_token_listener.py` | Optionaler Workflow-Name | +20 |

**Gesamt: 4 Dateien, ~90 LoC**

---

## Was NICHT in Phase 1 (spaeter)

- `active_workflow` vollstaendig entfernen
- CLI-Befehle auf explizite Workflow-Namen umstellen
- Workflow-Auswahl-Interface

---

## Seiteneffekte

- Workflows mit leerem `affected_files` (viele alte Eintraege) treffen keinen
  Treffer → Fallback auf active_workflow greift → unveraendertes Verhalten
- `complete_workflow()` Fix: keine Breaking Changes, nur defensiveres Verhalten
- Override-Token: Rueckwaertskompatibel (altes "override" ohne Namen funktioniert weiter)

---

## Nicht betroffene Systeme

- `override_token_guard.py` — unveraendert
- `override_token_bash_guard.py` — unveraendert
- Alle anderen Hooks (spec_enforcement, scope_guard, etc.) — unveraendert
- App-Code (Sources/, FocusBloxMac/) — unveraendert, nur Tooling
