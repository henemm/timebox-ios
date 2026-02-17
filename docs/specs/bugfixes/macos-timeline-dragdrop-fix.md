---
entity_id: macos-timeline-dragdrop-fix
type: bugfix
created: 2026-02-04
updated: 2026-02-04
status: draft
workflow: macos-timeline-dragdrop-fix
---

# MacTimelineView Drag & Drop Fix

## Approval

- [ ] Approved for implementation

---

## Purpose

Die MacTimelineView im "Planen"-Tab hat kaputte Interaktionen (Tap, Drop, Hover funktionieren nicht), weil `.offset()` nur visuell verschiebt aber die Hit-Area bei (0,0) belässt. Diese Spec beschreibt einen Rewrite mit **SwiftUI Layout Protocol**, das Views korrekt positioniert ohne Hit-Testing zu brechen.

---

## Recherche-Ergebnisse (2026-02-04)

### macOS 26.2 Bug (bekannt)

Es gibt einen bestätigten Bug in macOS Tahoe 26.2:
> "In layered NSHostingView setups, the middle NSHostingView no longer receives mouse or drag events."

**Quelle:** [Apple Developer Forums](https://developer.apple.com/forums/thread/759081)

### Layout Protocol vs. offset()

| Methode | Positionierung | Hit-Area |
|---------|----------------|----------|
| `offset()` | Nach Layout (Transformation) | Bleibt bei Original-Position |
| `place()` (Layout Protocol) | Während Layout | Stimmt mit visueller Position überein |

**Quelle:** [SwiftUI Lab - Layout Protocol](https://swiftui-lab.com/layout-protocol-part-2/)

---

## Problem (Root Cause)

```swift
// AKTUELL - KAPUTT
.offset(x: columnOffset, y: topOffset)
```

- SwiftUI `.offset()` verschiebt Views nur VISUELL
- Hit-Area (für Tap, Drop, Hover) bleibt an Original-Position
- Block wird bei Y=180 angezeigt, Hit-Area ist bei Y=0

---

## Lösungsansatz: Custom Layout Protocol

Statt ZStack + offset → Custom `TimelineLayout` mit `place()`:

```swift
struct TimelineLayout: Layout {
    let hourHeight: CGFloat
    let startHour: Int

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let totalHours = 22 - startHour  // 06:00 - 22:00
        return CGSize(
            width: proposal.width ?? 400,
            height: CGFloat(totalHours) * hourHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            // Lese Zeit-Position aus LayoutValueKey
            let hourOffset = subview[TimelineHourKey.self]
            let minuteOffset = subview[TimelineMinuteKey.self]

            let y = bounds.minY + (CGFloat(hourOffset - startHour) + CGFloat(minuteOffset) / 60.0) * hourHeight
            let x = bounds.minX

            // place() positioniert View UND Hit-Area korrekt!
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }
}
```

**Warum das funktioniert:**
- `place()` positioniert Views WÄHREND des Layouts
- Hit-Areas stimmen automatisch mit visueller Position überein
- Ist der korrekte SwiftUI-Weg für Custom Layouts
- Keine Transformation nach dem Layout nötig

---

## Scope

### Betroffene Dateien

| Datei | Änderung | Beschreibung |
|-------|----------|--------------|
| `FocusBloxMac/MacTimelineView.swift` | REWRITE | Custom Layout Protocol |
| `FocusBloxMac/MacPlanningView.swift` | MODIFY | Persistenz via EventKit |

### Geschätzter Aufwand

- **Dateien:** 2
- **LoC:** ~350 (Rewrite)
- **Risiko:** MITTEL (Layout Protocol ist bewährt, aber neu für uns)

---

## Implementation Details

### Neue Komponenten-Hierarchie

```
MacTimelineView (NEU)
├── GeometryReader
│   └── ScrollView
│       └── ZStack(alignment: .topLeading)
│           ├── HourGridBackground (Stunden-Linien, keine Interaktion)
│           └── TimelineLayout  ← Custom Layout Protocol
│               ├── ForEach(events) { EventBlockView }
│               └── ForEach(focusBlocks) { FocusBlockView }
│                   └── .dropDestination()  ← Funktioniert jetzt!
└── CurrentTimeIndicator (Overlay)
```

### LayoutValueKey für Zeit-Position

```swift
// Jede View trägt ihre Zeit-Position als LayoutValue
struct TimelineHourKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

struct TimelineMinuteKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

extension View {
    func timelinePosition(hour: Int, minute: Int) -> some View {
        self
            .layoutValue(key: TimelineHourKey.self, value: hour)
            .layoutValue(key: TimelineMinuteKey.self, value: minute)
    }
}
```

### Verwendung im View

```swift
var body: some View {
    ScrollView {
        ZStack(alignment: .topLeading) {
            // Hintergrund-Grid (statisch)
            HourGridView(startHour: 6, endHour: 22, hourHeight: 60)

            // Events und Blocks mit Layout Protocol
            TimelineLayout(hourHeight: 60, startHour: 6) {
                // Kalender-Events (readonly)
                ForEach(events) { event in
                    EventBlockView(event: event)
                        .timelinePosition(
                            hour: event.startHour,
                            minute: event.startMinute
                        )
                }

                // FocusBlocks (interaktiv)
                ForEach(focusBlocks) { block in
                    FocusBlockView(block: block)
                        .timelinePosition(
                            hour: block.startHour,
                            minute: block.startMinute
                        )
                        .dropDestination(for: MacTaskTransfer.self) { items, _ in
                            // FUNKTIONIERT JETZT!
                            guard let task = items.first else { return false }
                            onAddTaskToBlock?(block.id, task.id)
                            return true
                        }
                }
            }
        }
        .frame(height: CGFloat(16) * 60)  // 16 Stunden * 60px
    }
}
```

### Persistenz (MacPlanningView)

```swift
// Wie in MacAssignView - EventKit direkt nutzen
private func assignTaskToBlock(taskID: String, block: FocusBlock) async {
    do {
        var updatedTaskIDs = block.taskIDs
        updatedTaskIDs.append(taskID)

        try eventKitRepo.updateFocusBlock(
            eventID: block.id,
            taskIDs: updatedTaskIDs,
            completedTaskIDs: block.completedTaskIDs,
            taskTimes: block.taskTimes
        )

        await loadCalendarEvents()  // Refresh
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

---

## Test Plan

### Unit Tests (TDD RED)

**TimelineLayout Tests:**

| Test | Input | Expected Output |
|------|-------|-----------------|
| `testSizeThatFits_returns960Height` | hourHeight=60, startHour=6, endHour=22 | height = 960 (16h × 60px) |
| `testPlaceSubviews_positionsAt9am` | hour=9, minute=0, startHour=6 | y = 180 (3h × 60px) |
| `testPlaceSubviews_positionsAt930am` | hour=9, minute=30, startHour=6 | y = 210 (3.5h × 60px) |
| `testPlaceSubviews_positionsAt6am` | hour=6, minute=0, startHour=6 | y = 0 |
| `testPlaceSubviews_handlesMultipleSubviews` | 3 blocks at different times | Alle korrekt positioniert |

**Zeit-Berechnungs Tests:**

| Test | Input | Expected Output |
|------|-------|-----------------|
| `testCalculateYPosition_fullHour` | hour=10, minute=0 | y = 240 |
| `testCalculateYPosition_halfHour` | hour=10, minute=30 | y = 270 |
| `testCalculateYPosition_quarterHour` | hour=10, minute=15 | y = 255 |
| `testCalculateBlockHeight_60min` | duration=60 | height = 60 |
| `testCalculateBlockHeight_90min` | duration=90 | height = 90 |

**Persistenz Tests (mit MockEventKitRepository):**

| Test | Action | Expected |
|------|--------|----------|
| `testAssignTaskToBlock_addsTaskID` | assignTask("task1", block) | block.taskIDs enthält "task1" |
| `testAssignTaskToBlock_preventsDuplicates` | assignTask("task1", block) zweimal | block.taskIDs enthält "task1" nur einmal |
| `testRemoveTaskFromBlock_removesTaskID` | removeTask("task1", block) | block.taskIDs enthält "task1" nicht mehr |
| `testAssignTaskToBlock_callsEventKitUpdate` | assignTask(...) | eventKitRepo.updateFocusBlock() aufgerufen |

### Manuelle Tests (NOTWENDIG - nicht automatisierbar)

**Grund:** Hit-Testing und Drag & Drop sind Framework-Verhalten, die nicht zuverlässig automatisiert getestet werden können.

- [ ] Stunden-Grid zeigt 06:00-22:00
- [ ] FocusBlocks erscheinen an korrekter Zeit-Position
- [ ] Kalender-Events werden angezeigt (readonly)
- [ ] **Drag & Drop von Next Up auf FocusBlock funktioniert** ← Kernfunktion
- [ ] **Tap auf FocusBlock öffnet Tasks-Sheet** ← Kernfunktion
- [ ] **Hover zeigt Edit-Button** ← Kernfunktion
- [ ] Änderungen bleiben nach Tab-Wechsel erhalten

---

## Acceptance Criteria

**Automatisiert verifiziert (Unit Tests):**
- [ ] TimelineLayout berechnet korrekte Größe (960px für 16h)
- [ ] TimelineLayout positioniert Views an korrekten Y-Koordinaten
- [ ] Zeit-Berechnungen sind korrekt (hour/minute → Y-Position)
- [ ] Persistenz-Logik fügt Tasks korrekt hinzu/entfernt sie
- [ ] Alle Unit Tests grün

**Manuell verifiziert:**
- [ ] Timeline zeigt Stunden-Grid 06:00-22:00
- [ ] FocusBlocks werden an korrekter Zeit angezeigt
- [ ] Kalender-Events werden angezeigt
- [ ] **Tap auf FocusBlock öffnet Tasks-Sheet** (Hit-Testing funktioniert)
- [ ] **Drop auf FocusBlock fügt Task hinzu** (Drag & Drop funktioniert)
- [ ] **Hover auf FocusBlock zeigt Edit-Button** (Hover funktioniert)
- [ ] Änderungen bleiben nach Tab-Wechsel erhalten

---

## Risiken & Mitigations

| Risiko | Mitigation |
|--------|------------|
| macOS 26.2 NSHostingView Bug | Testen ob Layout Protocol das umgeht; Fallback: VStack-Ansatz |
| Events die Stunden-Grenzen überspannen | Höhe berechnen: `(endHour - startHour + minutes/60) * hourHeight` |
| Performance bei vielen Events | Layout Protocol ist effizient; bei Bedarf caching nutzen |
| Layout Protocol Lernkurve | Gute Dokumentation bei SwiftUI Lab |

---

## Fallback-Plan

Falls Layout Protocol das macOS 26.2 Bug nicht umgeht:

**Alternative: VStack mit Stunden-Containern**
```swift
VStack(spacing: 0) {
    ForEach(6..<22, id: \.self) { hour in
        HourSlotView(hour: hour, blocks: blocksInHour(hour))
            .frame(height: 60)
    }
}
```

Dieser Ansatz ist simpler, aber weniger präzise für Minute-genaue Positionierung.

---

## Referenzen

- **Layout Protocol Tutorial:** [SwiftUI Lab - Layout Protocol Part 2](https://swiftui-lab.com/layout-protocol-part-2/)
- **Anchored Position:** [Nil Coalescing Blog](https://nilcoalescing.com/blog/AnchoredPositionInSwiftUI/)
- **Apple Docs:** [Layout Protocol](https://developer.apple.com/documentation/swiftui/layout)
- **Funktionierendes Beispiel:** `FocusBloxMac/MacAssignView.swift`
- **Problem-Dokumentation:** `docs/specs/backlog/mac-timeline-interaction-bug.md`
- **Kontext:** `docs/context/macos-timeline-dragdrop-fix.md`

---

## Changelog

- 2026-02-04: Spec erstellt
- 2026-02-04: Aktualisiert mit Layout Protocol Ansatz nach Recherche
- 2026-02-04: Test Plan korrigiert: Unit Tests statt UI Tests (Drag & Drop nicht automatisierbar)
