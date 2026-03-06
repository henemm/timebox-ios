# TD-02 Paket 3: Shared FocusBlockCardHeader

## Summary

FocusBlockCard Header (Titel, Zeitraum, Dauer-Anzeige) ist auf iOS und macOS identisch. Extraktion in eine Shared View mit optionalem Edit-Button (nur iOS).

## Current State

- iOS: `FocusBlockCard` in `TaskAssignmentView.swift` L357-392 (36 LoC Header)
- macOS: `MacFocusBlockCard` in `MacAssignView.swift` L306-332 (27 LoC Header)
- **19 Zeilen identischer Code** (Title, TimeRange, Duration mit conditional green/red)
- iOS hat zusaetzlich Edit-Button (`pencil.circle`) im Header

## Approach

Parameter-basierte Shared View `FocusBlockCardHeader` mit primitiven Werten (nicht FocusBlock-Objekt), damit PlanItem/LocalTask-Divergenz irrelevant ist.

## Changes

### 1. FocusBlockCardHeader (NEU in SharedSheets.swift)

```swift
struct FocusBlockCardHeader: View {
    let title: String
    let timeRangeText: String
    let totalDuration: Int
    let blockDuration: Int
    var onEdit: (() -> Void)? = nil  // iOS only
}
```

### 2. FocusBlockCard (TaskAssignmentView.swift) — Header ersetzen
### 3. MacFocusBlockCard (MacAssignView.swift) — Header ersetzen

## Affected Files

| File | Change | LoC |
|------|--------|-----|
| Sources/Views/Components/SharedSheets.swift | MODIFY — FocusBlockCardHeader hinzufuegen | +30 |
| Sources/Views/TaskAssignmentView.swift | MODIFY — Header durch Shared View ersetzen | -15 |
| FocusBloxMac/MacAssignView.swift | MODIFY — Header durch Shared View ersetzen | -12 |

**Netto: ~+3 LoC** (Abstraktion kostet, aber eliminiert Duplikation und zentralisiert Aenderungen)

## Acceptance Criteria

1. FocusBlockCardHeader zeigt Titel, Zeitraum, Dauer korrekt
2. Edit-Button erscheint nur wenn onEdit gesetzt (iOS)
3. Remaining-Minutes Logik: gruen wenn frei, rot wenn ueber
4. Build erfolgreich auf iOS UND macOS

## Test Plan

Reine View-Extraktion ohne neue Business-Logik. Build-Validierung genuegt.
