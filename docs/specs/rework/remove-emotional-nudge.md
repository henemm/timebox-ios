# Spec: Emotional Nudge Feature entfernen (#210)

## Kontext
Das Feature "Emotional Nudge" (RW_3.4) wurde implementiert ohne PO-Freigabe und soll komplett entfernt werden.

## Änderungen

### Dateien LÖSCHEN
1. `Sources/Services/EmotionalNudgeService.swift`
2. `FocusBloxTests/SmartNudgeTests.swift`
3. `FocusBloxTests/EmotionalNudgeServiceTests.swift`
4. `FocusBloxUITests/EmotionalNudgeUITests.swift`
5. `FocusBloxTests/SmartNotificationEngineIntentionTests.swift`

### Dateien EDITIEREN
6. `Sources/Views/BacklogRow.swift` — `isStuck` Property + Overlay entfernen
7. `Sources/Views/TaskDetailSheet.swift` — `onStartNudgeSprint` + Nudge-Section entfernen
8. `Sources/Views/TaskFormSheet.swift` — `onStartNudgeSprint` + `nudgeSection` entfernen
9. `Sources/Views/BacklogView.swift` — `isStuck:` Parameter + `EmotionalNudgeService.recordNudge` entfernen
10. `Sources/Views/FocusLiveView.swift` — Nudge-Sprint-Dialog + `extendNudgeBlock()` entfernen
11. `Sources/Views/SettingsView.swift` — Nudge-Budget Section entfernen
12. `Sources/Services/SmartNotificationEngine.swift` — `budgetNudges`, `buildNudgeRequests()`, `fetchTodayIntention()` entfernen
13. `Sources/Services/NotificationContentService.swift` — Nudge-Content-Generierung entfernen
14. `Sources/Services/NotificationService.swift` — Nudge-Kategorie entfernen
15. `Sources/Services/NotificationActionDelegate.swift` — Nudge-Kommentare bereinigen
16. `Sources/Models/AppSettings.swift` — Nudge-Properties entfernen
17. `Sources/FocusBloxApp.swift` — Mock "Stuck Task" entfernen
18. `FocusBloxMac/ContentView.swift` — `startNudgeSprint()` + Nudge-Button entfernen

### Was BLEIBT
- `rescheduleCount` auf PlanItem (wird für Priority Score genutzt)
- `TaskPriorityScoringService.neglectScore()` (Score-Erhöhung bei Verschiebungen)

## Acceptance Criteria
- Kein gelbes ⚠️ Icon mehr im Backlog
- Keine "Nur 2 Minuten anfangen" Section im Task-Detail
- Keine Nudge-Notifications
- Kein "Weitermachen?" Dialog nach kurzen Blöcken
- Build erfolgreich (iOS + macOS)
- Alle verbleibenden Tests grün
