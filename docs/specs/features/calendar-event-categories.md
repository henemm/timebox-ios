# Spec: Calendar Event Categories

> Created: 2026-01-24
> Status: Draft
> Phase: 1 of 2

## Overview

Kalendereinträge (nicht nur Focus Blocks) sollen kategorisierbar werden. Phase 1 fokussiert auf die Grundfunktion: Tippen auf einen Kalendereintrag öffnet ein Category Sheet.

## User Story

**Als** Nutzer, der seine Zeit analysieren will,
**möchte ich** auch normale Kalendertermine kategorisieren können,
**damit** mein Rückblick ein vollständiges Bild meiner Zeitverwendung zeigt.

## Scope (Phase 1)

| In Scope | Out of Scope (Phase 2) |
|----------|------------------------|
| `CalendarEvent.category` Property | "unbekannt" als Default-Kategorie |
| `updateEventCategory()` im Repository | Review-Integration (Stats) |
| Tap auf Event → CategorySheet | Daily/Weekly Stats mit Events |
| UI Tests + Unit Tests | Uncategorized Tasks handling |

## Technical Design

### 1. CalendarEvent Model Extension

```swift
// Sources/Models/CalendarEvent.swift

var category: String? {
    guard let notes else { return nil }
    return parseNotesValue(prefix: "category:", from: notes)
}

private func parseNotesValue(prefix: String, from notes: String) -> String? {
    let lines = notes.components(separatedBy: "\n")
    guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
        return nil
    }
    return String(line.dropFirst(prefix.count))
}
```

### 2. EventKitRepositoryProtocol Extension

```swift
// Add to protocol:
func updateEventCategory(eventID: String, category: String?) throws
```

### 3. EventKitRepository Implementation

```swift
func updateEventCategory(eventID: String, category: String?) throws {
    guard let event = store.event(withIdentifier: eventID) else {
        throw EventKitError.eventNotFound
    }

    // Update notes with category, preserving existing content
    var notes = event.notes ?? ""

    // Remove existing category line
    var lines = notes.components(separatedBy: "\n")
    lines.removeAll { $0.hasPrefix("category:") }

    // Add new category if provided
    if let category = category {
        lines.append("category:\(category)")
    }

    event.notes = lines.joined(separator: "\n")
    try store.save(event, span: .thisEvent)
}
```

### 4. UI: CategorySheet for Events

Wiederverwendung des existierenden Category-Pickers (wie bei Tasks):

```swift
// In BlockPlanningView
struct ExistingEventBlock: View {
    // ... existing code ...
    @State private var showCategorySheet = false

    var body: some View {
        // existing view
        .onTapGesture {
            showCategorySheet = true
        }
        .sheet(isPresented: $showCategorySheet) {
            EventCategorySheet(event: event, onSave: { category in
                // Call repository.updateEventCategory()
            })
        }
    }
}
```

## Test Plan

### Unit Tests (FocusBloxTests/CalendarEventCategoryTests.swift)

| Test | Description |
|------|-------------|
| `testCategoryParsedFromNotes` | Event with `category:income` returns "income" |
| `testCategoryNilWhenNotInNotes` | Event without category returns nil |
| `testCategoryPreservesOtherNotes` | Update category preserves other notes lines |

### UI Tests (FocusBloxUITests/CalendarCategoryUITests.swift)

| Test | Description |
|------|-------------|
| `testTapOnEventShowsCategorySheet` | Tap on calendar event → sheet appears |
| `testSelectCategorySavesAndDismisses` | Select category → sheet closes, category saved |
| `testEventShowsCategoryIndicator` | Categorized event shows color indicator |

## Affected Files

| File | Change |
|------|--------|
| `Sources/Models/CalendarEvent.swift` | +category property |
| `Sources/Protocols/EventKitRepositoryProtocol.swift` | +updateEventCategory() |
| `Sources/Services/EventKitRepository.swift` | +updateEventCategory() impl |
| `Sources/Testing/MockEventKitRepository.swift` | +mock support |
| `Sources/Views/BlockPlanningView.swift` | +tap gesture, +sheet |
| `Sources/Views/Components/EventCategorySheet.swift` | CREATE |
| `FocusBloxTests/CalendarEventCategoryTests.swift` | CREATE |
| `FocusBloxUITests/CalendarCategoryUITests.swift` | CREATE |

## Acceptance Criteria

- [ ] Tap auf Kalendereintrag öffnet CategorySheet
- [ ] Kategorie-Auswahl speichert in Event notes
- [ ] Kategorisierte Events zeigen Farb-Indikator
- [ ] Unit Tests grün
- [ ] UI Tests grün

## Phase 2 Preview

Nach Phase 1:
- "unbekannt" als 6. Kategorie hinzufügen
- `DailyReviewView.categoryStats` erweitern um Event-Minuten
- Uncategorized Tasks/Events → automatisch "unbekannt"
