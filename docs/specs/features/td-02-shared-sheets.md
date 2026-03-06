# TD-02 Paket 2: Shared Sheet Components

## Summary

CreateFocusBlockSheet und EventCategorySheet existieren als Duplikate auf iOS und macOS mit ~85-90% identischer Logik. Unification in Shared-Code nach dem Muster von EditFocusBlockSheet (`#if os(iOS)` fuer plattform-spezifische Presentation).

## Current State

| Sheet | iOS | macOS | Identisch |
|-------|-----|-------|-----------|
| CreateFocusBlockSheet | BlockPlanningView.swift L720-790 (71 LoC) | MacPlanningView.swift L600-659 (60 LoC) | ~90% |
| EventCategorySheet | BlockPlanningView.swift L947-1008 (62 LoC) | MacPlanningView.swift L522-596 (75 LoC) | ~85% |

### Unterschiede (nur Presentation)

**CreateFocusBlockSheet:**
- iOS: `NavigationStack` + `Form` + `.toolbar` + `.presentationDetents([.medium])`
- macOS: `VStack` + `Form` + `.formStyle(.grouped)` + inline `HStack` Buttons + `.frame(width:height:)` + `.keyboardShortcut`
- Logik (DatePicker, onChange, durationText, snapToQuarterHour): **100% identisch**

**EventCategorySheet:**
- iOS: `NavigationStack` + `List` + `.toolbar` + `.presentationDetents([.medium])`
- macOS: `VStack` + custom Buttons + `.buttonStyle(.plain)` + `.frame(width:)` + `.keyboardShortcut`
- Logik (ForEach TaskCategory, checkmark, clear category): **100% identisch**

## Approach

Folge dem EditFocusBlockSheet-Muster:
- Shared View mit `#if os(iOS)` / `#else` Branching fuer Container und Buttons
- macOS-spezifische Sheet-Structs (`MacCreateFocusBlockSheet`, `MacEventCategorySheet`) entfernen
- Call-Sites in MacPlanningView aktualisieren (Mac-Prefix entfernen)

## Changes

### 1. CreateFocusBlockSheet → Shared (Sources/Views/BlockPlanningView.swift)

Die iOS-Version wird zur Shared-Version erweitert:
- `NavigationStack` + `.toolbar` nur auf iOS
- `VStack` + inline Buttons + `.keyboardShortcut` auf macOS
- `.presentationDetents` nur auf iOS
- `durationText` bleibt identisch

### 2. EventCategorySheet → Shared (Sources/Views/BlockPlanningView.swift)

Die iOS-Version wird zur Shared-Version erweitert:
- `NavigationStack` + `List` + `.toolbar` nur auf iOS
- `VStack` + custom Buttons auf macOS
- `.presentationDetents` nur auf iOS

### 3. MacPlanningView.swift — Duplikate entfernen

- `MacCreateFocusBlockSheet` struct entfernen (~60 LoC)
- `MacEventCategorySheet` struct entfernen (~75 LoC)
- Call-Sites: `MacCreateFocusBlockSheet(` → `CreateFocusBlockSheet(`
- Call-Sites: `MacEventCategorySheet(` → `EventCategorySheet(`

## Affected Files

| File | Change | LoC |
|------|--------|-----|
| Sources/Views/BlockPlanningView.swift | MODIFY — Platform branching in beide Sheets | +30 |
| FocusBloxMac/MacPlanningView.swift | MODIFY — Mac-Sheets entfernen, Call-Sites umbenennen | -135 |

**Netto: ~-105 LoC Duplikation eliminiert**

## Acceptance Criteria

1. CreateFocusBlockSheet funktioniert auf iOS (NavigationStack, toolbar, detents)
2. CreateFocusBlockSheet funktioniert auf macOS (VStack, inline buttons, keyboardShortcut, frame)
3. EventCategorySheet funktioniert auf iOS (NavigationStack, List, toolbar, detents)
4. EventCategorySheet funktioniert auf macOS (VStack, custom buttons, keyboardShortcut, frame)
5. MacCreateFocusBlockSheet und MacEventCategorySheet existieren nicht mehr
6. Build erfolgreich auf iOS UND macOS
7. Keine Verhaltensaenderung auf beiden Plattformen

## Test Plan

### Unit Tests (nicht noetig)
Reine View-Refactoring ohne Business-Logik-Aenderung. Keine neuen Funktionen.

### UI Tests
- `testCreateFocusBlockSheetOpens` — Sheet oeffnet sich nach Tap auf freien Slot
- `testEventCategorySheetOpens` — Sheet oeffnet sich nach Tap auf Event
- `testCreateFocusBlockSheetHasDatePickers` — Start/Ende DatePicker vorhanden
- `testEventCategorySheetShowsAllCategories` — Alle 5 Kategorien sichtbar
