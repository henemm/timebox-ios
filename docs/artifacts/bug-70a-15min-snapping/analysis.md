# Bug 70a: 15-Min-Snapping bei FocusBlock-Erstellung

## Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check)
- 15-Min-Snapping wurde **nie implementiert oder versucht**
- Einziger verwandter Fix: Bug 14 (Midnight-Wrapping bei DatePicker)
- `FocusBlock.normalizeEndTime()` existiert bereits fuer Mitternacht-Korrektur

### Agent 2 (Datenfluss-Trace)
- iOS: Tap Free Slot -> TimeSlot (GapFinder) -> CreateFocusBlockSheet (DatePicker) -> EventKit
- macOS: Tap Free Slot -> TimeSlot (GapFinder) -> MacCreateFocusBlockSheet (DatePicker) -> EventKit
- DatePicker erlaubt beliebige Minuten (kein Snapping)
- `EventKitRepository.createFocusBlock()` ist Shared Code (beide Plattformen)

### Agent 3 (Alle Schreiber)
8 Stellen identifiziert die FocusBlock-Zeiten setzen:
- 3x DatePicker OHNE Snapping (iOS Create, Shared Edit, macOS Create)
- 1x macOS Drop Handler MIT 15-Min-Snapping (MacTimelineView:328)
- 2x GapFinder OHNE Snapping (Gap-Boundaries + Default-Suggestions)
- 2x Hour-based Creation (inherent auf :00)

### Agent 4 (Szenarien)
5 Stellen ohne 15-Min-Snapping:
1. iOS CreateFocusBlockSheet DatePicker (BlockPlanningView:645-646)
2. macOS MacCreateFocusBlockSheet DatePicker (MacPlanningView:601-602)
3. Shared EditFocusBlockSheet DatePicker (EditFocusBlockSheet:24-25)
4. GapFinder Slot-Boundaries (GapFinder:84-91)
5. GapFinder Default-Suggestions End-Time (GapFinder:149)

### Agent 5 (Blast Radius)
- **Risiko: MINIMAL** — nur FocusBlock-DatePicker betroffen
- 8 andere DatePicker im Projekt (Due-Date, Settings) sind NICHT betroffen
- EventKit akzeptiert beliebige Date-Werte
- Keine Business-Logik haengt von Minuten-Praezision ab

### Challenge Round 1 (Verdict: SCHWACH)
Kritische Funde:
1. **`.minuteInterval(15)` existiert NICHT in SwiftUI** — nur in UIKit (UIDatePicker)
2. **EditFocusBlockSheet ist Shared Code** (nicht iOS-only) — liegt in `Sources/Views/`, wird von macOS MacPlanningView:96 genutzt
3. **Existierende Blocks mit nicht-15-Min-Zeiten** (z.B. 09:23) — was passiert beim Editieren?
4. **macOS NSDatePicker hat KEIN minuteInterval** — plattformuebergreifender Ansatz noetig

## Korrigierter Fix-Ansatz

### Warum NICHT `.minuteInterval(15)`:
- Existiert nur in UIKit (`UIDatePicker.minuteInterval`), nicht in SwiftUI
- `NSDatePicker` (macOS) hat gar kein Aequivalent
- UIViewRepresentable-Wrapper waere zu aufwendig fuer diesen Scope

### Stattdessen: `.onChange` Rounding (bereits bewaehrtes Pattern)
- **Beweis:** `MacTimelineView.swift:328` nutzt `(minute / 15) * 15` bereits erfolgreich
- Cross-platform (iOS + macOS identisch)
- Shared Helper: `FocusBlock.snapToQuarterHour(_ date: Date) -> Date`

### Implementierung:
1. **`FocusBlock.swift`** — Neue statische Methode `snapToQuarterHour()` (analog zu `normalizeEndTime()`)
2. **`CreateFocusBlockSheet`** (BlockPlanningView.swift) — init snappt Initialwerte, onChange snappt Aenderungen
3. **`MacCreateFocusBlockSheet`** (MacPlanningView.swift) — gleiche Logik
4. **`EditFocusBlockSheet.swift`** (Shared) — init snappt Blockzeiten, onChange snappt Aenderungen

### Edge Case: Existierende Blocks mit nicht-15-Min-Zeiten
- Beim Oeffnen des Edit-Sheets werden Start/End auf naechstes 15-Min-Raster gesnappt
- User sieht z.B. 09:15 statt 09:13 → bewusste UX-Entscheidung (Konsistenz > Praezision)
- EventKit-Event wird erst bei "Speichern" aktualisiert (kein Auto-Snap im Hintergrund)

## Hypothesen (korrigiert)

### Hypothese 1: onChange-Rounding mit Shared Helper (HOHE Wahrscheinlichkeit)
- **Beweis dafuer:** Exakt dieses Pattern existiert in MacTimelineView:328 und funktioniert
- **Beweis dagegen:** Keiner — bewaehrtes Pattern
- **Wahrscheinlichkeit:** HOCH

### Hypothese 2: UIViewRepresentable fuer echten minuteInterval-Picker (nur iOS)
- **Beweis dafuer:** Apple Calendar nutzt UIDatePicker.minuteInterval fuer :00/:15/:30/:45
- **Beweis dagegen:** Funktioniert nicht auf macOS, waere 2 verschiedene Implementierungen
- **Wahrscheinlichkeit:** NIEDRIG — zu aufwendig, inkonsistent cross-platform

### Hypothese 3: Snap nur beim Speichern (minimaler Ansatz)
- **Beweis dafuer:** Einfachste Implementierung, null onChange-Risiko
- **Beweis dagegen:** Schlechte UX — User sieht 09:13 und nach Speichern steht 09:15
- **Wahrscheinlichkeit:** MITTEL — funktional korrekt aber UX-maessig suboptimal

## Fix-Scope (korrigiert)

### 3 Dateien, ~25 LoC:
1. **`Sources/Models/FocusBlock.swift`** — `snapToQuarterHour()` statische Methode (~8 LoC)
2. **`Sources/Views/BlockPlanningView.swift`** — CreateFocusBlockSheet init + onChange (~6 LoC)
3. **`Sources/Views/EditFocusBlockSheet.swift`** — init + onChange (~6 LoC) — SHARED (iOS + macOS!)
4. **`FocusBloxMac/MacPlanningView.swift`** — MacCreateFocusBlockSheet init + onChange (~6 LoC)

### Plattform-Check (korrigiert):
- **Shared:** FocusBlock.swift (Helper), EditFocusBlockSheet.swift (Edit-Sheet)
- **iOS:** BlockPlanningView.swift (Create-Sheet)
- **macOS:** MacPlanningView.swift (Create-Sheet)
- **Beide Plattformen vollstaendig abgedeckt**

## Blast Radius
- Keine anderen Features betroffen (separate DatePicker fuer Tasks, Settings etc.)
- Keine Logik-Aenderung (nur UI-Rundung)
- `normalizeEndTime()` bleibt kompatibel (arbeitet mit gerundeten Werten genauso)
- Existierende Blocks: Zeiten werden beim naechsten Edit auf Raster gezogen
