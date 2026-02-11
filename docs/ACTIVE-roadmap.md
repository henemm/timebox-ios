# Active Roadmap

> Geplante Features und Erweiterungen.
>
> **Regel:** Nach JEDEM Feature hier aktualisieren!

---

## Status-Legende

| Status | Bedeutung |
|--------|-----------|
| **Open** | Noch nicht begonnen |
| **Spec Ready** | Spec geschrieben & approved, Implementation ausstehend |
| **In Progress** | Aktive Implementation |
| **Done** | Fertig (Phase 8 complete) |
| **Blocked** | Kann nicht fortgesetzt werden |

**WICHTIG:** "Spec Ready" ≠ "Done"! Ein Feature mit fertiger Spec ist NICHT abgeschlossen.

---

## Spec Ready

_Keine Features mit fertiger Spec_

---

## In Arbeit

_Keine Features in Arbeit_

---

## Offen

### Watch Voice Capture
**Status:** Open
**Priorität:** Must
**Bereich:** watchOS App

**Kurzbeschreibung:**
Button-Tap → Spracheingabe → Task landet im Backlog (als tbd).

**Hinweis:** VoiceInputSheet UI existiert bereits, ist aber nicht in die Watch-App integriert. Watch ContentView ist noch ein Placeholder.

---

### Quick Add Widget (iOS) - Bundle-Registrierung
**Status:** Open (Code existiert, nicht aktiviert)
**Priorität:** Must
**Bereich:** iOS WidgetKit

**Kurzbeschreibung:**
`QuickCaptureWidget.swift` ist fertig implementiert (systemSmall + systemMedium, öffnet App via `focusblox://create-task`). Muss nur noch in `FocusBloxWidgetsBundle.swift` registriert werden.

---

### Bug 22: Edit-Button in Backlog Toolbar ohne Funktion
**Status:** Open
**Priorität:** Mittel
**Bereich:** BacklogView

**Kurzbeschreibung:**
`EditButton()` existiert, aber List hat keinen `.onMove` Handler. Drag-Reorder funktioniert nicht.

---

### Spotlight Integration (Mac)
**Status:** Open
**Priorität:** Should
**Bereich:** macOS

**Kurzbeschreibung:**
CMD+Leertaste → Syntax-Eingabe → Task im Backlog (als tbd).

---

### Control Center Inline-Eingabe (iOS 26+)
**Status:** Open
**Priorität:** Niedrig
**Bereich:** iOS Control Center

**Kurzbeschreibung:**
Interaktives Control Center Widget mit Textfeld fuer direkte Task-Eingabe.

---

### Feature Request: macOS FocusBlox Drag&Drop in Timeline
**Status:** Open
**Priorität:** Niedrig
**Bereich:** macOS MacPlanningView

**Kurzbeschreibung:**
FocusBlox in der Timeline per Drag&Drop verschieben statt nur ueber Dialog.

---

### Feature Request: Shake to Undo → Zurueck zu Backlog
**Status:** Open
**Priorität:** Niedrig
**Bereich:** iOS

**Kurzbeschreibung:**
Versehentlich zu Next Up hinzugefuegt → Shake soll rueckgaengig machen.

---

## Abgeschlossen (Done)

### Feature: Kalender-Events in Review-Statistiken (macOS + iOS)
**Status:** Done ✅ (2026-02-11)
**Commit:** `e6abc5d`

### Bug 34: Duplikate nach CloudKit-Aktivierung
**Status:** Done ✅ (2026-02-11)
**Fix 1:** Reminders-Import auf iOS ueberspringen wenn CloudKit aktiv
**Fix 2 (v2):** externalID-basierte Dedup-Bereinigung bestehender Duplikate
**Commit:** `cd936e6`

### Bug 33: Cross-Platform Sync (CloudKit + App Group auf iOS)
**Status:** Done ✅ (2026-02-11)

### Bug 32: Importance/Urgency Race Condition
**Status:** Done ✅ (2026-02-10)

### Bug 31: Focus Block Startzeit/Endzeit Synchronisation
**Status:** Done ✅ (2026-02-10)

### Bug 30: Kategorie-Bezeichnungen inkonsistent
**Status:** Done ✅ (2026-02-10)

### Bug 29: Duration-Werte korrigiert
**Status:** Done ✅ (2026-02-10)

### Bug 26: macOS Zuweisen Drag&Drop
**Status:** Done ✅ (2026-02-10)

### Bug 25: macOS Planen echte Kalender-Daten
**Status:** Done ✅ (2026-02-10)

### Kategorien in Backlog-View sichtbar
**Status:** Done ✅
**Hinweis:** CategoryBadge in BacklogRow implementiert mit Icon, Farbe und Tap-Handler.

### Details von Erinnerungen auf Klick
**Status:** Done ✅
**Hinweis:** TaskDetailSheet mit voller Editierbarkeit (Title, Priority, Duration, Tags, etc.)

### Reihenfolge im Focus Block veraenderbar
**Status:** Done ✅
**Hinweis:** Drag & Drop in FocusBlockCard via `.draggable()` + `onReorderTasks`.

### Tasks im Backlog als erledigt markieren
**Status:** Done ✅
**Hinweis:** Swipe-Actions: Rechts = Next Up, Links = Delete + Edit.

### Backlog Row Redesign
**Status:** Done ✅
**Hinweis:** Glass Card Layout mit Chips (Importance, Urgency, Category, Duration), `.ultraThinMaterial` Backgrounds, Swipe-Actions.

### Bug 17: BacklogRow Badges als Chips
**Status:** Done ✅
**Hinweis:** Alle Badges (Importance, Urgency, Category, Duration) als Chips mit Material-Hintergrund und Farb-Kodierung.

### TBD Tasks (Unvollstaendige Tasks)
**Status:** Done ✅ (2026-01-26)
**Spec:** `docs/specs/features/tbd-tasks.md`

### Sprint 6: Wochen-Rueckblick
**Status:** Done ✅
**Commit:** `cc2d34a`

### Sprint 5: Tages-Rueckblick
**Status:** Done ✅
**Spec:** `docs/specs/features/daily-review.md`

### Sprint 4: Live Activity
**Status:** Done ✅
**Spec:** `docs/specs/features/live-activity.md`

### Sprint 3: Kategorien erweitern (5 statt 3)
**Status:** Done ✅
**Commit:** `5c054ef`

### Sprint 2: Vorwarnung vor Block-Ende
**Status:** Done ✅
**Commit:** `247dc76`

### Sprint 1: End-Gong/Sound
**Status:** Done ✅

### Kalender auswaehlbar machen (Settings)
**Status:** Done ✅
**Commit:** `3bcd378`

### Quick Capture (Task 7, 7b, 8, 10)
**Status:** Done ✅
**Hinweis:** Control Center Fix, Compact QuickCaptureView, Home Screen Widget (Code), Siri Shortcut

### Themengruppe A-F
**Status:** Done ✅
**Hinweis:** Next Up Layout, State Management, Drag&Drop, Focus Block Ausfuehrung, Sprint Review - alle abgeschlossen.
