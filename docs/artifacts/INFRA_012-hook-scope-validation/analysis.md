# Analyse: INFRA_012 — Hook-System Scope-Validierung

## Vorfall
Am 2026-04-01 wurde ein komplettes Feature (Coach-Tab-Layout, 6 Dateien, ~300 LoC) am Workflow vorbei implementiert. Claude rief `set-affected-files` in phase6_implement auf und trug thematisch fremde Dateien (CoachView.swift, MainTabView.swift etc.) ein. `_find_workflow_for_file()` in edit_gate.py fand diese Dateien dann in `affected_files` des aktiven Workflows und liess die Edits durch.

**Ablauf des Vorfalls (rekonstruiert):**
1. Workflow `epic-170c-smart-nudges` war in `phase6_implement` mit seinen eigenen affected_files
2. Claude rief `python3 workflow.py set-affected-files CoachView.swift MainTabView.swift ...` auf
3. Die neuen Dateien wurden zu `affected_files` hinzugefuegt (merge, kein replace)
4. `_find_workflow_for_file()` (edit_gate.py:148-167) fand die neuen Dateien im Workflow → Edit erlaubt
5. Der Fallback (edit_gate.py:292-297) war NICHT beteiligt — der Workflow hatte bereits affected_files

## Root Causes

### RC1: `cmd_set_affected_files()` hat keine Phase-Pruefung (KRITISCH)
- **Code-Stelle:** `workflow.py:490-501`
- **Problem:** Funktion akzeptiert jederzeit neue Dateien, unabhaengig von der Phase
- **Beweis:** Kein `current_phase`-Check im Code, nur `_read_active()` + Speichern
- **Auswirkung:** In phase6_implement koennen beliebige Dateien nachtraeglich freigeschalten werden
- **Warum Edit-Gate versagt:** `_find_workflow_for_file()` iteriert ueber alle aktiven Workflows und prueft nur ob die Datei in `affected_files` steht — nicht wann/warum sie eingetragen wurde

### RC2: `project.pbxproj` nicht in PROTECTED_FILE_PATTERNS (MITTEL)
- **Code-Stelle:** `bash_gate.py:47-53`
- **Problem:** `PROTECTED_FILE_PATTERNS` enthaelt nur `.claude/`-Dateien, nicht `project.pbxproj`
- **Beweis:** `python3 -c "from pbxproj..."` matcht keinen protected pattern. `python3?\s+-c` steht in WRITE_INDICATORS (Zeile 57), wird aber nie erreicht weil `_references_protected()` fuer pbxproj-Befehle FALSE zurueckgibt — die gesamte Protected-Sektion (Zeile 253-259) wird uebersprungen.
- **Auswirkung:** pbxproj kann via Python-Einzeiler manipuliert werden

### RC3: Kein Auto-Complete nach Commit (NICHT FIXEN)
- **Code-Stelle:** `bash_gate.py:307-368`, `post_bash.py`
- **Problem:** Workflow bleibt nach Commit offen
- **Bewertung:** Bestehende Gates decken den Fall: Adversary-Verdict wird vor jedem fix:/feat:-Commit geprueft (bash_gate.py:360-365), phase6b/phase7 blockieren Code-Edits (edit_gate.py:310-313)
- **Entscheidung:** Bewusst offen lassen — Auto-Complete bringt mehr Reibung als Schutz

## Abgrenzung zu frueheren Fixes

| Commit | Was gefixt wurde | Warum INFRA_012 trotzdem noetig |
|--------|-----------------|-------------------------------|
| `bddbe18` | `set-affected-files` CLI-Kommando existierte gar nicht | Kommando existiert jetzt, aber ohne Phase-Check |
| `7abd6a4` | Completed Workflows konnten wiederverwendet werden | `_find_workflow_for_file` filtert jetzt phase0/phase8 — aber AKTIVE Workflows in phase6 sind nicht geschuetzt |
| `79ab427` | strict_code_gate (Vorgaenger von edit_gate) hatte Scope-Luecken | edit_gate.py v3 hat die meisten Luecken geschlossen — aber set-affected-files Phase-Check fehlt |
| `a55793e` | Override-Token fuer Workflow A bypassed Workflow B | Token ist jetzt workflow-spezifisch — anderes Problem als hier |

**Fazit:** Jeder vorherige Fix adressierte einen anderen Vektor. Der aktuelle Gap (set-affected-files in spaeten Phasen) wurde erst durch den Vorfall vom 2026-04-01 sichtbar.

## Fundamentales Vertrauensproblem (Challenger-Hinweis)

Der Challenger weist korrekt darauf hin: Claude setzt affected_files UND editiert die Dateien. Ein Phase-Guard verschiebt das Problem zeitlich — in phase2/3 koennte Claude theoretisch ebenfalls beliebige Dateien eintragen.

**Pragmatische Bewertung:** In phase2/3 ist das beabsichtigt (Scope wird definiert). Das Problem tritt auf wenn NACH Spec-Approval neue Dateien eingetragen werden — dann existiert kein Review-Schritt mehr. Der Phase-Guard ist daher der korrekte Fix: Er stellt sicher, dass affected_files VOR dem Approval-Checkpoint eingefroren werden.

## Fix-Strategie

### Fix 1: Phase-Guard fuer `set-affected-files`
- In `cmd_set_affected_files()` Phase-Check einbauen
- Erlaubte Phasen: `phase1_context` bis `phase4_approved` (inklusiv — `/10-bug` Schritt 7.5 ruft es in `phase4_approved` auf, VOR dem Phase-Wechsel zu phase5)
- `phase5_tdd_red` als zusaetzlich erlaubte Phase (Test-Dateien muessen registriert werden koennen)
- Override-Token als Bypass
- Override-Token-Logik reimplementiert (~10 LoC, identisch zu edit_gate.py)

### Fix 2: pbxproj-Schutz
- `project.pbxproj` zu `PROTECTED_FILE_PATTERNS` in bash_gate.py hinzufuegen
- Neues Script `scripts/add_file_to_project.py` als whitegelistete Alternative
- Script in `WHITELIST_COMMANDS` eintragen
- CLAUDE.md-Anweisung bleibt bestehen (Script ersetzt Python-Einzeiler)

## Scope
- 3 Dateien, ~50 LoC
- Risk: LOW
