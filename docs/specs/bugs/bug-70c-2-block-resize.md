# Bug 70c-2: FocusBlock Resize per Drag am unteren Rand

## Ziel
User kann die Dauer eines FocusBlocks aendern, indem er den unteren Rand des Blocks
auf der Timeline nach oben/unten zieht. 15-Min-Snapping, beide Plattformen.

## Verhalten
- Unterer Rand (~20px) des FocusBlocks ist ein Resize-Handle
- DragGesture aendert die Block-Hoehe (= Dauer) live
- EndTime wird auf 15-Min-Grenzen gerundet (snapToQuarterHour)
- Minimum-Dauer: 15 Minuten
- Persistenz erst bei Gesture-Ende (kein EventKit-Spam)
- Nur fuer Future-Blocks (konsistent mit Move-Drag)

## Dateien
- `Sources/Models/FocusBlock.swift` — MIN_DURATION_MINUTES Konstante
- `Sources/Views/BlockPlanningView.swift` — iOS Resize Gesture + Handle
- `FocusBloxMac/MacTimelineView.swift` — macOS Resize Gesture + Handle
- `FocusBloxTests/FocusBlockResizeTests.swift` — Unit Tests
