# Context: Step 2 - BacklogView

## Request Summary
BacklogView implementieren: Sortierbare Liste aller Tasks mit Drag & Drop Reordering.

## Scope (aus Projekt-Spec)

**Features:**
1. Liste aller PlanItems sortiert nach Rank
2. Drag & Drop zum Umsortieren
3. Duration Badge (gelb wenn Default)
4. Haptisches Feedback beim Drop
5. Sofortiges Speichern der neuen Reihenfolge

## Vorhandene Komponenten

| Komponente | Status | Datei |
|------------|--------|-------|
| TaskMetadata | ✅ Fertig | Sources/Models/TaskMetadata.swift |
| ReminderData | ✅ Fertig | Sources/Models/ReminderData.swift |
| PlanItem | ✅ Fertig | Sources/Models/PlanItem.swift |
| EventKitRepository | ✅ Fertig | Sources/Services/EventKitRepository.swift |
| SyncEngine | ✅ Fertig | Sources/Services/SyncEngine.swift |
| ContentView | Wird ersetzt | Sources/Views/ContentView.swift |

## Benötigte Änderungen

1. **BacklogView.swift** (neu) - Hauptview mit Liste
2. **BacklogRow.swift** (neu) - Einzelne Zeile mit Badge
3. **SyncEngine.swift** (erweitern) - Reorder-Funktion
4. **ContentView.swift** (anpassen) - BacklogView einbinden

## SwiftUI Patterns für Drag & Drop

```swift
List {
    ForEach(items) { item in
        Row(item)
    }
    .onMove { from, to in
        // Reorder logic
    }
}
.environment(\.editMode, .constant(.active)) // Enables drag handles
```

## Risiken

- SwiftData Concurrency beim Speichern
- Animation bei Reorder
