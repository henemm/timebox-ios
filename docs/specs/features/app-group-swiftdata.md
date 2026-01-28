---
entity_id: app-group-swiftdata
type: feature
created: 2026-01-28
status: draft
workflow: app-group-swiftdata
---

# App Group SwiftData für Shortcuts Integration

- [x] Approved for implementation
- [x] Implementation complete (2026-01-28)

## Purpose

Haupt-App und Shortcuts sollen dieselbe SwiftData-Datenbank nutzen, damit Shortcuts Tasks lesen/erstellen/ändern können OHNE die App zu öffnen.

## Das Problem (vereinfacht)

| Komponente | Aktuell | Nach Änderung |
|------------|---------|---------------|
| Haupt-App | Schreibt in Ordner A | Schreibt in Ordner B |
| Shortcuts | Lesen Ordner B (leer!) | Lesen Ordner B ✓ |

**Ordner B** = App Group Container (beide Prozesse können darauf zugreifen)

## Scope

**Betroffene Dateien:**

| Datei | Änderung |
|-------|----------|
| `Sources/FocusBloxApp.swift` | App Group Container nutzen + Migration |
| `Sources/Intents/TaskEntity.swift` | SharedModelContainer hinzufügen |
| `Sources/Intents/CreateTaskIntent.swift` | SwiftData direkt nutzen |
| `Sources/Intents/GetNextUpIntent.swift` | SwiftData Abfrage |
| `Sources/Intents/CompleteTaskIntent.swift` | SwiftData Update |
| `Sources/Intents/CountOpenTasksIntent.swift` | SwiftData Count |
| `FocusBloxTests/AppGroupMigrationTests.swift` | Neue Tests |

**Geschätzt:** +150/-50 LoC, 7 Dateien

## Implementation Details

### 1. SharedModelContainer (zentral)

```swift
// In TaskEntity.swift
enum SharedModelContainer {
    private static let appGroupID = "group.com.henning.focusblox"

    static func create() throws -> ModelContainer {
        let schema = Schema([LocalTask.self, TaskMetadata.self])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

### 2. Migration (einmalig beim App-Start)

```swift
// In FocusBloxApp.swift
func migrateToAppGroupIfNeeded() {
    // 1. Prüfen ob bereits migriert
    guard !UserDefaults.standard.bool(forKey: "appGroupMigrationDone") else { return }

    // 2. Default Container öffnen, Daten lesen
    // 3. App Group Container öffnen, Daten kopieren
    // 4. Flag setzen

    UserDefaults.standard.set(true, forKey: "appGroupMigrationDone")
}
```

### 3. Intents aktualisieren

```swift
// CreateTaskIntent
static let openAppWhenRun: Bool = false  // ← Wichtig!

func perform() async throws -> some IntentResult {
    let container = try SharedModelContainer.create()
    let context = ModelContext(container)

    let task = LocalTask(title: taskTitle, ...)
    context.insert(task)
    try context.save()

    return .result(dialog: "Task '\(taskTitle)' erstellt.")
}
```

## Test Plan

### Unit Tests (TDD RED)

| Test | GIVEN | WHEN | THEN |
|------|-------|------|------|
| `testMigrationCopiesAllTasks` | 3 Tasks in Default Container | Migration läuft | 3 Tasks in App Group Container |
| `testMigrationOnlyRunsOnce` | Migration bereits erfolgt | App startet | Migration wird übersprungen |
| `testSharedContainerAccessible` | App Group konfiguriert | SharedModelContainer.create() | Kein Fehler |

### Integration Tests

| Test | Beschreibung |
|------|--------------|
| `testCreateTaskIntentSavesTask` | Intent erstellt Task, App sieht ihn |
| `testGetNextUpIntentReturnsTasks` | Intent liest Tasks korrekt |
| `testCompleteTaskIntentMarksComplete` | Intent markiert Task als erledigt |

### Manuelle Tests (auf Device)

- [ ] App starten → Bestehende Tasks sind da (Migration)
- [ ] Kurzbefehl "Task erstellen" → Task erscheint in App
- [ ] Kurzbefehl "Next Up anzeigen" → Zeigt korrekte Tasks
- [ ] Kurzbefehl "Task erledigen" → Task wird als erledigt markiert

## Acceptance Criteria

- [x] **AC1:** Haupt-App nutzt App Group Container ✓
- [x] **AC2:** Migration kopiert alle bestehenden Tasks (einmalig) ✓
- [x] **AC3:** CreateTaskIntent erstellt Tasks OHNE App zu öffnen (`openAppWhenRun = false`) ✓
- [x] **AC4:** GetNextUpIntent zeigt Next-Up Tasks an ✓
- [x] **AC5:** CompleteTaskIntent markiert Tasks als erledigt ✓
- [x] **AC6:** CountOpenTasksIntent zählt offene Tasks ✓
- [x] **AC7:** Alle Unit Tests grün ✓
- [x] **AC8:** UI Tests weiterhin grün (in-memory bleibt) ✓

## Risiko-Mitigation

| Risiko | Mitigation |
|--------|------------|
| Migration fehlschlägt | Try-Catch, App startet trotzdem |
| Daten verloren | Default Container wird NICHT gelöscht (Backup) |
| Intent crasht | Graceful Error mit Dialog |

## Offene Entscheidungen

**Soll Default Container nach Migration gelöscht werden?**
→ **Empfehlung: NEIN** (bleibt als Backup, verbraucht wenig Speicher)
