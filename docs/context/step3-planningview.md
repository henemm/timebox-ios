# Context: Step 3 - PlanningView

## Request Summary
Split-View mit Kalender-Timeline und Backlog-Liste. Tasks per Drag & Drop in freie Zeitslots einplanen.

## Scope (aus Projekt-Spec)

**Features:**
1. Split View: Kalender oben/links, Backlog unten/rechts
2. Timeline zeigt Tagesansicht (z.B. 8:00-20:00)
3. Drag & Drop von Backlog in Timeline
4. Snap-Logik: Task an Startzeit ausrichten
5. Bestehende Kalender-Events anzeigen

## Vorhandene Komponenten

| Komponente | Status |
|------------|--------|
| BacklogView | ✅ Fertig |
| EventKitRepository | ✅ Fertig (nur Reminders) |
| SyncEngine | ✅ Fertig |

## Benötigte Erweiterungen

1. **EventKitRepository** - Calendar Events fetchen
2. **PlanningView** - Split View Container
3. **TimelineView** - Kalender-Tagesansicht
4. **TimeSlot** - Einzelner Zeitblock
5. **Navigation** - Tab zwischen Backlog und Planning

## Technische Herausforderungen

1. Calendar Events lesen (zusätzliche Permission)
2. Drag & Drop zwischen Views
3. Timeline-Rendering mit korrekten Höhen
4. Snap-to-Time Logik
