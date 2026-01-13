---
entity_id: step4-duration-editing
type: feature
created: 2026-01-13
status: draft
workflow: step4-duration-editing
---

# Step 4: Duration Editing

## Approval

- [x] Approved for implementation

## Purpose

Manuelle Dauer-Auswahl fuer Tasks via vordefinierte Optionen (5, 15, 30, 60 Minuten). Tap auf DurationBadge oeffnet Picker-Sheet.

## Scope

| File | Change | Description |
|------|--------|-------------|
| `Views/DurationPicker.swift` | CREATE | Picker mit 4 Buttons + Reset |
| `Views/DurationBadge.swift` | MODIFY | Optional onTap callback |
| `Views/BacklogRow.swift` | MODIFY | onDurationTap weiterleiten |
| `Views/BacklogView.swift` | MODIFY | Sheet-State, updateDuration |
| `Services/SyncEngine.swift` | MODIFY | updateDuration() Methode |

**Estimated:** +90 LoC

## Implementation Details

### 1. DurationPicker (neu)

```swift
struct DurationPicker: View {
    let currentDuration: Int
    let onSelect: (Int?) -> Void  // nil = Reset

    private let options = [5, 15, 30, 60]

    var body: some View {
        VStack(spacing: 16) {
            Text("Dauer waehlen")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(options, id: \.self) { minutes in
                    Button("\(minutes)m") {
                        onSelect(minutes)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(minutes == currentDuration ? .blue : .gray)
                }
            }

            Button("Zuruecksetzen") {
                onSelect(nil)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .presentationDetents([.height(180)])
    }
}
```

### 2. DurationBadge (erweitert)

```swift
struct DurationBadge: View {
    let minutes: Int
    let isDefault: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        Text("\(minutes)m")
            // ... existing styling ...
            .onTapGesture {
                onTap?()
            }
    }
}
```

### 3. BacklogRow (erweitert)

```swift
struct BacklogRow: View {
    let item: PlanItem
    var onDurationTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            // ... existing ...
            DurationBadge(
                minutes: item.effectiveDuration,
                isDefault: item.durationSource == .default,
                onTap: onDurationTap
            )
        }
    }
}
```

### 4. BacklogView (erweitert)

```swift
@State private var selectedItemForDuration: PlanItem?

// In List ForEach:
BacklogRow(item: item) {
    selectedItemForDuration = item
}

// Sheet:
.sheet(item: $selectedItemForDuration) { item in
    DurationPicker(currentDuration: item.effectiveDuration) { newDuration in
        updateDuration(for: item, minutes: newDuration)
        selectedItemForDuration = nil
    }
}
```

### 5. SyncEngine.updateDuration()

```swift
func updateDuration(itemID: String, minutes: Int?) throws {
    let allMetadata = try fetchAllMetadata()
    guard let metadata = allMetadata.first(where: { $0.reminderID == itemID }) else {
        return
    }
    metadata.manualDuration = minutes
    try modelContext.save()
}
```

## Test Plan

### Unit Tests (TDD RED)

1. **SyncEngine.updateDuration():**
   - GIVEN: TaskMetadata exists
   - WHEN: updateDuration(itemID, 30)
   - THEN: manualDuration == 30

2. **SyncEngine.updateDuration() Reset:**
   - GIVEN: TaskMetadata with manualDuration == 30
   - WHEN: updateDuration(itemID, nil)
   - THEN: manualDuration == nil

### UI Tests

1. **DurationBadge tappable:**
   - GIVEN: BacklogView with tasks
   - WHEN: Tap on DurationBadge
   - THEN: Sheet appears

2. **Duration selection:**
   - GIVEN: DurationPicker sheet open
   - WHEN: Tap "30m" button
   - THEN: Sheet closes, badge shows "30m"

## Acceptance Criteria

- [x] Tap auf DurationBadge oeffnet Picker-Sheet
- [x] 4 vordefinierte Optionen: 5m, 15m, 30m, 60m
- [x] Reset-Option setzt auf Default/Parsed zurueck
- [x] Aenderung wird in SwiftData persistiert
- [x] Badge-Farbe: gelb (default), blau (manual/parsed)
- [x] Haptisches Feedback bei Auswahl

## Changelog

- 2026-01-13: Initial spec created
