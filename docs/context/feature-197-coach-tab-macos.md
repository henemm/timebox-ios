# Context: Coach-Tab für macOS (#197)

## Request Summary
Feature-Parität: Der Coach-Tab (Morning Intention, Tagsüber-Stille, Evening Reflexion) soll auch auf macOS verfügbar sein. CoachView ist bereits shared Code — es fehlt die Integration in die macOS Sidebar/Toolbar-Navigation.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxMac/SidebarView.swift` | `MainSection` enum — braucht neuen `case coach` |
| `FocusBloxMac/ContentView.swift` | `mainContentView` Switch — muss `CoachView()` einbinden |
| `FocusBloxMac/FocusBloxMacApp.swift` | Feature-Flag `useCoachTabLayout` Handling |
| `Sources/Views/CoachView.swift` | Shared View — KEINE `#if os()` Blöcke, komplett plattformübergreifend |
| `Sources/Views/MainTabView.swift` | iOS Coach-Layout: 4 Tabs (Backlog, Planen, Focus, Coach) |
| `Sources/FocusBloxApp.swift` | iOS Feature-Flag Definition (`@AppStorage("useCoachTabLayout")`) |
| `Sources/Models/DayIntention.swift` | Shared Model — bereits verfügbar |
| `Sources/Services/IntentionSuggestionService.swift` | Shared AI Service — bereits verfügbar |
| `Sources/Services/SuccessStoryService.swift` | Shared Service — bereits verfügbar |
| `Sources/Views/SuccessStoryView.swift` | Shared View — keine `#if os()` Blöcke |
| `FocusBloxMac/MacSettingsView.swift` | macOS Settings — braucht ggf. Toggle für Feature-Flag |

## Existing Patterns

### iOS Coach-Layout (Feature-Flag gesteuert)
- **Flag aus:** 5 Tabs (Backlog, Blox, Tag, Focus, Review)
- **Flag an:** 4 Tabs (Backlog, Planen, Focus, Coach)
- Umschalten per `@AppStorage("useCoachTabLayout")` oder Launch-Argument `--coach-tab-layout`

### macOS Navigation
- `MainSection` enum mit 5 Cases: backlog, planning, day, focus, review
- Segmented Picker in Toolbar (`mainNavigationPicker`)
- `mainContentView` Switch dispatcht zu Views
- Sidebar nur bei `selectedSection == .backlog`

### macOS Shared Views
- `DayView` wird bereits direkt aus Shared-Code genutzt (kein Mac-Wrapper)
- Andere Views (`MacPlanningView`, `MacFocusView`, `MacReviewView`) sind macOS-spezifisch
- Pattern: Shared Views direkt nutzen, nur bei Bedarf macOS-Wrapper

### taskDataChanged Notification
- macOS Views müssen nach Task-Mutations `.taskDataChanged` posten
- CoachView mutiert Tasks (Intention setzen) → muss Notification posten

## Dependencies
- **Upstream:** CoachView nutzt `DayIntention`, `IntentionSuggestionService`, `SuccessStoryService`, `DayPhase`
- **Downstream:** macOS ContentView/SidebarView müssen neuen Section kennen

## Existing Specs
- `docs/specs/features/coach-tab-layout.md` — Feature-Spec für Coach-Tab (iOS)

## Risks & Considerations
1. **Feature-Flag Symmetrie:** macOS braucht dasselbe Toggle-Verhalten (4 vs 5 Sections)
2. **taskDataChanged:** CoachView setzt Intentions — muss Notification posten für macOS Refresh
3. **Segmented Picker:** 4-5 Sections in segmented Picker — UI muss passen
4. **SettingsView:** macOS Settings braucht Coach-Tab Toggle (falls noch nicht vorhanden)
5. **`#if os()` in CoachView:** `.withSettingsToolbar()` nutzt iOS-only `.topBarTrailing` — braucht `#if os(iOS)` Guard

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/SidebarView.swift` | MODIFY | `.coach` case + icon zu `MainSection` enum (+5 LoC) |
| `FocusBloxMac/ContentView.swift` | MODIFY | `@AppStorage`, `visibleSections`, `.coach` case in switch (+15 LoC) |
| `FocusBloxMac/FocusBloxMacApp.swift` | MODIFY | Feature-Flag + Launch-Argument Support (+8 LoC) |
| `FocusBloxMac/MacSettingsView.swift` | MODIFY | Toggle für Coach-Tab Layout (+10 LoC) |
| `Sources/Views/CoachView.swift` | MODIFY | `.taskDataChanged` Notification + `#if os(iOS)` Toolbar (+5 LoC) |
| `FocusBloxMacUITests/MacCoachTabLayoutUITests.swift` | CREATE | UI Tests für Coach-Navigation (+80 LoC) |

### Scope Assessment
- Files: 5 MODIFY + 1 CREATE = 6
- Estimated LoC: +123
- Risk Level: LOW

### Technical Approach
**Option A: Filtered `visibleSections` computed property**
- `MainSection` behält `CaseIterable` + bekommt `.coach` case
- `ContentView` bekommt `visibleSections: [MainSection]` basierend auf Feature-Flag
- Feature-Flag: `@AppStorage("useCoachTabLayout")` (gleicher Key wie iOS für iCloud-Sync)
- Launch-Argument: `--coach-tab-layout` (gleich wie iOS, für UI Tests)

### Implementation Order
1. `CoachView.swift` — Shared Fix: `.taskDataChanged` + `#if os(iOS)` Toolbar
2. `SidebarView.swift` — `.coach` case zu `MainSection` enum
3. `ContentView.swift` — Feature-Flag, `visibleSections`, Coach-Case
4. `FocusBloxMacApp.swift` — Feature-Flag + Launch-Argument
5. `MacSettingsView.swift` — Settings Toggle
6. `MacCoachTabLayoutUITests.swift` — UI Tests (TDD RED vor Steps 2-5)

### Open Questions
Keine — alle Abhängigkeiten geklärt, Ansatz klar
