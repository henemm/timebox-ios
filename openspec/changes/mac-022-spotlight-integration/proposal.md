# MAC-022: Spotlight Integration — Proposal

**Modus:** AENDERUNG (Bestehendes erweitern)
**Status:** Geplant
**Prioritaet:** P2
**Kategorie:** Support Feature
**Aufwand:** Klein (S)

---

## Was existiert bereits

### 1. SpotlightIndexingService (ITB-G2)
`Sources/Services/SpotlightIndexingService.swift`

- Vollstaendiger CoreSpotlight-Service: `indexTask()`, `deindexTask()`, `reindexAllTasks()`
- Korrekte Filter-Logik: completed + templates werden NICHT indexiert
- Korrekte Attribute: title, description, tags, taskType als keywords
- Korrekte Identifier: `task.uuid.uuidString` als uniqueIdentifier, `"com.focusblox.tasks"` als Domain
- 8 Unit Tests gruen (SpotlightIndexingServiceTests)
- **PROBLEM: Wird NIE aufgerufen.** Kein einziger Call-Site in iOS oder macOS-App.

### 2. NSUserActivity (ITB-F-lite)
`Sources/Intents/TaskEntity.swift`, `Sources/Views/BacklogRow.swift`, `FocusBloxMac/MacBacklogRow.swift`

- `TaskEntity.userActivity`: isEligibleForSearch = true, activityType = "com.henning.focusblox.viewTask"
- `BacklogRow`: `.userActivity(...)` Modifier — indexiert Tasks nur wenn die Zeile auf dem Bildschirm sichtbar ist
- `MacBacklogRow`: `.userActivity(...)` Modifier — gleiches Pattern
- **Problem:** Sichtbarkeits-abhaengig. Tasks die nie angezeigt werden, erscheinen nicht in Spotlight.

### 3. macOS Quick Capture Action (indexQuickCaptureAction)
`FocusBloxMac/FocusBloxMacApp.swift`

- "Neue Task erstellen" CSSearchableItem wird beim macOS App-Start indexiert
- Handler `handleSpotlightActivity()` ist implementiert — oeffnet Quick Capture Panel
- Handler ist via `.onContinueUserActivity(CSSearchableItemActionType)` verknuepft

### 4. iOS: KEIN Spotlight-Activity-Handler
`Sources/FocusBloxApp.swift`

- Kein `.onContinueUserActivity()` vorhanden
- iOS zeigt Tasks in Spotlight via NSUserActivity (view-dependent), aber ein Tap darauf tut nichts

---

## Was fehlt (das Delta)

### Luecke 1: SpotlightIndexingService wird nie aufgerufen — KRITISCH

`SpotlightIndexingService` ist vollstaendig implementiert aber ein totes Stueck Code:

| Methode | Soll aufgerufen werden in | Wird aufgerufen in |
|---------|--------------------------|-------------------|
| `reindexAllTasks()` | App-Start (iOS + macOS) | Nirgends |
| `indexTask()` | Nach Task-Erstellung/Update | Nirgends |
| `deindexTask()` | Nach Task-Completion/Loeschung | Nirgends |

**Resultat:** Spotlight zeigt aktuell KEINE FocusBlox-Tasks im iOS/macOS Spotlight.

### Luecke 2: iOS hat keinen Spotlight-Tap-Handler

Wenn ein User in Spotlight einen Task-Eintrag antippe, passiert auf iOS nichts. Die App oeffnet sich, aber navigiert nicht zum Task.

### Luecke 3: macOS reindexiert Tasks nicht beim Start

macOS indexiert nur die "Neue Task erstellen"-Action, aber nie die eigentlichen Tasks.

---

## Empfohlener Ansatz

**Minimaler Fix in 3 Call-Sites, 2 Dateien.**

Der gesamte Service ist fertig — er muss nur eingebunden werden.

### Schritt 1: iOS App-Start — reindexAllTasks aufrufen
In `Sources/FocusBloxApp.swift`, `.onAppear`, nach dem bestehenden Block:
```swift
Task {
    try? await SpotlightIndexingService.shared.reindexAllTasks(
        context: sharedModelContainer.mainContext
    )
}
```

### Schritt 2: iOS Task-Lifecycle — indexTask / deindexTask aufrufen
In `Sources/Services/SyncEngine.swift`:
- Nach `createTask` in `LocalTaskSource`: `await SpotlightIndexingService.shared.indexTask(task)`
- In `completeTask()`: `try? await SpotlightIndexingService.shared.deindexTask(uuid: task.uuid)`
- In `deleteTask()`: `try? await SpotlightIndexingService.shared.deindexTask(uuid: task.uuid)`

Alternativ: In `LocalTaskSource.createTask()` und `LocalTaskSource.deleteTask()` (da dort der eigentliche `context.insert/delete` passiert).

### Schritt 3: iOS Spotlight-Tap-Handler
In `Sources/FocusBloxApp.swift`:
```swift
.onContinueUserActivity(TaskEntity.activityType) { activity in
    // Extrahiere Task-ID und navigiere zum Task (oder zeige Backlog)
    // Phase 1: Nur App-Oeffnen (kein Deep-Link noetig fuer MVP)
}
```

### Schritt 4: macOS reindexAllTasks beim Start
In `FocusBloxMac/FocusBloxMacApp.swift`, `.onAppear`:
```swift
Task {
    try? await SpotlightIndexingService.shared.reindexAllTasks(
        context: container.mainContext
    )
}
```

---

## Scope-Schaetzung

| Datei | Typ | Delta |
|-------|-----|-------|
| `Sources/FocusBloxApp.swift` | Aenderung | +5 LoC |
| `Sources/Services/SyncEngine.swift` | Aenderung | +8 LoC |
| `FocusBloxMac/FocusBloxMacApp.swift` | Aenderung | +5 LoC |

**Gesamt: 3 Dateien, ~18 LoC — weit innerhalb der Scoping-Limits.**

---

## Was NICHT im Scope ist

- Deep-Link Navigation zum spezifischen Task (wuerde ContentView-Refactoring erfordern)
- Spotlight Suggestion Ranking (Apple kontrolliert das automatisch)
- Benutzerdefinierte Spotlight-Thumbnails oder Bilder

---

## Risiken

- `SpotlightIndexingService` ist ein `actor` — alle Calls muessen `async` sein (bereits durch `Task {}` geloest)
- Reindex beim App-Start ist ein Background-Task, der beim UI-Testing uebersprungen werden sollte
- `deindexTask` bei Completion/Loeschung: Fehler sollen nicht propagiert werden (`try?`)
