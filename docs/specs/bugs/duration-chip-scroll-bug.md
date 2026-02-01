# Bug Fix: Duration Chip Scroll Jump

## Problem

Wenn der User auf einen Dauer-Chip tippt, scrollt die Backlog-Liste nach oben bevor der DurationPicker Sheet öffnet.

## Root Cause

**Nested ScrollViews verursachen Fokus-/Scroll-Konflikte:**

1. `BacklogView.listView` verwendet `ScrollView` (vertikal)
2. `BacklogRow.metadataRow` verwendet `ScrollView(.horizontal)`
3. Button-Tap im nested ScrollView triggert unerwünschtes Scroll-Verhalten

## Lösung

Horizontalen ScrollView in `metadataRow` durch einfachen `HStack` ersetzen.

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/BacklogRow.swift` | `ScrollView(.horizontal)` → `HStack` |

## Implementation

### Vorher (Zeile 127-128):
```swift
private var metadataRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
            // badges...
        }
    }
}
```

### Nachher:
```swift
private var metadataRow: some View {
    HStack(spacing: 6) {
        // badges...
    }
}
```

## Scope

- **Dateien:** 1
- **LoC:** ~3 (nur ScrollView Wrapper entfernen)
- **Risiko:** Niedrig

## Akzeptanzkriterien

1. [x] Duration-Chip Tap öffnet DurationPicker ohne Scroll-Jump
2. [x] Andere Chips (Importance, Urgency, Category) funktionieren weiterhin
3. [x] Alle Badges bleiben sichtbar und tappable
4. [x] UI Tests für Duration-Tap bestehen

## Test Plan

### UI Test
```swift
func testDurationChipDoesNotScrollList() {
    // 1. Scroll zu Task in der Mitte der Liste
    // 2. Tap auf Duration-Chip
    // 3. Verify: Liste hat nicht gescrollt (Task noch sichtbar)
    // 4. Picker Sheet ist offen
}
```
