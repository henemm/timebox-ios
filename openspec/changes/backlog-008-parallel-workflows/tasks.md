# BACKLOG-008: Implementierungs-Checkliste (Phase 1 MVP)

## Phase 1: workflow_state_multi.py

- [ ] Neue Funktion `find_workflow_for_file(file_path: str) -> list[tuple[str, dict]]`
  - Alle Workflows in CODE_MODIFY_PHASES durchsuchen
  - `verify_file_in_workflow()` Logik wiederverwenden (oder inline)
  - Rueckgabe: Liste von (workflow_name, workflow_dict) Tupeln
  - Sortierung: zuletzt_geupdateter zuerst

- [ ] `complete_workflow()` reparieren
  - `remaining[0]`-Logik entfernen
  - Nach Completion: `active_workflow` unveraendert lassen (oder auf None)
  - Kein automatisches Wechseln auf zufaelligen Workflow

## Phase 2: strict_code_gate.py

- [ ] Neue Lookup-Logik nach dem Whitelist/Code-File-Check:
  ```
  candidates = find_workflow_for_file(file_path)
  if candidates:
      workflow = candidates[0][1]   # Bester Treffer
      workflow["name"] = candidates[0][0]
  else:
      workflow = get_active_workflow()  # Legacy-Fallback
  ```
- [ ] Override-Check: `token["workflow"] == workflow["name"]` (nicht active_name)
- [ ] Fehlermeldung bei keinem Treffer anpassen: Klartext welche Workflows in Frage kaemen

## Phase 3: tdd_enforcement.py

- [ ] `check_tdd_requirements(file_path)` anpassen:
  - Gleiche `find_workflow_for_file()`-Logik wie Code-Gate
  - Legacy-Fallback auf `get_active_workflow()` wenn kein Treffer
- [ ] `check_user_override()` anpassen:
  - workflow_name-Parameter hinzufuegen
  - Token-Vergleich gegen uebergebenen Namen, nicht active_workflow

## Phase 4: override_token_listener.py

- [ ] Regex fuer `"override [workflow-name]"` hinzufuegen
  - Pattern: `override\s+([\w-]+)` → Gruppe 1 = workflow-name
  - Validierung: Workflow-Name muss in state["workflows"] existieren
- [ ] Fallback: wenn kein Name → active_workflow (bestehend)
- [ ] Ausgabe: Name des Workflows fuer den Token erstellt wurde

## Tests (TDD RED zuerst)

- [ ] Unit-Tests in Python fuer `find_workflow_for_file()`:
  - Leeres affected_files → kein Treffer
  - Exact match → Treffer
  - Path-Suffix match → Treffer
  - Mehrere Treffer → zuletzt geupdateter gewinnt
  - Abgeschlossene Workflows (phase8) → ignoriert

- [ ] Unit-Tests fuer `complete_workflow()` Fix:
  - Nach Completion ist active_workflow NICHT auf zufaelligen Workflow gewechselt

- [ ] Integration-Test Override-Token mit explizitem Workflow-Namen

## Validierung

- [ ] Bestehende Workflows mit leerem `affected_files` weiterhin funktional
- [ ] Override "fuer workflow-name" korrekt zugewiesen
- [ ] `complete_workflow()` wechselt nicht mehr automatisch
- [ ] `docs/ACTIVE-todos.md`: BACKLOG-008 Status auf "done" setzen
