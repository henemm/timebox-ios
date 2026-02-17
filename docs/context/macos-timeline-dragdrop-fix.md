# Context: macOS Timeline Drag & Drop Fix

**Workflow:** macos-timeline-dragdrop-fix
**Phase:** Analysis
**Erstellt:** 2026-02-04

---

## Problem-Zusammenfassung

Die MacTimelineView im "Planen"-Tab hat kaputte Interaktionen:
- Tap auf FocusBlock → funktioniert NICHT
- Drop auf FocusBlock → funktioniert NICHT
- Hover → funktioniert NICHT

**Root Cause:** `.offset()` verschiebt Views nur VISUELL. Die Hit-Area bleibt bei (0,0).

---

## Existierende Dokumentation

| Dokument | Inhalt |
|----------|--------|
| `docs/specs/backlog/mac-timeline-interaction-bug.md` | Vollständige Analyse, 10 gescheiterte Versuche, 4 Lösungsansätze |
| `docs/artifacts/macos-layout-fix/DEBUG-PLAN.md` | 1/3 Höhe Bug (GELÖST) |
| `docs/reference/learnings.md` | SwiftUI Path + offset Probleme |

---

## Technisches Problem

```swift
// MacTimelineView.swift - KAPUTT
.offset(x: columnOffset, y: topOffset)  // Verschiebt nur visuell!
```

- Block wird bei Y=180 (09:00) ANGEZEIGT
- Hit-Area ist bei Y=0 (06:00)
- Alle Interaktionen treffen die falsche Position

---

## Was funktioniert: MacAssignView

```swift
// MacAssignView.swift - FUNKTIONIERT
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(focusBlocks) { block in
            MacFocusBlockCard(...)
                .dropDestination(for: MacTaskTransfer.self) { ... }
        }
    }
}
```

**Warum es funktioniert:**
- Keine `.offset()` oder `.position()`
- Views in normalem Document Flow
- Hit-Areas stimmen mit visueller Position überein

---

## Gescheiterte Versuche (10 Stück)

1. `.contentShape(Rectangle())` - offset transformiert auch contentShape
2. `onDrop` statt `dropDestination` - gleiche Probleme
3. dropDestination auf Parent-ZStack - falsche Koordinaten
4. Verschachtelte Drop-Handler - propagiert nicht korrekt
5. `allowsHitTesting(true)` - keine Wirkung bei offset
6. Overlay statt offset - gleiche Problematik
7. GeometryReader für Koordinaten - fehleranfällig
8. `.position()` statt `.offset()` - **KATASTROPHE** (Layout zerstört)
9. Nested handlers mit Koordinaten-Mapping - Race Conditions
10. Git-Restore - Features nicht vollständig implementiert

---

## Mögliche Lösungsansätze

### Ansatz A: VStack mit Stunden-Containern
- VStack mit fixen Höhen pro Stunde (60px)
- Blöcke als Overlays INNERHALB der Stunden-Container
- Ähnlich wie HTML `position: relative` + `absolute`

### Ansatz B: Canvas + SwiftUI Hybrid
- Stunden-Grid und readonly Events als Canvas rendern
- FocusBlocks als normale SwiftUI Views ohne offset
- Zwei-Schichten-Architektur

### Ansatz C: MacAssignView-Pattern
- Timeline zeigt nur Zeiten als Labels auf Cards
- Blöcke sind Cards in normalem LazyVStack
- Weniger visuell, aber funktional

### Ansatz D: AppKit
- NSView-basierte Timeline
- Sehr hoher Aufwand

---

## Scope-Analyse

### Betroffene Dateien

| Datei | Änderung | Beschreibung |
|-------|----------|--------------|
| `FocusBloxMac/MacTimelineView.swift` | REWRITE | Komplett neue Architektur |
| `FocusBloxMac/MacPlanningView.swift` | MODIFY | Persistenz + neue View integrieren |

### Anforderungen an die Lösung

1. **Zeit-basierte Anzeige:** Blöcke müssen an korrekter Uhrzeit erscheinen
2. **Kalender-Events:** Normale Events müssen weiterhin angezeigt werden
3. **Stunden-Grid:** Hintergrund mit Zeitraster 06:00-22:00
4. **Tap-Interaktion:** Klick auf Block öffnet Tasks-Sheet
5. **Drop-Interaktion:** Task droppen fügt Task hinzu
6. **Hover-Interaktion:** Mouse-Over zeigt Edit-Button
7. **Persistenz:** Änderungen in EventKit speichern

### Geschätzter Aufwand

- **Dateien:** 2
- **LoC:** ~400 (Rewrite von MacTimelineView)
- **Risiko:** HOCH (fundamentale Architekturänderung)

---

## Empfehlung

**Ansatz A (VStack mit Stunden-Containern)** ist der beste Kompromiss:
- Erhält die visuelle Timeline-Darstellung
- Löst das Hit-Testing-Problem fundamental
- Überschaubarer Aufwand

**Nicht empfohlen:**
- Ansatz C (verliert Timeline-Visualisierung)
- Ansatz D (zu hoher Aufwand)

---

## Nächster Schritt

`/write-spec` - Spezifikation für Ansatz A erstellen
