---
entity_id: category_switches_dedup
type: refactoring
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [backlog-008, dedup, category, cross-platform]
---

# BACKLOG-008: Hardcoded Category-Switches durch TaskCategory ersetzen

## Approval

- [ ] Approved

## Purpose

Verbleibende hardcoded category switch-Statements in 3 Dateien durch Delegation an das zentrale `TaskCategory` Enum ersetzen. Zusaetzlich `.localizedName` Property zum Enum hinzufuegen, um deutsche Kategorie-Labels zentral zu pflegen. Beseitigt Inkonsistenzen bei Icons und Farben in QuickCaptureSnippetView und CategoryBadge.

## Source

- **Enum:** `Sources/Models/TaskCategory.swift` — Single Source of Truth
- **Context:** `docs/context/backlog-008-category-hardcoded-switches.md`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `TaskCategory` | Enum | Zentrale Kategorie-Definition (color, icon, displayName) |
| `CategoryBadge` | View (macOS) | Standalone Badge in MacBacklogRow, genutzt von MacAssignView + MacPlanningView |
| `QuickCaptureSnippetView` | View (iOS) | Siri/Spotlight Interactive Snippet |
| `TaskFormSheet` | View (iOS) | Task-Erstellungs-Formular |

## Affected Files

| File | Change | Description |
|------|--------|-------------|
| `Sources/Models/TaskCategory.swift` | MODIFY | Neue Property `localizedName` hinzufuegen |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | `categoryColor(for:)` Funktion → Einzeiler mit TaskCategory |
| `Sources/Intents/QuickCaptureSnippetView.swift` | MODIFY | `categoryIcon` + `categoryColor` → TaskCategory Lookup |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | CategoryBadge: 3 Switches → TaskCategory Lookup |
| `FocusBloxTests/TaskCategoryTests.swift` | CREATE | Regressions-Tests |

## Implementation Details

### 1. TaskCategory.swift — Neue Property

```swift
var localizedName: String {
    switch self {
    case .income: "Geld"
    case .essentials: "Pflege"
    case .selfCare: "Energie"
    case .learn: "Lernen"
    case .social: "Geben"
    }
}
```

### 2. TaskFormSheet.swift — categoryColor ersetzen

**Vorher (Z.329-338):**
```swift
private func categoryColor(for type: String) -> Color {
    switch type {
    case "income": return .green
    case "maintenance": return .orange
    case "recharge": return .cyan
    case "learning": return .purple
    case "giving_back": return .pink
    default: return .gray
    }
}
```

**Nachher:**
```swift
private func categoryColor(for type: String) -> Color {
    TaskCategory(rawValue: type)?.color ?? .gray
}
```

### 3. QuickCaptureSnippetView.swift — 2 Switches ersetzen

**Vorher (Z.121-141):** Hardcoded switches mit abweichenden Werten
**Nachher:**
```swift
private var categoryIcon: String {
    TaskCategory(rawValue: state.taskType)?.icon ?? "folder"
}

private var categoryColor: Color {
    TaskCategory(rawValue: state.taskType)?.color ?? .gray
}
```

### 4. CategoryBadge (MacBacklogRow.swift) — 3 Switches ersetzen

**Vorher (Z.346-377):** 3 separate Switches fuer color, icon, label
**Nachher:**
```swift
private var color: Color {
    TaskCategory(rawValue: taskType)?.color ?? .gray
}

private var icon: String {
    TaskCategory(rawValue: taskType)?.icon ?? "questionmark.circle"
}

private var label: String {
    TaskCategory(rawValue: taskType)?.localizedName ?? "Typ"
}
```

## Expected Behavior

- **Input:** rawValue String (z.B. "income", "maintenance")
- **Output:** Identische Farben/Icons wie bisher in TaskFormSheet; korrigierte Farben/Icons in SnippetView und CategoryBadge
- **Side effects:**
  - QuickCaptureSnippetView: 3 Icons und 3 Farben aendern sich (Konsistenz-Fix)
  - CategoryBadge: 2 Icons aendern sich (heart.circle statt battery.100, person.2 statt gift)

### Visuelle Aenderungen (User-sichtbar)

| Stelle | Property | Vorher | Nachher |
|--------|----------|--------|---------|
| SnippetView | maintenance icon | wrench | wrench.and.screwdriver.fill |
| SnippetView | maintenance color | .blue | .orange |
| SnippetView | recharge icon | heart | heart.circle |
| SnippetView | recharge color | .pink | .cyan |
| SnippetView | giving_back icon | hand.raised | person.2 |
| SnippetView | giving_back color | .orange | .pink |
| CategoryBadge | recharge icon | battery.100 | heart.circle |
| CategoryBadge | giving_back icon | gift | person.2 |

## Test Plan

### Regressions-Tests (FocusBloxTests/TaskCategoryTests.swift)

```swift
// 1. Alle 5 rawValues korrekt aufloesen
func test_allRawValues_resolveCorrectly()

// 2. color Property korrekte Werte
func test_color_returnsExpectedValues()

// 3. icon Property korrekte Werte
func test_icon_returnsExpectedValues()

// 4. displayName Property korrekte Werte
func test_displayName_returnsExpectedValues()

// 5. localizedName Property korrekte deutsche Werte
func test_localizedName_returnsGermanLabels()

// 6. Unbekannter rawValue ergibt nil
func test_unknownRawValue_returnsNil()
```

## Scope Assessment

- **Files:** 4 MODIFY + 1 CREATE
- **LoC:** +40 (Tests + localizedName) / -50 (Switches) ≈ netto -10
- **Risk:** LOW — reine Delegation an bestehendes Enum
- **Build-Validation:** iOS + macOS Targets

## Known Limitations

- `BacklogView.swift` hat eine separate `localizedCategory` Extension mit veralteten Kategorien — separates Backlog-Item, nicht in Scope
- `displayName` bleibt Englisch (Earn, Essentials, etc.) — wird in BacklogRow/QuickCaptureView bereits so angezeigt

## Changelog

- 2026-02-13: Initial spec created
