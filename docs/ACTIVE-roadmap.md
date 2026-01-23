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

_Keine Features in Arbeit_

---

## User Story Roadmap (Priorität 1)

> Basiert auf: `docs/project/stories/timebox-core.md`
> Gap-Analyse: `docs/context/user-story-gap-analysis.md`

### Sprint 4: Live Activity (Lockscreen/Dynamic Island)

---

### Sprint 4: Live Activity (Lockscreen/Dynamic Island)
**Status:** Open
**Prioritaet:** Hoch (User Story Core)
**Bereich:** ActivityKit, Widgets

**Kurzbeschreibung:**
Fokus-Block auf Lockscreen und Dynamic Island anzeigen.

---

### Sprint 5: Tages-Rückblick
**Status:** Open
**Prioritaet:** Mittel (User Story)
**Bereich:** Neues View, History-Model

**Kurzbeschreibung:**
"Was habe ich heute alles geschafft?" - Übersicht erledigter Tasks.

---

### Sprint 6: Wochen-Rückblick
**Status:** Open
**Prioritaet:** Mittel (User Story)
**Bereich:** Neues View, History-Model

**Kurzbeschreibung:**
"Womit habe ich meine Woche verbracht?" - Zeit-Analyse nach Kategorie.

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

## Abgeschlossen (Done)

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
