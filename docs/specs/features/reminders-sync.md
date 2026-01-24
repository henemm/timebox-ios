---
entity_id: reminders_sync
type: feature
created: 2026-01-23
updated: 2026-01-23
status: draft
version: "1.0"
workflow: reminders-sync
tags: [sync, eventkit, reminders]
---

# Optionale Synchronisation mit Apple Erinnerungen

## Approval

- [x] Approved for implementation (2026-01-23)

## Purpose

Bidirektionale Synchronisation mit Apple Erinnerungen. Tasks aus Apple Reminders werden als LocalTask importiert. Felder, die Apple nicht unterstützt (Tags, Urgency, TaskType), werden nur lokal gespeichert. Die Apple Reminders-ID wird für bidirektionale Sync-Verknüpfung gespeichert.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/RemindersSyncService.swift` | CREATE | Sync-Logik für Import/Export |
| `Sources/Models/ReminderData.swift` | MODIFY | +dueDate, +notes aus EKReminder |
| `Sources/Services/EventKitRepository.swift` | MODIFY | +createReminder(), +updateReminder() |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | MODIFY | Protocol-Erweiterung |
| `Sources/Services/SyncEngine.swift` | MODIFY | Integration von RemindersSyncService |
| `Sources/Views/SettingsView.swift` | MODIFY | Toggle für Reminders-Sync |
| `FocusBloxUITests/RemindersSyncUITests.swift` | CREATE | UI Tests |

### Estimates

- **Files:** 7 (4 MODIFY, 3 CREATE)
- **LoC:** +350 / -20
- **Risk Level:** MEDIUM

## Implementation Details

### 1. ReminderData Erweiterung

```swift
struct ReminderData: Identifiable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int
    let dueDate: Date?      // NEU
    let notes: String?      // NEU
}
```

### 2. EventKitRepository Erweiterung

```swift
// Neue Methoden
func createReminder(title: String, priority: Int, dueDate: Date?, notes: String?) throws -> String
func updateReminder(id: String, title: String?, priority: Int?, dueDate: Date?, notes: String?, isCompleted: Bool?) throws
```

### 3. RemindersSyncService

```swift
@Observable
@MainActor
final class RemindersSyncService {
    private let eventKitRepo: EventKitRepositoryProtocol
    private let modelContext: ModelContext

    /// Import: Apple Reminders → LocalTask
    func importFromReminders() async throws -> [LocalTask]

    /// Export: LocalTask → Apple Reminders (nur für sourceSystem: "reminders")
    func exportToReminders(task: LocalTask) async throws

    /// Full bidirectional sync
    func syncAll() async throws
}
```

### 4. Sync-Logik

**Import (Apple → Local):**
1. Alle incompleten Reminders fetchen
2. Für jeden Reminder:
   - Suche LocalTask mit `externalID == reminder.calendarItemIdentifier`
   - Wenn gefunden: Update (title, priority, dueDate, notes, isCompleted)
   - Wenn nicht gefunden: Neuen LocalTask erstellen mit `sourceSystem: "reminders"`

**Export (Local → Apple):**
1. Für LocalTask mit `sourceSystem: "reminders"` und `externalID != nil`:
   - Update Apple Reminder mit unterstützten Feldern

**Gelöschte Reminders:**
- Reminder nicht mehr in Apple gefunden → `sourceSystem` auf "local" setzen
- Task bleibt lokal erhalten

### 5. Settings Integration

```swift
// SettingsView.swift
@AppStorage("remindersSync Enabled") private var remindersSyncEnabled: Bool = false

Section("Apple Erinnerungen") {
    Toggle("Mit Erinnerungen synchronisieren", isOn: $remindersSyncEnabled)
}
```

### 6. Feld-Mapping

| LocalTask | EKReminder | Sync |
|-----------|------------|------|
| title | title | ↔ |
| priority | priority | ↔ |
| isCompleted | isCompleted | ↔ |
| dueDate | dueDateComponents | ↔ |
| taskDescription | notes | ↔ |
| externalID | calendarItemIdentifier | ← |
| tags | - | lokal |
| urgency | - | lokal |
| taskType | - | lokal |
| recurrencePattern | - | lokal |
| isNextUp | - | lokal |

## Test Plan

### UI Tests (TDD RED) - FocusBloxUITests/RemindersSyncUITests.swift

1. **testRemindersSyncToggleExists**
   - GIVEN: Settings offen
   - WHEN: User scrollt
   - THEN: Toggle "Mit Erinnerungen synchronisieren" sichtbar
   - EXPECTED TO FAIL: Toggle existiert noch nicht

2. **testRemindersSyncToggleDisabledByDefault**
   - GIVEN: Frische App-Installation
   - WHEN: Settings öffnen
   - THEN: Toggle ist OFF
   - EXPECTED TO FAIL: Toggle existiert noch nicht

3. **testImportedReminderAppearsInBacklog**
   - GIVEN: Apple Reminder existiert (Mock)
   - WHEN: Sync aktiviert + Backlog öffnen
   - THEN: Task erscheint mit korrektem Title
   - EXPECTED TO FAIL: Sync existiert noch nicht

4. **testImportedTaskRetainsLocalFields**
   - GIVEN: Importierter Task, dann lokal Tags hinzugefügt
   - WHEN: Erneuter Sync
   - THEN: Tags bleiben erhalten
   - EXPECTED TO FAIL: Sync existiert noch nicht

### Unit Tests - FocusBloxTests/RemindersSyncServiceTests.swift

1. **testImportCreatesNewLocalTask**
   - GIVEN: Reminder ohne existierenden LocalTask
   - WHEN: importFromReminders()
   - THEN: Neuer LocalTask mit sourceSystem="reminders" + externalID

2. **testImportUpdatesExistingLocalTask**
   - GIVEN: LocalTask mit externalID, Reminder mit geändertem Title
   - WHEN: importFromReminders()
   - THEN: LocalTask.title aktualisiert

3. **testImportPreservesLocalOnlyFields**
   - GIVEN: LocalTask mit tags=["Test"], Reminder ohne Tags
   - WHEN: importFromReminders()
   - THEN: LocalTask.tags bleibt ["Test"]

4. **testDeletedReminderBecomesLocal**
   - GIVEN: LocalTask mit sourceSystem="reminders"
   - WHEN: Reminder nicht mehr in Apple gefunden
   - THEN: sourceSystem → "local", externalID bleibt

5. **testExportUpdatesAppleReminder**
   - GIVEN: LocalTask mit sourceSystem="reminders", geänderter Title
   - WHEN: exportToReminders()
   - THEN: Apple Reminder.title aktualisiert

## Acceptance Criteria

- [ ] Settings: Toggle für Reminders-Sync vorhanden
- [ ] Import: Apple Reminders werden als LocalTask importiert
- [ ] Bidirektional: Änderungen synchen in beide Richtungen
- [ ] Lokale Felder: Tags, Urgency, TaskType bleiben bei Sync erhalten
- [ ] Gelöschte Reminders: Tasks werden nicht automatisch gelöscht
- [ ] UI Tests: Alle 4 UI Tests grün
- [ ] Unit Tests: Alle 5 Unit Tests grün

## Reminder-Listen Konfiguration

### Funktionalitaet

User kann in Settings auswaehlen, welche Reminder-Listen synchronisiert werden sollen:
- Alle verfuegbaren Listen werden als Toggles angezeigt
- Standardmaessig sind alle Listen aktiv
- Auswahl wird in UserDefaults gespeichert (`visibleReminderListIDs`)

### API

```swift
// EventKitRepositoryProtocol
func getAllReminderLists() -> [EKCalendar]

// EventKitRepository - fetchIncompleteReminders() filtert nach visibleReminderListIDs
```

### UI (SettingsView)

```swift
Section("Sichtbare Erinnerungslisten") {
    ForEach(allReminderLists) { list in
        Toggle(list.title, isOn: binding(for: list.calendarIdentifier))
    }
}
```

## Known Limitations

- Nur Sync von incompleten Reminders (completed werden ignoriert)
- Keine Push-Notifications bei Änderungen in Apple (nur Pull bei App-Start/Refresh)
- Recurrence wird nicht synchronisiert (zu komplex)

## Changelog

- 2026-01-23: Initial spec created
