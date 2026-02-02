# Feature Spec: Volle Editierbarkeit für importierte Reminders

## Metadata

| Key | Value |
|-----|-------|
| Feature ID | reminder-full-edit |
| Type | AENDERUNG (Modification) |
| Priority | Hoch (UX-kritisch) |
| Scope | ~60 LoC, 4 Dateien |
| Created | 2026-01-24 |

---

## Problem Statement

Tasks aus Apple Erinnerungen haben eingeschränkte Editierbarkeit im Vergleich zu nativen FocusBlox Tasks. User sehen unterschiedliche Edit-Dialoge je nach Task-Quelle, was verwirrend ist.

**Aktuell editierbar (importierte Tasks):**
- Title
- Priority
- Duration

**NICHT editierbar (aber bei nativen Tasks möglich):**
- Tags
- Urgency (Dringlichkeit)
- TaskType (Typ)
- DueDate (Fälligkeitsdatum)
- Description (Beschreibung)

---

## Solution

### Technischer Kontext (bereits vorhanden)

1. **LocalTask Model** hat bereits ALLE Felder (tags, urgency, taskType, dueDate, taskDescription)
2. **RemindersSyncService** speichert Reminders als LocalTask mit `sourceSystem="reminders"`
3. **Sync preserviert lokale Felder** - beim Update werden nur Apple-Felder überschrieben

### Was zu ändern ist

Die UI (`EditTaskSheet`) muss erweitert werden, um alle Felder anzuzeigen und zu speichern.

---

## Affected Files

| Datei | Änderung | LoC |
|-------|----------|-----|
| `Sources/Views/EditTaskSheet.swift` | Alle Felder hinzufügen | +60 |
| `Sources/Services/SyncEngine.swift` | updateTask() erweitern | +15 |
| `Sources/Services/RemindersSyncService.swift` | notes/dueDate beim Import übernehmen | +5 |
| `Sources/Models/PlanItem.swift` | Unused init entfernen | -20 |

**Gesamt:** ~60 LoC netto

---

## Implementation Plan

### Phase 1: EditTaskSheet erweitern

```swift
// Neue Felder hinzufügen:
@State private var tags: String           // Comma-separated
@State private var urgency: String        // "normal", "dringend", "kann warten"
@State private var taskType: String       // "task", "meeting", "call", etc.
@State private var dueDate: Date?         // Optional
@State private var hasDueDate: Bool
@State private var description: String
```

UI Sections:
1. **Basis** (bestehend): Title, Priority, Duration
2. **Kategorisierung** (neu): Tags, Urgency, TaskType
3. **Zeitplanung** (neu): DueDate Toggle + Picker
4. **Details** (neu): Description TextEditor

### Phase 2: SyncEngine.updateTask() erweitern

```swift
func updateTask(
    itemID: String,
    title: String,
    priority: TaskPriority,
    duration: Int,
    tags: [String],           // NEU
    urgency: String,          // NEU
    taskType: String,         // NEU
    dueDate: Date?,           // NEU
    description: String?      // NEU
) async throws
```

### Phase 3: RemindersSyncService Import verbessern

Bei `createTask()`:
- `reminder.notes` → `localTask.taskDescription`
- `reminder.dueDate` → `localTask.dueDate`

### Phase 4: Cleanup

- `PlanItem.init(reminder:metadata:)` entfernen (unused)

---

## Test Plan

### UI Tests (TDD RED)

```swift
final class EditTaskSheetUITests: XCTestCase {

    /// Test: EditTaskSheet zeigt Tags-Feld
    func testEditSheetShowsTagsField() {
        // Open task edit sheet
        // Verify tags input field exists
    }

    /// Test: EditTaskSheet zeigt Urgency Picker
    func testEditSheetShowsUrgencyPicker() {
        // Verify urgency picker exists with options
    }

    /// Test: EditTaskSheet zeigt DueDate Toggle
    func testEditSheetShowsDueDateToggle() {
        // Verify due date toggle exists
    }

    /// Test: EditTaskSheet zeigt Description
    func testEditSheetShowsDescriptionField() {
        // Verify description text editor exists
    }

    /// Test: Änderungen werden gespeichert
    func testEditSheetSavesAllFields() {
        // Edit all fields
        // Save
        // Reopen and verify values persisted
    }
}
```

### Unit Tests

```swift
final class SyncEngineUpdateTests: XCTestCase {

    /// Test: updateTask speichert alle Felder
    func testUpdateTaskSavesAllFields() async throws {
        // Create task
        // Update with all fields
        // Verify all fields saved
    }
}
```

---

## Acceptance Criteria

1. [ ] User kann Tags bei importiertem Task bearbeiten
2. [ ] User kann Urgency bei importiertem Task ändern
3. [ ] User kann TaskType bei importiertem Task ändern
4. [ ] User kann DueDate bei importiertem Task setzen/ändern
5. [ ] User kann Description bei importiertem Task bearbeiten
6. [ ] Änderungen werden in SwiftData gespeichert
7. [ ] Änderungen überleben App-Neustart
8. [ ] Änderungen überleben Reminders-Sync (werden nicht überschrieben)

---

## Out of Scope

- iCloud Sync für TaskMetadata (separates Feature)
- Bidirektionaler Sync von erweiterten Feldern zurück zu Apple Reminders
- Recurrence Pattern für importierte Tasks

---

## Dependencies

- Keine externen Dependencies
- Nutzt bestehende SwiftData Infrastruktur

---

## Risks

| Risk | Mitigation |
|------|------------|
| Sync überschreibt lokale Änderungen | Bereits gelöst: RemindersSyncService preserviert lokale Felder |
| UI wird zu komplex | Sections nutzen, wie in CreateTaskView |
