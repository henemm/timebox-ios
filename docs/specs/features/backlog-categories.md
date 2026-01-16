---
entity_id: backlog-categories
type: feature
created: 2026-01-15
updated: 2026-01-15
status: draft
version: "1.0"
workflow: backlog-categories
tags: [backlog, categories, grouping, sorting]
---

# Backlog Categories & Grouping

## Approval

- [ ] Approved for implementation

## Purpose

Kategorien aus Apple Reminders in der Backlog-View sichtbar machen und verschiedene Gruppierungs-/Sortieroptionen anbieten, damit der Nutzer Tasks nach Kontext (Liste), Dauer oder Faelligkeit organisieren kann.

## Scope

### Affected Files

| File | Change | Description |
|------|--------|-------------|
| `Sources/Models/ReminderData.swift` | MODIFY | + calendarTitle, calendarColor, dueDate |
| `Sources/Services/EventKitRepository.swift` | MODIFY | Calendar-Info beim Mapping hinzufuegen |
| `Sources/Models/PlanItem.swift` | MODIFY | + calendarTitle, calendarColor, dueDate |
| `Sources/Views/BacklogRow.swift` | MODIFY | + Kategorie-Chip Darstellung |
| `Sources/Views/BacklogView.swift` | MODIFY | + Gruppierung, Sortier-Menu in Toolbar |
| `Sources/Models/BacklogGroupMode.swift` | CREATE | Enum fuer Gruppierungsmodus |

### Estimate

- **Files:** 6
- **LoC:** +120/-10
- **Risk:** LOW

## Implementation Details

### 1. Data Model Extensions

**ReminderData.swift:**
```swift
struct ReminderData {
    // Existing
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: Int

    // NEW
    let calendarTitle: String      // Reminder-Liste Name
    let calendarColor: CGColor?    // Reminder-Liste Farbe
    let dueDate: Date?             // Faelligkeitsdatum
}
```

**PlanItem.swift:**
```swift
struct PlanItem {
    // Existing fields...

    // NEW
    let calendarTitle: String
    let calendarColor: CGColor?
    let dueDate: Date?
}
```

### 2. Grouping Modes

**BacklogGroupMode.swift:**
```swift
enum BacklogGroupMode: String, CaseIterable {
    case none           // Flache Liste mit Chips
    case byCategory     // Nach Reminder-Liste
    case byDuration     // Kurz/Mittel/Lang
    case byDueDate      // Ueberfaellig/Heute/Woche/Spaeter

    var displayName: String { ... }
    var icon: String { ... }
}
```

### 3. Duration Groups

| Gruppe | Kriterium |
|--------|-----------|
| Kurz | < 15 min |
| Mittel | 15-30 min |
| Lang | > 30 min |

### 4. Due Date Groups

| Gruppe | Kriterium |
|--------|-----------|
| Ueberfaellig | dueDate < today |
| Heute | dueDate == today |
| Diese Woche | dueDate in next 7 days |
| Spaeter | dueDate > 7 days |
| Ohne Datum | dueDate == nil |

### 5. UI Changes

**BacklogView.swift:**
- Menu in Toolbar mit Gruppierungsoptionen
- Sectioned List wenn gruppiert
- Persistierung via `@AppStorage("backlogGroupMode")`

**BacklogRow.swift:**
- Kategorie-Chip wenn `groupMode == .none`
- Chip: Farbiger Punkt (8pt) + Text in sekundaerer Farbe

## Expected Behavior

- **Default:** `byCategory` (gruppiert nach Reminder-Liste)
- **Wechsel:** Tap auf Menu-Icon in Toolbar
- **Persistenz:** Auswahl bleibt nach App-Neustart erhalten
- **Chips:** Nur sichtbar wenn `groupMode == .none`

## Test Plan

### Automated Tests (TDD RED)

```swift
// ReminderDataTests.swift
- [ ] test_reminderData_extractsCalendarTitle()
- [ ] test_reminderData_extractsCalendarColor()
- [ ] test_reminderData_extractsDueDate()

// PlanItemTests.swift
- [ ] test_planItem_passesCalendarInfo()

// BacklogGroupModeTests.swift
- [ ] test_groupByDuration_sortsCorrectly()
- [ ] test_groupByDueDate_categorizes_overdue()
- [ ] test_groupByDueDate_categorizes_today()
- [ ] test_groupByCategory_groupsByCalendarTitle()
```

### Manual Tests

- [ ] Gruppierung nach Kategorie zeigt Sections mit Listennamen
- [ ] Gruppierung nach Dauer zeigt Kurz/Mittel/Lang Sections
- [ ] Gruppierung nach Faelligkeit zeigt korrekte Einordnung
- [ ] Ohne Gruppierung: Chips mit Farbe + Listenname sichtbar
- [ ] Menu in Toolbar wechselt Gruppierungsmodus
- [ ] Auswahl bleibt nach App-Neustart erhalten

## Acceptance Criteria

- [ ] Kategorie-Information (Name + Farbe) wird aus Reminders geladen
- [ ] 4 Gruppierungsmodi verfuegbar (None, Category, Duration, DueDate)
- [ ] Gruppierungsmodus ueber Toolbar-Menu waehlbar
- [ ] Bei `none`: Kategorie-Chip in jeder Zeile sichtbar
- [ ] Auswahl wird persistiert
- [ ] Alle Unit Tests gruen

## Known Limitations

- Farben aus EKCalendar sind CGColor, muessen zu SwiftUI Color konvertiert werden
- Faelligkeitsdatum ist optional (nicht alle Reminders haben eins)

## Changelog

- 2026-01-15: Initial spec created
