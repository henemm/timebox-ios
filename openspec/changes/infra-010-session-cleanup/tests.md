# Acceptance Tests: INFRA_010 Session-Cleanup

## Unit Tests (Python)

- [ ] GIVEN sessions.json mit Eintrag für nicht-existierenden Workflow WHEN _prune_orphaned_sessions() THEN Eintrag wird entfernt
- [ ] GIVEN sessions.json mit Eintrag für existierenden Workflow WHEN _prune_orphaned_sessions() THEN Eintrag bleibt erhalten
- [ ] GIVEN sessions.json mit Mix aus gültigen und verwaisten Einträgen WHEN _prune_orphaned_sessions() THEN nur verwaiste werden entfernt
- [ ] GIVEN leere sessions.json WHEN _prune_orphaned_sessions() THEN keine Fehler, Datei bleibt leer
- [ ] GIVEN cmd_list() wird aufgerufen WHEN verwaiste Sessions existieren THEN werden vor Auflistung geprunt
- [ ] GIVEN session_start.py wird aufgerufen WHEN verwaiste Sessions existieren THEN werden beim Start geprunt
