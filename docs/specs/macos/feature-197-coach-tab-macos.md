---
entity_id: feature-197-coach-tab-macos
type: feature
created: 2026-04-03
updated: 2026-04-03
status: draft
version: "1.0"
tags: [macos, coach, navigation, feature-parity]
---

# Coach-Tab für macOS — Feature-Parität mit iOS (#197)

## Approval

- [ ] Approved

## Purpose

Der Coach-Tab (Morning Intention, Tagsüber-Stille, Evening Reflexion) existiert bereits als shared `CoachView.swift` auf iOS, fehlt jedoch vollständig auf macOS. Dieses Feature integriert den Coach-Tab in die macOS-Toolbar-Navigation hinter demselben Feature-Flag wie iOS (`useCoachTabLayout`), sodass beide Plattformen denselben emotionalen Tagesbogen anbieten.

## Motivation

| Problem | Aktuell (macOS) | Nach Feature #197 |
|---------|-----------------|-------------------|
| Kein Coach-Tab auf macOS | Fehlendes Feature, obwohl CoachView shared ist | Coach-Tab in Toolbar-Navigation |
| Feature-Flag-Parität | iOS hat Toggle, macOS nicht | Gleicher `AppStorage`-Key, gleiche Wirkung |
| taskDataChanged fehlt | Intention-Speicherung triggert kein macOS-Refresh | `.taskDataChanged` Notification nach save |
| withSettingsToolbar auf macOS | Crash/falsches Verhalten | `#if os(iOS)` Guard, macOS nutzt Cmd+, |

## Source

- **Neue Datei:** `FocusBloxMacUITests/MacCoachTabLayoutUITests.swift`
- **Geänderte Dateien:**
  - `FocusBloxMac/SidebarView.swift` (`.coach` case + Icon zu `MainSection`)
  - `FocusBloxMac/ContentView.swift` (`@AppStorage`, `visibleSections`, `.coach` case im Switch)
  - `FocusBloxMac/FocusBloxMacApp.swift` (Feature-Flag + Launch-Argument Support)
  - `FocusBloxMac/MacSettingsView.swift` (Toggle für Coach-Tab Layout)
  - `Sources/Views/CoachView.swift` (`.taskDataChanged` Notification + `#if os(iOS)` Toolbar-Guard)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| CoachView | View (shared) | Haupt-View des Coach-Tabs — wird direkt eingebunden |
| MainSection | Enum (`SidebarView.swift`) | Toolbar-Navigation — wird um `.coach` erweitert |
| DayIntention | Model (shared) | Tages-Intention, die im Coach-Tab gesetzt wird |
| IntentionSuggestionService | Service (shared) | AI-Vorschläge für Morning Intention |
| SuccessStoryService | Service (shared) | AI-generierte Abend-Reflexion |
| DayPhase | Enum (shared, in `DayView.swift`) | Bestimmt aktive Tagesphase (morning/daytime/evening) |
| taskDataChanged | Notification | macOS-weites Refresh nach Daten-Mutation |
| AppStorage("useCoachTabLayout") | Feature-Flag | Gleicher Key wie iOS — steuert Coach-Layout |
| coach-tab-layout (iOS Spec) | Spec | `docs/specs/features/coach-tab-layout.md` — Referenz-Implementierung |

## Implementation Details

### 1. MainSection Enum — `.coach` Case

```swift
// FocusBloxMac/SidebarView.swift
enum MainSection: String, Hashable, CaseIterable {
    case backlog  = "Backlog"
    case planning = "Planen"   // Umbenennung wenn Coach aktiv
    case day      = "Tag"
    case focus    = "Focus"
    case review   = "Review"
    case coach    = "Coach"    // NEU

    var icon: String {
        switch self {
        case .backlog:  return "list.bullet"
        case .planning: return "calendar"
        case .day:      return "sun.max"
        case .focus:    return "target"
        case .review:   return "chart.bar"
        case .coach:    return "sparkles"   // NEU
        }
    }
}
```

### 2. ContentView — Feature-Flag + visibleSections

```swift
// FocusBloxMac/ContentView.swift
@AppStorage("useCoachTabLayout") private var useCoachTabLayout = false

private var useCoachLayout: Bool {
    useCoachTabLayout
        || ProcessInfo.processInfo.arguments.contains("--coach-tab-layout")
}

private var visibleSections: [MainSection] {
    if useCoachLayout {
        return [.backlog, .planning, .focus, .coach]
    } else {
        return [.backlog, .planning, .day, .focus, .review]
    }
}
```

Im Body-Switch wird `.coach` auf `CoachView()` gemappt:

```swift
case .coach:
    CoachView()
```

### 3. FocusBloxMacApp — Launch-Argument Support

```swift
// FocusBloxMac/FocusBloxMacApp.swift
// Launch-Argument "--coach-tab-layout" wird in ContentView ausgewertet.
// Kein zusätzlicher Code in App nötig — ProcessInfo wird direkt in ContentView gelesen.
// AppStorage-Key "useCoachTabLayout" wird beim App-Start via Defaults-Injection gesetzt
// wenn der Launch-Argument-Flag gesetzt ist (für UI Tests):
if ProcessInfo.processInfo.arguments.contains("--coach-tab-layout") {
    UserDefaults.standard.set(true, forKey: "useCoachTabLayout")
}
```

### 4. MacSettingsView — Toggle

```swift
// FocusBloxMac/MacSettingsView.swift
@AppStorage("useCoachTabLayout") private var useCoachTabLayout = false

// Im Entwickler-Bereich:
Toggle("Coach-Tab Layout", isOn: $useCoachTabLayout)
```

### 5. CoachView Shared-Fix — taskDataChanged Notification

```swift
// Sources/Views/CoachView.swift — in selectIntention():
try? modelContext.save()
#if os(macOS)
NotificationCenter.default.post(name: .taskDataChanged, object: nil)
#endif
```

### 6. CoachView Shared-Fix — withSettingsToolbar Guard

```swift
// Sources/Views/CoachView.swift — im View body:
// VORHER:
.withSettingsToolbar()
// NACHHER:
#if os(iOS)
.withSettingsToolbar()
#endif
```

### Navigation-Struktur (macOS Coach-Layout)

```
Toolbar (Segmented Picker) — visibleSections:
├── Backlog   → BacklogView
├── Planen    → BlockPlanningView
├── Focus     → FocusLiveView
└── Coach     → CoachView (shared)
               ├── MorningSection (Intention + AI-Vorschläge)
               ├── DaytimeSection (Block-Status)
               └── EveningSection (Timeline + Reflexion)
```

## Expected Behavior

- **Feature-Flag OFF (default):** macOS zeigt klassische 5-Sections wie bisher. Keine sichtbare Änderung.
- **Feature-Flag ON (via Toggle oder `--coach-tab-layout`):** macOS zeigt 4 Sections (Backlog, Planen, Focus, Coach).
- **Coach-Section auswählbar:** Klick auf "Coach" in Toolbar-Picker navigiert zu CoachView.
- **Morning Intention speichern:** Änderungen triggern `taskDataChanged` Notification, ContentView refresht.
- **Tagsüber:** Block-Status und erledigte Tasks werden korrekt angezeigt.
- **Abends:** Success Story und Timeline erscheinen in CoachView.
- **Rückgängig:** MacSettings → "Coach-Tab Layout" Toggle aus → sofort 5 Sections.
- **withSettingsToolbar:** Wird auf macOS nicht aufgerufen — kein Crash, macOS nutzt Cmd+, für Settings.

## Known Limitations

- Coach-Tab auf macOS ist ein **Prototyp** zur Feature-Parität — identisch mit iOS-Prototyp-Status
- CoachView ist shared und auf macOS-Fenstergrössen nicht vollständig optimiert (Scrolling funktioniert, Layout ggf. suboptimal)
- Auto-Scroll zur aktuellen Tagesphase (aus iOS CoachView) funktioniert auf macOS identisch — kein macOS-spezifisches Tuning
- Keine Sidebar-Navigation (macOS nutzt Toolbar Segmented Picker, keine echte Sidebar)

## Test Plan

**UI Tests:** `FocusBloxMacUITests/MacCoachTabLayoutUITests.swift` (~80 LoC)

| Test | Beschreibung | Erwartetes Ergebnis |
|------|-------------|---------------------|
| `testCoachSectionAppearsWithFlag` | App mit `--coach-tab-layout` starten | "Coach" erscheint im Toolbar-Picker |
| `testCoachSectionNotVisibleWithoutFlag` | App ohne Flag starten | "Coach" erscheint NICHT im Picker |
| `testNavigateToCoachSection` | Coach in Toolbar antippen | CoachView wird angezeigt |
| `testClassicSectionsWithoutFlag` | Ohne Flag: Sections prüfen | Tag + Review sichtbar, Coach nicht |
| `testSettingsToggleEnablesCoach` | Toggle in Settings aktivieren | Coach-Section erscheint sofort |

**TDD RED:** Tests werden VOR Implementation geschrieben und fehlschlagen.
**TDD GREEN:** Tests bestehen nach vollständiger Implementation.

## Changelog

- 2026-04-03: Initial spec created (Feature-Parität iOS → macOS)
