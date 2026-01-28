# Context: App Group SwiftData für Shortcuts Integration

## Anforderung

App Group SwiftData in BEIDEN Prozessen nutzen:
- **Haupt-App** → liest/schreibt Tasks aus App Group Container
- **Intents (Shortcuts)** → liest/schreibt Tasks aus demselben Container

**Ziel:** Intents können Tasks OHNE App-Öffnung erstellen/lesen/ändern.

## Aktueller Stand

### Haupt-App (FocusBloxApp.swift)
- Nutzt **Standard-Container** (NICHT App Group)
- Kommentar: "App Group NOT used - causes data loss issues"
- UI Tests nutzen in-memory Storage

### Intents
- `CreateTaskIntent`: Nutzt UserDefaults-Bridge (öffnet App)
- `GetNextUpIntent`, `CompleteTaskIntent`, `CountOpenTasksIntent`: Öffnen nur die App
- `TaskEntityQuery`: Gibt leere Arrays zurück

### App Group
- ID: `group.com.henning.focusblox`
- Bereits konfiguriert in Entitlements (App + Widget)
- Wird für UserDefaults genutzt (CC Widget, Shortcuts Bridge)

## Technische Analyse

### Problem bei vorherigem Versuch

1. **Migration nicht getestet** - Daten im Default Container blieben dort
2. **Zwei separate Datenbanken** - App Group Container ≠ Default Container
3. **Keine Migration auf Device** - Nur Simulator getestet

### Lösung: Einmalige Migration + App Group Container

**Schritt 1: Migration**
```swift
// Beim App-Start EINMALIG:
// 1. Prüfen ob Default Container Daten hat
// 2. Daten in App Group Container kopieren
// 3. Default Container löschen (optional)
// 4. Flag setzen dass Migration erfolgt ist
```

**Schritt 2: App Group Container nutzen**
```swift
// Haupt-App:
ModelConfiguration(
    schema: schema,
    groupContainer: .identifier("group.com.henning.focusblox"),
    cloudKitDatabase: .none
)

// Intents (identisch!):
ModelConfiguration(
    schema: schema,
    groupContainer: .identifier("group.com.henning.focusblox"),
    cloudKitDatabase: .none
)
```

### Risiken

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Migration fehlschlägt | MITTEL | HOCH | Backup in UserDefaults vor Migration |
| Daten verloren | NIEDRIG | HOCH | Nur migrieren wenn Default Container existiert |
| Tests brechen | HOCH | NIEDRIG | UI Tests bleiben in-memory |
| Intents crashen | MITTEL | MITTEL | Try-Catch, graceful degradation |

## Analysis

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/FocusBloxApp.swift` | MODIFY | App Group Container nutzen, Migration |
| `Sources/Intents/TaskEntity.swift` | MODIFY | IntentModelContainer wiederherstellen |
| `Sources/Intents/CreateTaskIntent.swift` | MODIFY | SwiftData direkt nutzen, `openAppWhenRun = false` |
| `Sources/Intents/GetNextUpIntent.swift` | MODIFY | SwiftData Abfrage, `openAppWhenRun = false` |
| `Sources/Intents/CompleteTaskIntent.swift` | MODIFY | SwiftData Update, Entity Picker |
| `Sources/Intents/CountOpenTasksIntent.swift` | MODIFY | SwiftData Count Abfrage |
| `FocusBloxTests/AppGroupMigrationTests.swift` | CREATE | Migration Tests |

### Scope Assessment

- **Files:** 7
- **Estimated LoC:** +150/-50
- **Risk Level:** MEDIUM-HIGH (Datenmigration!)

### Technical Approach

1. **SharedModelContainer erstellen** - Zentraler Container für App + Intents
2. **Migration implementieren** - Default → App Group (einmalig)
3. **Intents aktualisieren** - SwiftData direkt nutzen
4. **Tests schreiben** - Migration + Intent-Funktionalität

### Migrations-Strategie

```
1. App startet
2. Check: UserDefaults["appGroupMigrationDone"] == true?
   - JA → App Group Container nutzen
   - NEIN → Migration durchführen:
     a. Default Container öffnen
     b. Alle LocalTasks + TaskMetadata lesen
     c. App Group Container öffnen
     d. Alle Daten kopieren
     e. UserDefaults["appGroupMigrationDone"] = true
3. App Group Container nutzen
```

### Open Questions

- [x] App Group bereits in Entitlements? → JA
- [x] Widget nutzt bereits App Group? → JA (für UserDefaults)
- [ ] Wie viele Tasks hat der User typischerweise? (Performance bei Migration)
- [ ] Soll Default Container nach Migration gelöscht werden?

## Empfehlung

**JA, umsetzen.** Die Vorteile überwiegen:
- Intents funktionieren ohne App-Öffnung
- Saubere Architektur (ein Container für alles)
- Migration ist einmalig und testbar

**Aber:** Sorgfältige Migration mit Backup-Strategie nötig.
