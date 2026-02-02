---
entity_id: MAC-024
type: feature
created: 2026-02-01
status: draft
workflow: macos-sync-ui-alignment
---

# MAC-024: macOS Sync + UI Alignment

- [ ] Approved for implementation

## Purpose

Drei kritische Fixes für die macOS App:
1. **Sync aktivieren** - Sandbox war deaktiviert, App Group Sync mit iOS funktionierte nicht
2. **Chip Layout fixen** - Kategorie-Text wurde vertikal statt horizontal angezeigt
3. **UI an iOS angleichen** - Interaktive Badges, Chip-basierter Inspector, Navigation

## Scope

**Files:**
- `FocusBloxMac/FocusBloxMac.entitlements` (MODIFY - 1 Zeile)
- `FocusBloxMac/MacBacklogRow.swift` (MODIFY - ~200 LoC)
- `FocusBloxMac/TaskInspector.swift` (MODIFY - ~300 LoC)
- `FocusBloxMac/SidebarView.swift` (MODIFY - ~100 LoC)
- `FocusBloxMac/ContentView.swift` (MODIFY - ~50 LoC)
- `FocusBloxMac/Assets.xcassets/AppIcon.appiconset/*` (CREATE - Icons)
- `FocusBloxMacUITests/MacSyncUIAlignmentUITests.swift` (CREATE - Tests)

**Estimated:** +450 / -100 LoC

## Implementation Details

### 1. Sync Fix (kritisch)

```xml
<!-- FocusBloxMac.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>  <!-- war false -->
```

### 2. MacBacklogRow - Interaktive Badges

```swift
struct MacBacklogRow: View {
    var onImportanceCycle: ((Int) -> Void)?
    var onUrgencyToggle: ((String?) -> Void)?
    var onCategoryTap: (() -> Void)?
    var onDurationTap: (() -> Void)?

    // Metadata Row mit tappbaren Badges
    private var metadataRow: some View {
        HStack(spacing: 6) {
            importanceBadge   // cycles 1→2→3→1
            urgencyBadge      // cycles nil→not_urgent→urgent→nil
            categoryBadge     // cycles durch 10 Kategorien
            durationBadge     // cycles 15→30→45→60→90→120
            dueDateBadge      // read-only
        }
    }
}
```

### 3. TaskInspector - Chip Controls

```swift
struct TaskInspector: View {
    // Importance: 3 tappbare Chips
    HStack {
        importanceChip(1)  // Niedrig, blau
        importanceChip(2)  // Mittel, gelb
        importanceChip(3)  // Hoch, rot
    }

    // Urgency: 3 tappbare Chips
    HStack {
        urgencyChip(nil, "Ungesetzt")
        urgencyChip("not_urgent", "Nicht dringend")
        urgencyChip("urgent", "Dringend")
    }

    // Duration: 6 Preset-Chips
    HStack {
        ForEach([15, 30, 45, 60, 90, 120]) { durationChip($0) }
    }

    // Category: 5x2 Grid
    LazyVGrid(columns: 5) {
        categoryChip("income", ...)
        // ... 10 Kategorien
    }
}
```

### 4. SidebarView - Navigation

```swift
enum MainSection: CaseIterable {
    case backlog, planning, review
}

struct SidebarView: View {
    @Binding var selectedSection: MainSection
    @Binding var selectedFilter: SidebarFilter

    // Bereiche (immer sichtbar)
    Section("Bereiche") { ... }

    // Filter (nur bei Backlog)
    if selectedSection == .backlog {
        Section("Filter") { ... }
        Section("Kategorien") { ... }  // alle 10
    }
}
```

## Test Plan

### Automated UI Tests (TDD RED → GREEN)

**Sidebar Navigation Tests:**
- [ ] Test 1: GIVEN app launched WHEN sidebar visible THEN Backlog/Planen/Review sections exist
- [ ] Test 2: GIVEN Backlog selected WHEN tap Planning THEN Planning view shows
- [ ] Test 3: GIVEN Backlog selected THEN Filter section visible with All/NextUp/TBD
- [ ] Test 4: GIVEN Planning selected THEN Filter section NOT visible

**MacBacklogRow Badge Tests:**
- [ ] Test 5: GIVEN task in list THEN importanceBadge_{id} exists
- [ ] Test 6: GIVEN task in list THEN urgencyBadge_{id} exists
- [ ] Test 7: GIVEN task in list THEN categoryBadge_{id} exists
- [ ] Test 8: GIVEN task in list THEN durationBadge_{id} exists

**TaskInspector Chip Tests:**
- [ ] Test 9: GIVEN task selected THEN importance chips (Niedrig/Mittel/Hoch) visible
- [ ] Test 10: GIVEN task selected THEN urgency chips visible
- [ ] Test 11: GIVEN task selected THEN duration chips (15m-120m) visible
- [ ] Test 12: GIVEN task selected THEN category grid (10 items) visible

### Manual Verification
- [ ] macOS App startet nach Sandbox-Aktivierung
- [ ] Tasks von iOS erscheinen in macOS
- [ ] Neue Tasks in macOS erscheinen in iOS
- [ ] Badges horizontal lesbar (nicht vertikal)

## Acceptance Criteria

- [ ] Sandbox aktiviert (`com.apple.security.app-sandbox = true`)
- [ ] Tasks synchronisieren zwischen iOS und macOS
- [ ] Sidebar zeigt 3 Bereiche (Backlog, Planen, Review)
- [ ] Backlog zeigt Filter + 10 Kategorien
- [ ] MacBacklogRow: 4 interaktive Badges (Importance, Urgency, Category, Duration)
- [ ] TaskInspector: Chip-basierte Controls statt Picker
- [ ] Alle UI Tests GRÜN
- [ ] macOS und iOS Builds erfolgreich

## Accessibility Identifiers

| Element | Identifier |
|---------|------------|
| Sidebar Bereiche | `sidebarSection_{backlog\|planning\|review}` |
| Sidebar Filter | `sidebarFilter_{all\|nextUp\|tbd}` |
| Sidebar Kategorien | `sidebarCategory_{id}` |
| Importance Badge | `importanceBadge_{task.id}` |
| Urgency Badge | `urgencyBadge_{task.id}` |
| Category Badge | `categoryBadge_{task.id}` |
| Duration Badge | `durationBadge_{task.id}` |
| Inspector Importance Chip | `importanceChip_{1\|2\|3}` |
| Inspector Urgency Chip | `urgencyChip_{nil\|not_urgent\|urgent}` |
| Inspector Duration Chip | `durationChip_{15\|30\|45\|60\|90\|120}` |
| Inspector Category Chip | `categoryChip_{id}` |

## Dependencies

- MAC-013: Backlog View (Basis)
- App Group: `group.com.henning.focusblox`

## Out of Scope

- Drag & Drop zwischen Views
- Timeline als eigenständiger Bereich (ist Teil von Planning)
