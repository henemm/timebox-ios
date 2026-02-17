# MacTimelineView Interaktions-Bug

**Status:** Backlog - Ungelöst
**Priorität:** Hoch
**Erstellt:** 2026-02-04
**Aufwand:** Unbekannt (10+ Versuche gescheitert)

---

## Problem-Beschreibung

Die MacTimelineView im "Planen"-Tab zeigt FocusBlocks in einer Zeitleisten-Ansicht an. Diese Blöcke sollen interaktiv sein:
- Tap → Tasks-Sheet öffnen
- Drop → Task zum Block hinzufügen
- Hover → Edit-Button anzeigen

**Aktueller Zustand:** KEINE dieser Interaktionen funktioniert zuverlässig. Klicks und Drops werden nicht erkannt oder an der falschen Position registriert.

---

## Root Cause Analyse

### Das fundamentale Problem: `.offset()` in SwiftUI

MacTimelineView verwendet `.offset()` um FocusBlocks an der korrekten Zeit-Position zu platzieren:

```swift
// In FocusBlockView
.offset(x: columnOffset, y: topOffset)
```

**Problem:** SwiftUI's `.offset()` verschiebt Views nur VISUELL. Die Hit-Area (für Tap, Drop, Hover) bleibt an der Original-Position (0,0).

**Beispiel:**
- Ein Block wird bei Y=180 (09:00 Uhr) ANGEZEIGT
- Die Hit-Area ist aber bei Y=0 (06:00 Uhr)
- Klicks auf den sichtbaren Block werden nicht erkannt
- Klicks auf "leeren" Bereich werden fälschlicherweise erkannt

### Warum MacAssignView funktioniert

Der "Zuweisen"-Tab verwendet **keine** `.offset()`. Die Architektur ist fundamental anders:

```swift
// MacAssignView - FUNKTIONIERT
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(focusBlocks) { block in
            MacFocusBlockCard(...)
                .dropDestination(for: MacTaskTransfer.self) { ... }
        }
    }
}
```

- Cards sind in normalem Document Flow
- Keine manuelle Positionierung
- Hit-Areas stimmen mit visueller Position überein
- Alle Interaktionen funktionieren einwandfrei

---

## Gescheiterte Lösungsversuche

### Versuch 1: `.contentShape(Rectangle())`
**Idee:** Explizite Hit-Area definieren
**Ergebnis:** Keine Verbesserung - offset transformiert auch contentShape nur visuell

### Versuch 2: `onDrop` statt `dropDestination`
**Idee:** Ältere API mit anderen Koordinaten
**Ergebnis:** Gleiche Probleme, zusätzlich keine visuelle Feedback-Unterstützung

### Versuch 3: dropDestination auf Parent-ZStack
**Idee:** Drop auf Container-Ebene, dann Block per Koordinaten finden
**Ergebnis:**
- Koordinaten in ScrollView sind viewport-relativ, nicht content-relativ
- `findFocusBlockAtLocation()` findet falschen Block
- Verschlimmert das Problem

### Versuch 4: dropDestination auf ZStack-Content
**Idee:** Verschachtelte Drop-Handler, inner handler für Blöcke
**Ergebnis:** `return false` propagiert nicht korrekt, Drop wird abgelehnt statt weitergeleitet

### Versuch 5: allowsHitTesting(true) explizit
**Idee:** SwiftUI-Modifier für Hit-Testing
**Ergebnis:** Keine Wirkung bei offset-basierten Views

### Versuch 6: Overlay statt offset
**Idee:** FocusBlocks als Overlay über dem Grid
**Ergebnis:** Gleiche offset-Problematik, nur anders strukturiert

### Versuch 7: GeometryReader für absolute Koordinaten
**Idee:** Koordinaten-Transformation beim Drop
**Ergebnis:** Komplex, fehleranfällig, falsche Scroll-Offset-Berechnung

### Versuch 8: .position() statt .offset()
**Idee:** `.position()` positioniert View inklusive Hit-Area
**Ergebnis:** **KATASTROPHE** - Layout komplett zerstört:
- Stunden-Grid verschwunden
- Block als einziges Element, falsch positioniert
- Keine Inhalte sichtbar
- `.position()` erfordert fundamental anderes Layout-Setup

### Versuch 9: Nested drop handlers mit Koordinaten-Mapping
**Idee:** Globaler Handler mappt zu lokalem Handler
**Ergebnis:** Zu komplex, Race Conditions, unzuverlässig

### Versuch 10: Git-Restore von funktionierendem Commit
**Idee:** Commit 3ea6c19 enthielt funktionierende Version
**Ergebnis:** Features waren dort auch nicht vollständig implementiert

---

## Technische Anforderungen

Eine Lösung muss erfüllen:

1. **Zeit-basierte Positionierung:** Blöcke müssen an korrekter Uhrzeit angezeigt werden
2. **Tap-Interaktion:** Klick auf Block öffnet Tasks-Sheet
3. **Drop-Interaktion:** Task aus Next Up auf Block droppen fügt Task hinzu
4. **Hover-Interaktion:** Mouse-Over zeigt Edit-Button
5. **Persistenz:** Änderungen müssen in EventKit gespeichert werden
6. **Stunden-Grid:** Hintergrund mit Zeitraster 06:00-22:00

---

## Mögliche Lösungsansätze (nicht getestet)

### Ansatz A: Alternative Layout-Architektur
Komplett neues Design ohne offset:
- VStack mit fixen Höhen pro Stunde
- Blöcke als Overlays innerhalb der Stunden-Container
- Ähnlich wie HTML/CSS `position: relative` + `absolute`

### Ansatz B: Canvas für Hintergrund, SwiftUI für Interaktion
- Stunden-Grid und readonly Events als Canvas rendern
- FocusBlocks als normale SwiftUI Views ohne offset
- Erfordert zwei-Schichten-Architektur

### Ansatz C: MacAssignView-Pattern übernehmen
- Timeline zeigt nur Zeiten als Labels
- Blöcke sind Cards in normalem LazyVStack
- Weniger visuell, aber funktional

### Ansatz D: AppKit statt SwiftUI
- NSView-basierte Timeline mit korrektem Hit-Testing
- SwiftUI-Interop für Rest der App
- Sehr hoher Aufwand

---

## Referenz: MacAssignView (Funktioniert)

```swift
// Datei: FocusBloxMac/MacAssignView.swift
// Zeilen 83-103

ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(focusBlocks) { block in
            MacFocusBlockCard(
                block: block,
                tasks: tasksForBlock(block),
                onDropTask: { taskID in
                    Task { await assignTaskToBlock(taskID: taskID, block: block) }
                },
                onRemoveTask: { taskID in
                    Task { await removeTaskFromBlock(taskID: taskID, block: block) }
                },
                onReorderTasks: { newOrder in
                    Task { await reorderTasksInBlock(newOrder: newOrder, block: block) }
                }
            )
        }
    }
    .padding()
}
```

**Key Points:**
- Keine `.offset()` oder `.position()`
- Views in normalem Document Flow
- `.dropDestination()` direkt auf Card
- Alle Interaktionen funktionieren

---

## Dateien

| Datei | Beschreibung |
|-------|--------------|
| `FocusBloxMac/MacTimelineView.swift` | Kaputte Timeline mit offset |
| `FocusBloxMac/MacPlanningView.swift` | Parent View, auch Persistenz-Problem |
| `FocusBloxMac/MacAssignView.swift` | **FUNKTIONIERT** - Referenz |

---

## Zusätzliches Problem: Persistenz

Neben dem Hit-Testing-Problem gibt es ein separates Persistenz-Problem:

- MacPlanningView manipuliert nur lokale `@State` Arrays
- Änderungen werden NICHT in EventKit gespeichert
- Beim Tab-Wechsel gehen alle Änderungen verloren
- MacAssignView verwendet korrekt `eventKitRepo.updateFocusBlock()`

**Dieser Fix wurde auch versucht und musste zurückgerollt werden** weil das UI-Problem zuerst gelöst werden muss.

---

## Fazit

Das Problem ist fundamental und erfordert wahrscheinlich eine komplette Neuarchitektur der MacTimelineView. Ein einfacher Fix existiert nicht.

**Empfehlung:** Einen erfahrenen macOS/SwiftUI-Entwickler konsultieren, der sich mit dem Hit-Testing-Verhalten von offset/position auskennt.
