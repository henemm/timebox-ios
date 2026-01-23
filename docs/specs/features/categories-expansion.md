---
entity_id: categories-expansion
type: feature
created: 2026-01-23
status: draft
workflow: categories-expansion
tags: [task-type, categories, user-story-sprint-3]
---

# Kategorien erweitern (5 statt 3)

## Approval

- [ ] Approved for implementation

## Purpose

Erweiterung der Task-Kategorien von 3 auf 5, um das gesamte Spektrum der Lebensarbeit abzudecken:
- Bestehend: `income`, `maintenance`, `recharge`
- Neu: `learning`, `giving_back`

## Scope

### Affected Files

| File | Change | Description |
|------|--------|-------------|
| `TimeBox/Sources/Views/TaskCreation/CreateTaskView.swift` | MODIFY | 2 neue Optionen im Picker |
| `TimeBox/Sources/Views/BacklogView.swift` | MODIFY | localizedCategory Erweiterung |
| `TimeBox/Sources/Models/LocalTask.swift` | MODIFY | Dokumentation der gültigen Werte |

### Estimate

- **Files:** 3
- **LoC:** +10/-0
- **Risk:** LOW (additive change, no breaking changes)

## Implementation Details

### 1. CreateTaskView Picker erweitern

```swift
// Existing:
Picker("Aufgabentyp", selection: $taskType) {
    Label("Geld verdienen", systemImage: "dollarsign.circle").tag("income")
    Label("Schneeschaufeln", systemImage: "wrench.and.screwdriver").tag("maintenance")
    Label("Energie aufladen", systemImage: "battery.100").tag("recharge")
}

// After:
Picker("Aufgabentyp", selection: $taskType) {
    Label("Geld verdienen", systemImage: "dollarsign.circle").tag("income")
    Label("Schneeschaufeln", systemImage: "wrench.and.screwdriver").tag("maintenance")
    Label("Energie aufladen", systemImage: "battery.100").tag("recharge")
    Label("Lernen", systemImage: "book").tag("learning")
    Label("Weitergeben", systemImage: "gift").tag("giving_back")
}
```

### 2. BacklogView localizedCategory erweitern

```swift
private extension String {
    var localizedCategory: String {
        switch self {
        // ... existing cases ...
        case "income": return "Geld verdienen"
        case "recharge": return "Energie aufladen"
        case "learning": return "Lernen"
        case "giving_back": return "Weitergeben"
        default: return self.capitalized
        }
    }
}
```

### 3. LocalTask Dokumentation

```swift
/// Task categorization type (income/maintenance/recharge/learning/giving_back)
var taskType: String = "maintenance"
```

## Category Definitions

| Value | Label | Icon | Beschreibung |
|-------|-------|------|--------------|
| `income` | Geld verdienen | dollarsign.circle | Arbeit die Einkommen generiert |
| `maintenance` | Schneeschaufeln | wrench.and.screwdriver | Notwendige Erhaltungsarbeiten |
| `recharge` | Energie aufladen | battery.100 | Selbstfürsorge, Erholung |
| `learning` | Lernen | book | Weiterbildung, neue Fähigkeiten |
| `giving_back` | Weitergeben | gift | Anderen helfen, Mentoring, Ehrenamt |

## Test Plan

### Automated Tests (TDD RED)

#### Unit Tests (`TimeBoxTests/CategoriesTests.swift`)

1. **testAllCategoriesExist**
   - GIVEN: CreateTaskView default values
   - WHEN: Checking taskType options
   - THEN: All 5 categories should be selectable

2. **testLocalizedCategoryReturnsCorrectLabels**
   - GIVEN: All category string values
   - WHEN: Calling localizedCategory
   - THEN: Returns correct German labels

#### UI Tests (`TimeBoxUITests/CategoriesUITests.swift`)

1. **testTaskTypePickerShowsFiveOptions**
   - GIVEN: CreateTaskView is open
   - WHEN: Opening task type picker
   - THEN: 5 options are visible (income, maintenance, recharge, learning, giving_back)

2. **testNewCategoryCanBeSelected**
   - GIVEN: CreateTaskView is open
   - WHEN: Selecting "learning" category
   - THEN: Category is selected and task can be saved

### Manual Tests

- [ ] Alle 5 Kategorien im Picker sichtbar
- [ ] Neue Kategorien speicherbar
- [ ] Bestehende Tasks behalten ihre Kategorie

## Acceptance Criteria

- [ ] 5 Kategorien im CreateTaskView Picker
- [ ] Korrekte Icons für neue Kategorien
- [ ] localizedCategory gibt korrekte Labels zurück
- [ ] Keine Breaking Changes für bestehende Tasks
- [ ] Alle Unit Tests grün
- [ ] Alle UI Tests grün

## Design Decisions

| Frage | Entscheidung |
|-------|--------------|
| Icon für "Lernen"? | `book` (klar, universell) |
| Icon für "Weitergeben"? | `gift` (symbolisch für Geben) |
| Label "Weitergeben"? | Kurz und klar, alternative "Geben" zu vage |
| Default bleibt? | `maintenance` (meiste Tasks sind Erhaltung) |

## Migration

Keine Migration nötig - additive Änderung. Bestehende Tasks mit `income`, `maintenance`, `recharge` funktionieren weiterhin.

## Changelog

- 2026-01-23: Initial spec created (Sprint 3 der User Story Roadmap)
