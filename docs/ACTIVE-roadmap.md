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

<!-- Features mit fertiger Spec, Implementation noch ausstehend -->

<!-- Beispiel-Format:
### [Feature Name]
**Status:** Spec Ready
**Spec:** docs/specs/[category]/[name].md
**Prioritaet:** Hoch / Mittel / Niedrig

**Kurzbeschreibung:**
[1-2 Saetze was das Feature tut]
-->

_Keine Features mit fertiger Spec_

---

## In Arbeit

<!-- Beispiel-Format:
### [Feature Name]
**Status:** In Progress
**Phase:** TDD RED / Implementation / Validation
**Prioritaet:** Hoch / Mittel / Niedrig
**Kategorie:** Primary / Support / Passive Feature
**Aufwand:** Klein / Mittel / Gross

**Kurzbeschreibung:**
[1-2 Saetze was das Feature tut]

**Betroffene Systeme:**
- [System 1]
- [System 2]
-->

### Task 12b: Sprint Review UI
**Status:** Done ✅
**Phase:** Complete (2026-01-26)
**Priorität:** Hoch
**Bereich:** SprintReviewSheet

**Implementiert:**
- Zeit-Anzeige: "X min geplant" + "Y min gebraucht" mit Differenz
- Task-Status umschaltbar (Tap auf Checkbox)
- Stats Header mit "gebraucht" Spalte

---

## User Story Roadmap (Priorität 1)

> Basiert auf: `docs/project/stories/timebox-core.md`
> Gap-Analyse: `docs/context/user-story-gap-analysis.md`

_Alle User Story Features abgeschlossen - siehe "Abgeschlossen" unten_

---

## Quick Capture (User Story)

> Story: `docs/project/stories/quick-capture.md`
> JTBD: "Gedanken festhalten, bevor sie weg sind"

### TBD Tasks (Unvollständige Tasks)
**Status:** Done ✅
**Phase:** Validation complete (2026-01-26)
**Priorität:** Must
**Bereich:** App (alle Plattformen)
**Spec:** `docs/specs/features/tbd-tasks.md`
**Artifacts:** `docs/artifacts/tbd-tasks/`

**Kurzbeschreibung:**
Tasks ohne Wichtigkeit/Dringlichkeit/Dauer werden mit `tbd` Tag markiert (kursiver Titel). Keine Fake-Defaults mehr. TBD ViewMode für fokussierte Vervollständigung. Inkl. Umbenennung "Priorität" → "Wichtigkeit".

**Tests:** 14 Unit Tests + 11 UI Tests = 25 Tests GRÜN

---

### Watch Voice Capture
**Status:** Open
**Priorität:** Must
**Bereich:** watchOS App

**Kurzbeschreibung:**
Button-Tap → Spracheingabe → Task landet im Backlog (als tbd).

---

### Quick Add Widget (iOS)
**Status:** Open
**Priorität:** Must
**Bereich:** iOS WidgetKit

**Kurzbeschreibung:**
Home/Lock Screen Widget für schnelle Task-Eingabe (1-2 Taps). Task landet als tbd.

---

### Spotlight Integration (Mac)
**Status:** Open
**Priorität:** Should
**Bereich:** macOS

**Kurzbeschreibung:**
CMD+Leertaste → Syntax-Eingabe → Task im Backlog (als tbd).

---

## Weitere Features (Priorität 2)

### Kategorien in Backlog-View sichtbar machen
**Status:** Open
**Prioritaet:** Mittel
**Bereich:** BacklogView, Erinnerungen-Integration

**Kurzbeschreibung:**
Kategorien/Listen aus Apple Erinnerungen anzeigen mit visueller Unterscheidung.

---

### Details von Erinnerungen auf Klick anzeigen
**Status:** Open
**Prioritaet:** Mittel
**Bereich:** BacklogView, Detail-Sheet

**Kurzbeschreibung:**
Tap auf Task oeffnet Detail-Ansicht mit Notes, Faelligkeit, Prioritaet, Kategorie.

---

### Reihenfolge im Focus Block veraenderbar
**Status:** Open
**Prioritaet:** Niedrig
**Bereich:** TaskAssignmentView, FocusLiveView

**Kurzbeschreibung:**
Tasks innerhalb eines Focus Blocks per Drag & Drop umsortierbar.

---

### Tasks im Backlog als erledigt markieren
**Status:** Open
**Prioritaet:** Mittel
**Bereich:** BacklogView, BacklogRow

**Kurzbeschreibung:**
Tasks direkt in der Backlog-View auf "erledigt" setzen (Checkbox/Swipe-Action).

---

### Backlog Row Redesign
**Status:** Open (Konzept erstellt)
**Prioritaet:** Mittel
**Bereich:** BacklogView, BacklogRow, DurationBadge
**Konzept:** docs/concepts/backlog-row-redesign.md

**Kurzbeschreibung:**
Klarere Darstellung der Task-Informationen: Checkbox links (iOS-Standard), verstaendliche Prioritaets-Anzeige, Swipe-Actions statt versteckter Buttons, bessere visuelle Hierarchie.

**Abhaengigkeit:** "Tasks als erledigt markieren" sollte zuerst/zusammen umgesetzt werden.

---

## Abgeschlossen (Done)

### Sprint 6: Wochen-Rückblick
**Status:** Done
**Bereich:** DailyReviewView (erweitert)
**Commit:** cc2d34a

**Kurzbeschreibung:**
"Womit habe ich meine Woche verbracht?" - Segmented Picker im Rückblick-Tab ermöglicht Wechsel zwischen Tages- und Wochen-Ansicht. Wochen-Ansicht zeigt Zeit pro Kategorie als horizontale Balken.

---

### Sprint 5: Tages-Rückblick
**Status:** Done
**Bereich:** DailyReviewView, MainTabView
**Spec:** docs/specs/features/daily-review.md

**Kurzbeschreibung:**
"Was habe ich heute alles geschafft?" - Neuer Tab zeigt Übersicht aller erledigten Tasks des Tages, gruppiert nach Focus Blocks.

---

### Sprint 4: Live Activity (Lockscreen/Dynamic Island)
**Status:** Done
**Bereich:** ActivityKit, FocusBloxWidgets, FocusLiveView
**Spec:** docs/specs/features/live-activity.md

**Kurzbeschreibung:**
Focus Block Timer auf Lock Screen und Dynamic Island anzeigen mit Countdown und aktuellem Task.

---

### Sprint 3: Kategorien erweitern (5 statt 3)
**Status:** Done
**Bereich:** LocalTask, CreateTaskView, BacklogView
**Commit:** 5c054ef

**Kurzbeschreibung:**
2 neue Kategorien: `learning` (Lernen), `giving_back` (Weitergeben).

---

### Sprint 2: Vorwarnung vor Block-Ende
**Status:** Done
**Bereich:** FocusLiveView, SettingsView, SoundService
**Commit:** 247dc76

**Kurzbeschreibung:**
Prozentbasierte Vorwarnung (10/20/30% vor Ende) mit Sound + Haptic.

---

### Sprint 1: End-Gong/Sound
**Status:** Done
**Bereich:** FocusLiveView, SettingsView, SoundService
**Commit:** (Teil von Sound-System)

**Kurzbeschreibung:**
Akustisches Signal am Block-Ende. System-Sound, konfigurierbar.

---

### Kalender auswaehlbar machen (Settings)
**Status:** Done
**Bereich:** Settings, EventKitRepository
**Commit:** 3bcd378

**Kurzbeschreibung:**
User kann auswaehlen, welcher Kalender fuer Focus Blocks verwendet wird.
