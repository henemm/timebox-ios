# Tests für Backlog-Hygiene Slice 1

## Unit Tests (BacklogHealthServiceTests)

| Test | Prüft |
|------|-------|
| `test_findStaleTasks_oldTask_isIncluded` | Task 15 Tage alt → stale |
| `test_findStaleTasks_recentTask_isExcluded` | Task 3 Tage alt → nicht stale |
| `test_findStaleTasks_highRescheduleCount_isIncluded` | 3× verschoben → stale |
| `test_findStaleTasks_lowRescheduleCount_isExcluded` | 1× verschoben → nicht stale |
| `test_findStaleTasks_completedTask_isExcluded` | Erledigt → ausgeschlossen |
| `test_findStaleTasks_parkedTask_isExcluded` | Geparkt → ausgeschlossen |
| `test_findStaleTasks_templateTask_isExcluded` | Template → ausgeschlossen |
| `test_findStaleTasks_sortedOldestFirst` | Älteste zuerst |
| `test_findStaleTasks_customThresholds` | Eigene Schwellenwerte |
| `test_findStaleTasks_emptyInput_returnsEmpty` | Leere Liste → leer |

## UI Tests (BacklogHygieneUITests)

| Test | Prüft |
|------|-------|
| `test_hygieneBanner_appearsWhenStaleTasksExist` | Banner sichtbar bei stale Tasks |
| `test_hygieneBanner_opensSheet` | Tap auf Banner öffnet Aufräum-Sheet |
| `test_hygieneView_showsTaskCard` | Karte zeigt Task-Titel + Alter |
| `test_hygieneView_parkAction` | "Parken" → Task geparkt |
| `test_hygieneView_deleteAction` | "Löschen" → Task entfernt |
| `test_hygieneView_keepAction` | "Behalten" → nächste Karte |
| `test_hygieneView_summaryAfterLastTask` | Zusammenfassung am Ende |
