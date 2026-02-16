---
entity_id: quickadd-nextup-checkbox
type: feature
created: 2026-02-16
updated: 2026-02-16
status: draft
version: "1.0"
tags: [quick-capture, next-up, ios, macos]
---

# QuickAdd Next Up Checkbox

## Approval

- [ ] Approved

## Purpose

Erweitert alle 3 Quick-Add-Flows um einen "Next Up"-Toggle, damit Tasks direkt beim Erstellen als Next Up markiert werden koennen - ohne Umweg ueber den Backlog.

## Source

- **Files:**
  - `Sources/Views/QuickCaptureView.swift` (iOS)
  - `FocusBloxMac/QuickCapturePanel.swift` (macOS Floating Panel)
  - `FocusBloxMac/MenuBarView.swift` (macOS Menu Bar)
- **Pattern:** Toggle-Button pro Quick-Add-Flow, setzt `isNextUp` + `nextUpSortOrder` nach Task-Erstellung

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask.isNextUp` | Model Property | Bool-Flag das gesetzt wird |
| `LocalTask.nextUpSortOrder` | Model Property | Sortierung in Next Up Liste |
| `LocalTaskSource.createTask()` | Service | Gibt erstellten Task zurueck |
| `modelContext.save()` | SwiftData | Persistiert isNextUp-Aenderung nach createTask |

## Affected Files

| File | Change | LoC | Description |
|------|--------|-----|-------------|
| `Sources/Views/QuickCaptureView.swift` | MODIFY | ~12 | State, Toggle-Button in metadataRow, isNextUp nach save |
| `FocusBloxMac/QuickCapturePanel.swift` | MODIFY | ~10 | State, Toggle-Button neben TextField, isNextUp nach add |
| `FocusBloxMac/MenuBarView.swift` | MODIFY | ~10 | State, Toggle-Button im Quick-Add HStack, isNextUp nach add |

**Total: 3 Dateien, ~32 LoC netto**

## Implementation Details

### Alle 3 Stellen: Gleicher Ablauf

1. **State hinzufuegen:**
   ```swift
   @State private var isNextUp = false
   ```

2. **Toggle-Button in UI einfuegen** (Style je nach Plattform)

3. **Nach `createTask()` - isNextUp setzen:**
   ```swift
   let task = try await taskSource.createTask(title: ..., ...)
   if isNextUp {
       task.isNextUp = true
       task.nextUpSortOrder = Int.max  // Ans Ende der Next Up Liste
       try? modelContext.save()
   }
   ```

4. **State resetten** nach Erstellung: `isNextUp = false`

### iOS QuickCaptureView - Button-Style

Identisch zu bestehenden Metadata-Buttons (40x40, RoundedRectangle, farbiger Hintergrund):

```swift
Button { isNextUp.toggle() } label: {
    Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
        .font(.system(size: 16))
        .foregroundStyle(isNextUp ? .blue : .gray)
        .frame(width: 40, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((isNextUp ? Color.blue : Color.gray).opacity(0.2))
        )
}
.buttonStyle(.plain)
```

Position: Nach `durationButton` in der `metadataRow` HStack.

### macOS QuickCapturePanel - Kompakter Button

Neben dem Submit-Button, `.borderless` Style:

```swift
Button(action: { isNextUp.toggle() }) {
    Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
        .foregroundStyle(isNextUp ? .blue : .secondary)
}
.buttonStyle(.borderless)
.help("Next Up")
```

Position: Zwischen TextField und Return-Button.

### macOS MenuBarView - Im Quick-Add HStack

Zwischen TextField und Plus-Button:

```swift
Button(action: { isNextUp.toggle() }) {
    Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
        .foregroundStyle(isNextUp ? .blue : .secondary)
}
.buttonStyle(.borderless)
.help("Next Up")
```

## Expected Behavior

- **Input:** User tippt auf Next Up Toggle vor Task-Erstellung
- **Output:** Toggle wechselt visuell (filled/unfilled Icon, blau/grau)
- **Bei Task-Erstellung mit Toggle aktiv:** Task hat `isNextUp = true`, erscheint sofort in Next Up Sektion
- **Bei Task-Erstellung ohne Toggle:** Verhalten wie bisher (`isNextUp = false`)
- **Side effects:** `nextUpSortOrder = Int.max` wird mitgesetzt (ans Ende der Liste)
- **Reset:** Toggle wird nach jeder Task-Erstellung zurueckgesetzt

## Acceptance Criteria

1. iOS QuickCaptureView: Toggle-Button "Next Up" in Metadata-Leiste sichtbar
2. macOS QuickCapturePanel: Toggle-Button neben Textfeld sichtbar
3. macOS MenuBarView: Toggle-Button im Quick-Add-Bereich sichtbar
4. Task mit aktiviertem Toggle wird mit `isNextUp = true` erstellt
5. Task ohne Toggle bleibt `isNextUp = false` (Default, wie bisher)
6. Toggle wird nach Task-Erstellung zurueckgesetzt
7. `nextUpSortOrder` wird korrekt gesetzt (Int.max)

## Test Plan

### Unit Tests
- Task-Erstellung mit isNextUp=true: Pruefe isNextUp + nextUpSortOrder gesetzt
- Task-Erstellung mit isNextUp=false: Pruefe Default-Verhalten ungeaendert

### UI Tests (iOS)
- QuickCaptureView: Toggle-Button sichtbar, tappbar, visueller State-Wechsel
- Task mit Toggle erstellen -> erscheint in Next Up Sektion

### UI Tests (macOS)
- QuickCapturePanel: Toggle-Button sichtbar und klickbar
- MenuBarView: Toggle-Button sichtbar und klickbar

## Known Limitations

- `LocalTaskSource.createTask()` wird NICHT geaendert (kein neuer Parameter) - isNextUp wird direkt nach Erstellung gesetzt
- Kein `SyncEngine.updateNextUp()` Aufruf - wir setzen Properties direkt (einfacher, weniger Overhead)
- macOS QuickCapturePanel hat begrenzten Platz (60px Hoehe) - Button muss kompakt bleiben

## Changelog

- 2026-02-16: Initial spec created
