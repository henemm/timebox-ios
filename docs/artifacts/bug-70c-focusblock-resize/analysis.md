# Bug 70c: FocusBlock Resize per Drag — Analyse

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- Bug 70c wurde **nie zuvor versucht** — komplett neues Feature
- 70a (Snap to 15-min) und 70b (Drag & Drop Move) sind ERLEDIGT
- Bestehende Infrastruktur: `snapToQuarterHour()`, `CalendarEventTransfer`, `updateFocusBlockTime()`

### Agent 2: Datenfluss-Trace — KRITISCHER FUND
- **macOS**: Block-Hoehe = `(durationMinutes / 60) * hourHeight` via `TimelineLayout` — Blocks sind visuell proportional zur Dauer
- **iOS**: Block-Hoehe ist **FIXE Text-Hoehe** (~40pt) — NICHT duration-basiert! Ein 30-Min-Block und ein 3-Stunden-Block sehen gleich aus
- macOS: Live-Resize funktioniert (State-Update → TimelineLayout rechnet neu → Block waechst/schrumpft)
- iOS: Timeline ist **listenbasiert** (Blocks in TimelineHourRow), nicht canvas-basiert

### Agent 3: Alle Schreiber
- Genau **1 Write-Point** fuer Block-Zeiten: `EventKitRepository.updateFocusBlockTime(eventID:startDate:endDate:)`
- Aufrufer: `BlockPlanningView.updateBlock()` (iOS), `MacPlanningView.updateBlockTime()` (macOS), `EditFocusBlockSheet.onSave`
- `moveFocusBlock()` preserviert Duration beim Move — Resize braucht inverse Logik (startDate preservieren, endDate aendern)

### Agent 4: Edge Cases
- **Minimum Duration**: Kein Minimum enforced — brauchen 15-Min-Minimum
- **Midnight Crossing**: `normalizeEndTime()` existiert, muss bei Resize aufgerufen werden
- **Block Collision**: Keine Overlap-Verhinderung (nur Layout-Columns fuer Side-by-Side)
- **Active Blocks**: Geschuetzt via `isFuture` Check — nur Future-Blocks resizebar
- **Tasks**: Werden bei Resize preserviert (nur Zeiten aendern sich)
- **Sync**: Automatisch via EventKit/iCloud

### Agent 5: Blast Radius
- **Gesture-Konflikte**: `.draggable()` (Move) + `DragGesture` (Resize) auf gleicher View = Konfliktpotenzial
- **ScrollView vs DragGesture**: Vertikaler Drag am Block-Rand kollidiert mit Scroll
- **Notification-Loop**: `updateBlock()` rescheduled Notifications — darf NICHT pro Frame aufgerufen werden
- **Loesung**: Separate `previewDuration` State waehrend Drag, erst bei onEnded persistieren

## ARCHITEKTUR-PROBLEM: iOS vs macOS Timeline

**Dies ist die wichtigste Erkenntnis der Analyse.**

| Aspekt | iOS (BlockPlanningView) | macOS (MacTimelineView) |
|--------|------------------------|------------------------|
| Layout | Listen-basiert (Rows pro Stunde) | Canvas-basiert (TimelineLayout) |
| Block-Hoehe | Fix (~40pt, Text-basiert) | Duration-proportional (1pt/min) |
| Visuelles Spanning | Block nur in Start-Stunde sichtbar | Block spannt ueber mehrere Stunden |
| Resize per Drag | **Macht visuell keinen Sinn** | **Perfekt geeignet** |

**Hinweis (Devil's Advocate Fund):** In BlockPlanningView.swift existiert eine `FocusBlockView` (Zeile 581-633) die IS duration-basiert (`calculateHeight() = durationMinutes/60 * hourHeight`). Sie wird aber im aktuellen iOS-Timeline-Pfad NICHT genutzt — `TimelineHourRow` rendert `TimelineFocusBlockRow` (fix-height). `FocusBlockView` ist entweder Dead Code oder fuer spaetere Canvas-Migration vorbereitet.

**Konsequenz:** Drag-Resize am unteren Rand funktioniert nur auf macOS, weil dort die Block-Hoehe die Dauer repraesentiert. Auf iOS ist kein "unterer Rand" sichtbar der die Dauer repraesentiert.

## Hypothesen

### H1: macOS Resize per Bottom-Edge DragGesture (HOHE Wahrscheinlichkeit)
- **Beschreibung**: DragGesture am unteren 20px-Rand des FocusBlockView
- **Beweis DAFUER**: TimelineLayout ist canvas-basiert, Block-Hoehe = Duration, Live-Preview ueber State-Update moeglich
- **Beweis DAGEGEN**: Gesture-Konflikte mit `.draggable()` und ScrollView moeglich
- **Wahrscheinlichkeit**: HOCH — technisch machbar, visuell sinnvoll

### H2: iOS Resize per Bottom-Edge DragGesture (NIEDRIGE Wahrscheinlichkeit)
- **Beschreibung**: Gleicher Ansatz wie macOS auf iOS
- **Beweis DAFUER**: Keiner — iOS-Blocks haben keine duration-basierte Hoehe
- **Beweis DAGEGEN**: iOS-Timeline ist listenbasiert, Block-Hoehe ist fix, "unterer Rand" repraesentiert nicht das Ende
- **Wahrscheinlichkeit**: NIEDRIG — macht visuell keinen Sinn

### H3: iOS Resize per Long-Press + Stepper (MITTLERE Wahrscheinlichkeit)
- **Beschreibung**: Long-Press auf Block oeffnet Inline-Stepper fuer Duration (+/- 15 Min)
- **Beweis DAFUER**: Passt zur listenbasierten UI, kein Gesture-Konflikt
- **Beweis DAGEGEN**: Anderes Interaction-Pattern als macOS, weniger intuitiv als Drag
- **Wahrscheinlichkeit**: MITTEL — technisch einfach, UX-maessig OK

### H4: iOS Timeline zu Canvas-basiert umbauen (NIEDRIGE Wahrscheinlichkeit fuer dieses Ticket)
- **Beschreibung**: iOS-Timeline auf TimelineLayout umbauen wie macOS
- **Beweis DAFUER**: Wuerde konsistente UX ermoeglichen
- **Beweis DAGEGEN**: RIESIGER Scope (300+ LoC), eigenes Ticket, nicht Teil von Bug 70c
- **Wahrscheinlichkeit**: NIEDRIG fuer dieses Ticket

## Empfohlener Ansatz

**macOS:** Bottom-Edge DragGesture (H1) — technisch und visuell passend

**iOS:** Entscheidung noetig:
- Option A: Nur macOS implementieren, iOS als Follow-up (separates Ticket)
- Option B: iOS mit Long-Press + Duration-Stepper (H3) — anderes UX-Pattern
- Option C: iOS-Timeline zuerst auf Canvas-basiert umbauen (H4) — grosser Scope

## Blast Radius
- **Notification Service**: Darf nicht pro Frame aufgerufen werden → nur bei onEnded
- **EventKit**: Gleicher Write-Point wie Move — kein zusaetzliches Risiko
- **Gesture-Konflikt (Devil's Advocate Fund)**: SwiftUI `.draggable()` kann NICHT auf Sub-Bereiche beschraenkt werden. Loesung: `.draggable()` durch dediziertes Drag-Handle-Icon im Block-Header ersetzen (z.B. `line.3.horizontal`), unteren Bereich fuer Resize-DragGesture freigeben
- **ScrollView**: Gesture-Priority muss korrekt gesetzt werden
- **Live-Preview**: Separater `previewDuration` State in FocusBlockView, NICHT `calendarEvents`-Array pro Frame updaten (wuerde EventKit-Writes + Notification-Reschedule triggern). `previewDuration` fliesst direkt in `.timelinePosition(durationMinutes:)` ein

## Dateien fuer macOS-Implementation (~4 Dateien)
1. `Sources/Models/FocusBlock.swift` — `resizedEndDate()` Helper + min Duration Constant
2. `FocusBloxMac/MacTimelineView.swift` — Resize-Handle + DragGesture auf FocusBlockView
3. `FocusBloxMac/MacPlanningView.swift` — `resizeFocusBlock()` Handler (analog zu `moveFocusBlock()`)
4. Tests: FocusBlockResizeTests.swift + UI Tests
