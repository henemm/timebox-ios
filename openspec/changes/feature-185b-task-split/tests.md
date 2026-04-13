# Tests: Task Split UI

## Accessibility Identifiers (geplant)

| Element | ID | Typ |
|---------|-----|------|
| Aufteilen-Button (Hygiene) | `hygieneSplitButton` | Button |
| Original-Task-Titel (Split) | `splitOriginalTitle` | StaticText |
| Lade-Indikator | `splitLoadingIndicator` | ProgressView |
| Vorschlag-Zeile | `splitSuggestionRow_N` | View |
| Vorschlag-Titel (editierbar) | `splitSuggestionTitle_N` | TextField |
| Nochmal-Button | `splitRegenerateButton` | Button |
| Hinzufügen-Button | `splitAddButton` | Button |
| Erstellen-Button | `splitCreateButton` | Button |
| Info-Text | `splitInfoText` | StaticText |

## UI Tests

### test_splitButton_appearsInHygieneView
- GIVEN: BacklogHygieneView zeigt einen stale Task
- WHEN: Karte wird angezeigt
- THEN: "Aufteilen"-Button ist sichtbar

### test_splitButton_opensSheet
- GIVEN: "Aufteilen"-Button ist sichtbar
- WHEN: User tippt auf "Aufteilen"
- THEN: TaskSplitView-Sheet öffnet sich mit Original-Titel

### test_splitView_showsAISuggestions
- GIVEN: TaskSplitView ist offen
- WHEN: AI hat Vorschläge generiert
- THEN: Mindestens 2 Vorschläge sind sichtbar

### test_splitView_createButton_createsSubTasks
- GIVEN: AI-Vorschläge sind geladen
- WHEN: User tippt "Erstellen"
- THEN: Sheet schließt sich, nächster Hygiene-Task oder Summary erscheint

## Unit Tests

### test_suggestSplit_returnsEmptyWhenUnavailable
- Bereits vorhanden in TaskSplitServiceTests

### test_splitHouseholdTask / test_splitWorkTask / test_splitProjectTask
- Bereits vorhanden — AI-Qualitätstests
