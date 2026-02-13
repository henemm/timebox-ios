---
entity_id: importance_urgency_dedup
type: refactoring
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [backlog-009, dedup, importance, urgency, cross-platform]
---

# BACKLOG-009: Importance/Urgency Badge-Logik deduplizieren

## Approval

- [ ] Approved

## Purpose

23 identische Switch-Statements fuer Importance-Icon/Color/Label und Urgency-Icon/Color/Label in 5 Dateien durch zentrale Helper ersetzen. Keine visuellen Aenderungen.

## Source

- **File:** `Sources/Helpers/TaskMetadataUI.swift` (NEU)
- **Context:** `docs/context/backlog-009-importance-urgency-dedup.md`

## Affected Files

| File | Change | Description |
|------|--------|-------------|
| `Sources/Helpers/TaskMetadataUI.swift` | CREATE | ImportanceUI + UrgencyUI enums |
| `Sources/Views/BacklogRow.swift` | MODIFY | 6 Properties → Helper-Delegation |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | 4 Properties → Helper-Delegation |
| `Sources/Views/QuickCaptureView.swift` | MODIFY | 6 Properties → Helper-Delegation |
| `Sources/Intents/QuickCaptureSnippetView.swift` | MODIFY | 4 Properties → Helper-Delegation |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | 3 Properties → Helper-Delegation |
| `FocusBloxTests/TaskMetadataUITests.swift` | CREATE | Regressions-Tests |

## Implementation Details

### 1. TaskMetadataUI.swift (NEU)

```swift
import SwiftUI

enum ImportanceUI {
    static func icon(for level: Int?) -> String {
        switch level {
        case 3: "exclamationmark.3"
        case 2: "exclamationmark.2"
        case 1: "exclamationmark"
        default: "questionmark"
        }
    }

    static func color(for level: Int?) -> Color {
        switch level {
        case 3: .red
        case 2: .yellow
        case 1: .blue
        default: .gray
        }
    }

    static func label(for level: Int?) -> String {
        switch level {
        case 3: "Hoch"
        case 2: "Mittel"
        case 1: "Niedrig"
        default: "Nicht gesetzt"
        }
    }
}

enum UrgencyUI {
    static func icon(for urgency: String?) -> String {
        switch urgency {
        case "urgent": "flame.fill"
        case "not_urgent": "flame"
        default: "questionmark"
        }
    }

    static func color(for urgency: String?) -> Color {
        switch urgency {
        case "urgent": .orange
        default: .gray
        }
    }

    static func label(for urgency: String?) -> String {
        switch urgency {
        case "urgent": "Dringend"
        case "not_urgent": "Nicht dringend"
        default: "Nicht gesetzt"
        }
    }
}
```

### 2-6. Alle Views: Properties ersetzen

Beispiel BacklogRow.swift vorher:
```swift
private var importanceSFSymbol: String {
    switch item.importance {
    case 3: return "exclamationmark.3"
    ...
    }
}
```

Nachher:
```swift
private var importanceSFSymbol: String {
    ImportanceUI.icon(for: item.importance)
}
```

## Expected Behavior

- **Keine visuellen Aenderungen** — alle Werte sind bereits identisch
- **Side effects:** Keine

## Test Plan

```swift
// ImportanceUI Tests
func test_importanceIcon_allLevels()
func test_importanceColor_allLevels()
func test_importanceLabel_allLevels()
func test_importanceIcon_nilAndZero_returnQuestionmark()

// UrgencyUI Tests
func test_urgencyIcon_allValues()
func test_urgencyColor_allValues()
func test_urgencyLabel_allValues()
func test_urgencyIcon_nilAndDefault_returnQuestionmark()
```

## Scope Assessment

- **Files:** 5 MODIFY + 2 CREATE = 7
- **LoC:** +60 (Helper + Tests) / -100 (Switches) ≈ netto -40
- **Risk:** LOW — keine Logik-Aenderung, alle Werte identisch

## Changelog

- 2026-02-13: Initial spec created
