---
entity_id: MAC-025
type: feature
created: 2026-02-01
status: draft
workflow: macos-nextup-button
---

# MAC-025: Next Up Button in Backlog Row

- [ ] Approved for implementation

## Purpose

"Next Up" Button in der MacBacklogRow, um Tasks direkt als "Next Up" zu markieren - analog zum iOS-Verhalten. Aktuell gibt es nur einen Indicator, aber keinen Button zum Hinzufügen.

## iOS-Referenz

In `Sources/Views/BacklogRow.swift` (Zeile 403-427):
- Button erscheint rechts in der Zeile
- Nur sichtbar wenn Task **noch nicht** "Next Up" ist
- Icon: `arrow.up.circle`
- `accessibilityIdentifier: "nextUpButton_{id}"`

## Scope

**Files:**
- `FocusBloxMac/MacBacklogRow.swift` (MODIFY)

**Estimated:** +25 LoC

## Implementation Details

### 1. Neuer Callback

```swift
struct MacBacklogRow: View {
    // ... existing callbacks ...
    var onAddToNextUp: (() -> Void)?  // NEW
```

### 2. Button in der Row (nach TBD Indicator, vor Next Up Indicator)

```swift
// Next Up Button (only if not already Next Up)
if !task.isNextUp {
    Button {
        onAddToNextUp?()
    } label: {
        Image(systemName: "arrow.up.circle")
            .foregroundStyle(.blue)
            .font(.system(size: 14))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("nextUpButton_\(task.id)")
    .help("Zu Next Up hinzufügen")
}

// Next Up Indicator (existing - shows when already Next Up)
if task.isNextUp {
    Image(systemName: "arrow.up.circle.fill")
        .foregroundStyle(.blue)
        .font(.system(size: 14))
}
```

### 3. Callback-Verwendung in MacBacklogView

```swift
MacBacklogRow(
    task: task,
    onToggleComplete: { ... },
    onAddToNextUp: {
        task.isNextUp = true
        try? modelContext.save()
    }
)
```

## Unterschied iOS vs macOS

| Aspekt | iOS | macOS |
|--------|-----|-------|
| Button-Position | Rechte Spalte, groß (44x44) | Inline, klein (14pt) |
| Entfernen aus Next Up | Swipe Action | Im Inspector |
| Hover-Tooltip | - | `.help()` |

## Test Plan

### UI Tests

```swift
func testNextUpButtonAppearsForNonNextUpTask() {
    // GIVEN: Task ohne Next Up Status
    // WHEN: Row angezeigt
    // THEN: nextUpButton_{id} existiert
}

func testNextUpButtonHiddenForNextUpTask() {
    // GIVEN: Task mit isNextUp == true
    // WHEN: Row angezeigt
    // THEN: nextUpButton_{id} existiert NICHT
    // AND: arrow.up.circle.fill Indicator sichtbar
}

func testTapNextUpButtonMarksTaskAsNextUp() {
    // GIVEN: Task ohne Next Up Status
    // WHEN: Tap auf nextUpButton
    // THEN: Task hat isNextUp == true
    // AND: Button verschwindet, Indicator erscheint
}
```

## Acceptance Criteria

- [ ] "Next Up" Button erscheint nur wenn `isNextUp == false`
- [ ] Tap auf Button setzt `isNextUp = true`
- [ ] Button verschwindet nach Tap, Indicator (filled) erscheint
- [ ] `accessibilityIdentifier: "nextUpButton_{id}"`
- [ ] macOS Tooltip: "Zu Next Up hinzufügen"
- [ ] iOS und macOS Builds erfolgreich

## Dependencies

- MAC-013: Backlog View ✅
