# Context: macOS Sync + UI Alignment

## Request Summary

Drei Fixes für die macOS App:
1. **Sync kaputt** - Sandbox deaktiviert, daher keine App Group Sync mit iOS
2. **Kaputte Chips** - Kategorie-Text vertikal statt horizontal
3. **UI-Alignment** - macOS weicht stark von iOS ab (fehlende Badges, Interaktivität)

## Analysis

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/FocusBloxMac.entitlements` | MODIFY | Sandbox aktivieren für App Group |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | iOS-aligned Badges mit Interaktivität |
| `FocusBloxMac/TaskInspector.swift` | MODIFY | Chip-basierte Controls |
| `FocusBloxMac/SidebarView.swift` | MODIFY | Navigation + alle 10 Kategorien |
| `FocusBloxMac/ContentView.swift` | MODIFY | Bereich-Navigation |
| `FocusBloxMac/Assets.xcassets/AppIcon.appiconset/*` | CREATE | macOS App Icon |
| `FocusBloxMacUITests/MacSyncUIAlignmentUITests.swift` | CREATE | UI Tests für alle Features |

### Scope Assessment
- Files: 7 (6 modify + 1 create für Tests)
- Estimated LoC: +400 / -100
- Risk Level: MEDIUM (Sandbox-Änderung kann Permissions beeinflussen)

### Technical Approach

**1. Sync Fix (kritisch)**
- `com.apple.security.app-sandbox` von `false` auf `true`
- App Group `group.com.henning.focusblox` bereits konfiguriert

**2. Badge Layout Fix**
- `fixedSize()` auf allen Badge-Views
- HStack mit explizitem spacing

**3. UI Alignment**
- MacBacklogRow: Interaktive Badges wie iOS (tappable, cycling)
- TaskInspector: Chip-basierte Controls statt Form-Picker
- SidebarView: Bereiche (Backlog/Planen/Review) + Filter + 10 Kategorien
- ContentView: Navigation zwischen Bereichen

### Accessibility Identifiers (für UI Tests)

**MacBacklogRow:**
- `completeButton_{task.id}`
- `importanceBadge_{task.id}`
- `urgencyBadge_{task.id}`
- `categoryBadge_{task.id}`
- `durationBadge_{task.id}`

**SidebarView:**
- `sidebarSection_backlog`, `sidebarSection_planning`, `sidebarSection_review`
- `sidebarFilter_all`, `sidebarFilter_nextUp`, `sidebarFilter_tbd`
- `sidebarCategory_{id}`

**TaskInspector:**
- `importanceChip_{level}` (1, 2, 3)
- `urgencyChip_{value}` (nil, not_urgent, urgent)
- `durationChip_{minutes}` (15, 30, 45, 60, 90, 120)
- `categoryChip_{id}`
- `statusChip_completed`, `statusChip_nextUp`

### Open Questions
- [x] Sync über App Group? → Ja, bereits konfiguriert
- [x] Timeline als eigener Bereich? → Nein, Teil von Planning

## Related Files

| File | Relevance |
|------|-----------|
| `FocusBloxMac/FocusBloxMac.entitlements` | Sandbox-Setting für App Group Sync |
| `FocusBloxMac/MacBacklogRow.swift` | Task-Row mit Badges (muss iOS angleichen) |
| `FocusBloxMac/TaskInspector.swift` | Edit-Dialog (Form-basiert → Chip-basiert) |
| `FocusBloxMac/SidebarView.swift` | Navigation zwischen Bereichen |
| `FocusBloxMac/ContentView.swift` | Hauptansicht mit Navigation |
| `Sources/Views/BacklogRow.swift` | iOS-Referenz für Badge-Styling |
| `FocusBloxMacUITests/FocusBloxMacUITests.swift` | Bestehende UI Tests |

## Existing Patterns

### iOS BacklogRow Badge-Pattern
```swift
// Importance Badge - tappable, cycles 1 → 2 → 3 → 1
Button {
    let next = current >= 3 ? 1 : current + 1
    onImportanceCycle?(next)
} label: {
    Image(systemName: importanceSFSymbol)
        .font(.system(size: 14))
        .foregroundStyle(importanceColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(importanceColor.opacity(0.2))
        )
}
.buttonStyle(.plain)
.fixedSize()
.accessibilityIdentifier("importanceBadge_\(item.id)")
```

### iOS Urgency Badge-Pattern
```swift
// Urgency Badge - tappable, cycles: nil → not_urgent → urgent → nil
Button { ... } label: {
    Image(systemName: urgencyIcon) // flame.fill / flame / questionmark
        .foregroundStyle(urgencyColor) // orange / gray
        .background(RoundedRectangle...)
}
.accessibilityIdentifier("urgencyBadge_\(item.id)")
```

### iOS 10 Kategorien
```swift
case "income": "Geld", "dollarsign.circle", .green
case "maintenance": "Pflege", "wrench.and.screwdriver.fill", .orange
case "recharge": "Energie", "battery.100", .cyan
case "learning": "Lernen", "book", .purple
case "giving_back": "Geben", "gift", .pink
case "deep_work": "Deep Work", "brain", .indigo
case "shallow_work": "Shallow", "tray", .gray
case "meetings": "Meeting", "person.2", .teal
case "creative": "Kreativ", "paintbrush", .mint
case "strategic": "Strategie", "lightbulb", .yellow
```

## Dependencies

### Upstream
- `LocalTask` Model - gemeinsam mit iOS
- App Group Container (`group.com.henning.focusblox`)
- SwiftData ModelContainer

### Downstream
- MacPlanningView verwendet MacBacklogRow/CategoryBadge
- MacReviewView verwendet Task-Daten

## Existing Specs

- `docs/specs/macos/MAC-013-backlog-view.md` - Basis-Spec für Backlog View

## Risks & Considerations

1. **Sandbox-Aktivierung** kann die App vorübergehend nicht startbar machen (Permissions)
2. **Breaking Change** bei CategoryBadge wenn andere Views es nutzen
3. **UI Tests für macOS** müssen accessibility identifiers verwenden
4. **Chip-Layout** muss `fixedSize()` haben um horizontale Darstellung zu erzwingen

## Implementation Summary (bereits implementiert)

### Fix 1: Sync
- `FocusBloxMac.entitlements`: `com.apple.security.app-sandbox` → `true`

### Fix 2: Chip Layout
- `MacBacklogRow.swift`: `fixedSize()` auf allen Badges

### Fix 3: UI-Alignment
- `MacBacklogRow.swift`: Interaktive Badges (Importance, Urgency, Category, Duration, Due Date)
- `TaskInspector.swift`: Chip-basierte Controls statt Picker/Toggle
- `SidebarView.swift`: Navigation (Backlog, Planen, Review) + alle 10 Kategorien
- `ContentView.swift`: Bereich-basierte Navigation

## Tests benötigt

Da Implementation bereits erfolgt, müssen nachträglich UI Tests geschrieben werden:

1. **Sidebar Navigation Tests**
   - Bereiche (Backlog, Planen, Review) klickbar
   - Filter bei Backlog sichtbar

2. **MacBacklogRow Badge Tests**
   - Importance Badge tappable, cycled
   - Urgency Badge tappable, cycled
   - Category Badge tappable
   - Duration Badge tappable

3. **TaskInspector Chip Tests**
   - Importance Chips auswählbar
   - Urgency Chips auswählbar
   - Duration Chips auswählbar
   - Category Grid auswählbar
