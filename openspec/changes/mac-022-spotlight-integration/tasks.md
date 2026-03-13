# MAC-022: Spotlight Integration — Tasks

**Status:** Geplant
**Geschaetzter Aufwand:** S (1 Session, ~15-25k Tokens)

---

## Implementierungs-Checkliste

### Phase TDD RED

- [ ] Unit Test: `reindexAllTasks` wird in `FocusBloxApp.onAppear` aufgerufen (Mockbarkeit pruefen)
- [ ] Unit Test: `indexTask` wird nach `LocalTaskSource.createTask()` aufgerufen
- [ ] Unit Test: `deindexTask` wird nach `SyncEngine.completeTask()` aufgerufen
- [ ] Unit Test: `deindexTask` wird nach `SyncEngine.deleteTask()` aufgerufen

> Hinweis: `SpotlightIndexingService` ist ein `actor` — fuer Unit Tests sind Mock-Testable-Methoden oder Verhalten-Tests sinnvoller als Call-Site-Tests. Bestehende 8 Tests in `SpotlightIndexingServiceTests` bleiben unveraendert.

### Phase IMPLEMENT

- [ ] `Sources/FocusBloxApp.swift`: `reindexAllTasks` Aufruf in `.onAppear` (nach bestehendem RecurrenceService-Block, nur wenn nicht UITesting)
- [ ] `Sources/Services/SyncEngine.swift`: `indexTask` nach `completeTask()` Seiteneffekt-umkehr — wenn `uncompleteTask` aufgerufen, Task re-indexieren
- [ ] `Sources/Services/LocalTaskSource.swift`: `indexTask` nach `createTask()` und `updateTask()`
- [ ] `Sources/Services/SyncEngine.swift`: `deindexTask` in `completeTask()` und `deleteTask()`
- [ ] `Sources/FocusBloxApp.swift`: `.onContinueUserActivity(TaskEntity.activityType)` Handler (App-Oeffnen, kein Deep-Link)
- [ ] `FocusBloxMac/FocusBloxMacApp.swift`: `reindexAllTasks` Aufruf in `.onAppear`

### Phase VALIDATE

- [ ] Build: iOS erfolgreich
- [ ] Build: macOS erfolgreich
- [ ] Alle bestehenden Tests gruen (SpotlightIndexingServiceTests, TaskEntityUserActivityTests)
- [ ] Neue Tests gruen

---

## Betroffene Dateien

| Datei | Aenderungstyp |
|-------|--------------|
| `Sources/FocusBloxApp.swift` | reindexAllTasks + onContinueUserActivity |
| `Sources/Services/SyncEngine.swift` | deindexTask in completeTask + deleteTask |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | indexTask in createTask + updateTask |
| `FocusBloxMac/FocusBloxMacApp.swift` | reindexAllTasks |

**4 Dateien, ~20 LoC — innerhalb Scoping-Limits.**
