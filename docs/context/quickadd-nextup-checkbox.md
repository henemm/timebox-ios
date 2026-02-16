# Context: QuickAdd Next Up Checkbox

## Request Summary
Alle 3 Quick-Add-Flows (iOS QuickCaptureView, macOS QuickCapturePanel, macOS MenuBarView) um einen "Next Up"-Toggle erweitern, damit Tasks direkt beim Erstellen als Next Up markiert werden koennen.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/QuickCaptureView.swift` | iOS Quick Capture - bekommt Next Up Toggle in metadataRow |
| `FocusBloxMac/QuickCapturePanel.swift` | macOS Floating Panel - bekommt Next Up Toggle neben TextField |
| `FocusBloxMac/MenuBarView.swift` | macOS Menu Bar - bekommt Next Up Toggle im Quick Add |
| `Sources/Models/LocalTask.swift:54` | `isNextUp: Bool = false` - Property die gesetzt wird |
| `Sources/Services/TaskSources/LocalTaskSource.swift:73-106` | `createTask()` - hat KEINEN isNextUp Parameter |
| `Sources/Services/SyncEngine.swift:44-57` | `updateNextUp()` - setzt isNextUp + nextUpSortOrder |
| `Sources/Views/BacklogRow.swift` | Referenz: Swipe-Action "Next Up" mit `arrow.up.circle.fill` Icon |

## Existing Patterns

### Task-Erstellung
- iOS QuickCaptureView: Nutzt `LocalTaskSource.createTask()` mit Metadata (importance, urgency, duration, taskType)
- macOS QuickCapturePanel + MenuBarView: Nutzen `LocalTaskSource.createTask(title:, taskType: "")` - nur Titel
- Alle 3 Stellen erstellen Task und setzen danach KEINE weiteren Properties

### Next Up Mechanismus
- `isNextUp` wird NACH Task-Erstellung via `SyncEngine.updateNextUp()` gesetzt
- `updateNextUp()` setzt auch `nextUpSortOrder = Int.max` (ans Ende) und `assignedFocusBlockID = nil`
- Alternativ: Direkte Property-Zuweisung `task.isNextUp = true` + `modelContext.save()` (macOS ContentView Pattern)

### Metadata-Button-Pattern (iOS QuickCaptureView)
- Cycle-Buttons: 40x40px, RoundedRectangle, farbiger Hintergrund mit 0.2 Opacity
- `importanceButton`, `urgencyButton`, `categoryButton`, `durationButton` in HStack
- Alle mit `.buttonStyle(.plain)` + `accessibilityIdentifier`

### macOS Quick Add Pattern
- QuickCapturePanel: HStack mit Icon + TextField + Submit-Button, `.ultraThickMaterial` Background
- MenuBarView: TextField + Plus-Button + Close-Button in HStack, `.roundedBorder` Style

## Dependencies
- **Upstream:** `LocalTaskSource.createTask()` gibt `LocalTask` zurueck - wir setzen `.isNextUp` direkt danach
- **Upstream:** `modelContext.save()` - macOS Pattern braucht expliziten Save nach Property-Aenderung

## Downstream
- `@Query` in MenuBarView filtert `isNextUp == true` - neue Tasks tauchen sofort in Next Up auf
- NextUpSection (iOS) zeigt Tasks mit `isNextUp == true`

## Existing Spec
- `openspec/changes/quickadd-nextup-checkbox/proposal.md` - Detaillierte Proposal vorhanden

## Risks & Considerations
- **Kein Risiko:** `isNextUp` wird direkt auf dem zurueckgegebenen Task gesetzt, kein Model-Change noetig
- **nextUpSortOrder:** Muss beim Setzen von isNextUp=true auch gesetzt werden (Int.max = ans Ende)
- **Reset:** isNextUp State muss nach Task-Erstellung zurueckgesetzt werden (wie andere Metadata-Felder)
- **macOS Panel-Groesse:** QuickCapturePanel ist nur 60px hoch - der Toggle muss kompakt sein
