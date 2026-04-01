# FEATURE_030 — Test-Definition

## Unit Tests (TaskLifecycleLoggerTests)

### Logger-Grundfunktion
- `test_logCreated_writesEntryWithTimestampAndTaskID` — Bei logCreated wird ein Eintrag mit [created], ISO-Timestamp und Task-UUID geschrieben
- `test_logUpdated_writesFieldChanges` — Bei logUpdated werden alte→neue Werte pro Feld protokolliert
- `test_logDeleted_writesDeleteEntry` — Bei logDeleted wird ein [deleted]-Eintrag geschrieben
- `test_logCompleted_writesCompletedEntry` — Bei logCompleted wird ein [completed]-Eintrag geschrieben
- `test_logUncompleted_writesUncompletedEntry` — Bei logUncompleted wird ein [uncompleted]-Eintrag geschrieben

### Toggle-Guard
- `test_logCreated_doesNothingWhenDisabled` — Bei deaktiviertem Toggle wird NICHTS geschrieben
- `test_logUpdated_doesNothingWhenDisabled` — Bei deaktiviertem Toggle wird NICHTS geschrieben

### Log-Management
- `test_getLog_returnsAllEntries` — getLog() gibt den gesamten Log-Inhalt zurück
- `test_clearLog_removesAllEntries` — clearLog() leert die Log-Datei

### FieldChange
- `test_fieldChange_formatsCorrectly` — FieldChange erzeugt "field=old→new" Format

## UI Tests (TaskDebugModeUITests)

### Settings-Toggle
- `testDebugModeToggleExistsInSettings` — Toggle "Task Debug Mode" existiert in Settings unter "Entwickler"
- `testDebugModeToggleCanBeToggled` — Toggle kann ein-/ausgeschaltet werden
- `testLifecycleLogButtonExistsWhenEnabled` — "Lifecycle Log anzeigen"-Button erscheint bei aktiviertem Toggle
- `testLogSheetOpens` — Tap auf "Lifecycle Log anzeigen" öffnet ein Sheet mit Log-Inhalt
