# Spec: Step 1 - Foundation

**Status:** Draft
**Workflow:** step1-foundation
**Created:** 2026-01-13

---

## 1. Ziel

Basis-Infrastruktur aufbauen, die beweist: Wir können Apple Reminders lesen und mit lokalen Metadaten (SortOrder, Duration) verknüpfen.

**Erfolgskriterium:** Console-Output zeigt Liste von PlanItems mit Titel, Sortierung und Dauer.

---

## 2. Projektstruktur

```
TimeBox/
├── TimeBoxApp.swift          # App Entry Point
├── Info.plist                # Permissions
├── Models/
│   ├── TaskMetadata.swift    # SwiftData Model
│   └── PlanItem.swift        # View Model
├── Services/
│   ├── EventKitRepository.swift
│   └── SyncEngine.swift
└── Views/
    └── ContentView.swift     # Placeholder (nur Debug-Output)
```

---

## 3. Komponenten-Specs

### 3.1 TaskMetadata (SwiftData Model)

**Zweck:** Persistiert Daten, die Apple nicht unterstützt.

```swift
@Model
class TaskMetadata {
    @Attribute(.unique) var reminderID: String
    var sortOrder: Int
    var manualDuration: Int?  // Minutes (nil = nicht gesetzt)

    init(reminderID: String, sortOrder: Int) {
        self.reminderID = reminderID
        self.sortOrder = sortOrder
        self.manualDuration = nil
    }
}
```

**Constraints:**
- `reminderID` ist unique (entspricht `EKReminder.calendarItemIdentifier`)
- `sortOrder` beginnt bei 0, aufsteigend

---

### 3.2 PlanItem (View Model)

**Zweck:** Kombiniertes Objekt für die UI (nicht persistent).

```swift
struct PlanItem: Identifiable {
    let id: String              // = reminderID
    let title: String
    let isCompleted: Bool
    let priority: Int           // 0 = none, 1-9 = priority
    var rank: Int               // from TaskMetadata.sortOrder
    var effectiveDuration: Int  // Minutes (computed)

    // Computed from: manualDuration ?? parsedDuration ?? 15
}
```

**Duration Resolution Logic:**
1. `TaskMetadata.manualDuration` (wenn gesetzt)
2. Regex im Titel: `#(\d+)min` (z.B. "#30min")
3. Default: 15 Minuten

---

### 3.3 EventKitRepository

**Zweck:** Kapselung aller Apple EventKit Operationen.

**Interface:**
```swift
@Observable
class EventKitRepository {
    var authorizationStatus: EKAuthorizationStatus

    func requestAccess() async throws -> Bool
    func fetchIncompleteReminders() async throws -> [EKReminder]
}
```

**Permissions:**
- Benötigt `NSRemindersUsageDescription` in Info.plist
- Verwendet `EKEventStore.requestFullAccessToReminders()`

---

### 3.4 SyncEngine

**Zweck:** Merge-Logik zwischen Apple und lokalen Daten.

**Interface:**
```swift
@Observable
class SyncEngine {
    func sync() async throws -> [PlanItem]
}
```

**Sync-Algorithmus:**
1. Fetch alle incomplete EKReminders
2. Fetch alle TaskMetadata aus SwiftData
3. Für jeden Reminder:
   - Wenn Metadata existiert → PlanItem erstellen
   - Wenn Metadata fehlt → neue Metadata anlegen (sortOrder = Ende der Liste)
4. Orphaned Metadata löschen (Reminder nicht mehr vorhanden)
5. Return: PlanItems sortiert nach `rank` (aufsteigend)

---

## 4. Info.plist Entries

```xml
<key>NSRemindersUsageDescription</key>
<string>TimeBox benötigt Zugriff auf deine Erinnerungen, um sie als Tasks anzuzeigen und zu planen.</string>
```

---

## 5. Test-Szenario (Manual)

**Setup:**
1. App starten
2. Reminder-Berechtigung erteilen
3. Mindestens 3 Reminders in Apple Reminders App anlegen:
   - "Task A"
   - "Task B #30min"
   - "Task C"

**Erwartetes Ergebnis (Console):**
```
=== PlanItems ===
[0] Task A - 15min (default)
[1] Task B #30min - 30min (parsed)
[2] Task C - 15min (default)
```

---

## 6. Nicht im Scope

- UI (nur Debug-Output)
- Calendar Events erstellen
- Drag & Drop
- Manual Reordering

---

## 7. Dateien die geändert/erstellt werden

| Datei | Aktion | LoC (ca.) |
|-------|--------|-----------|
| TimeBoxApp.swift | Neu | 20 |
| Models/TaskMetadata.swift | Neu | 15 |
| Models/PlanItem.swift | Neu | 40 |
| Services/EventKitRepository.swift | Neu | 50 |
| Services/SyncEngine.swift | Neu | 60 |
| Views/ContentView.swift | Neu | 30 |
| Info.plist | Neu | 20 |

**Gesamt:** 7 Dateien, ~235 LoC (innerhalb Scoping Limits)
