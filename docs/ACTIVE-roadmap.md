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

## Geplant (Open)

### Kategorien in Backlog-View sichtbar machen
**Status:** Open
**Prioritaet:** Hoch
**Bereich:** BacklogView, Erinnerungen-Integration

**Kurzbeschreibung:**
Kategorien/Listen aus Apple Erinnerungen anzeigen mit visueller Unterscheidung.

**Offene Fragen:**
- Wie visuell darstellen? (Farbige Chips, Sections, Icons?)
- Gruppieren oder nur als Label?

---

### Sortierung nach Kategorie oder Zeit
**Status:** Open
**Prioritaet:** Mittel
**Bereich:** BacklogView

**Kurzbeschreibung:**
Sortier-Optionen fuer Backlog: nach Kategorie/Liste oder nach Zeit/Faelligkeit.

**Offene Fragen:**
- UI: Dropdown, Segmented Control, oder Menu?
- Persistieren der Sortierung?

---

### Details von Erinnerungen auf Klick anzeigen
**Status:** Open
**Prioritaet:** Mittel
**Bereich:** BacklogView, Detail-Sheet

**Kurzbeschreibung:**
Tap auf Task oeffnet Detail-Ansicht mit Notes, Faelligkeit, Prioritaet, Kategorie.

**Offene Fragen:**
- Modal Sheet oder Navigation Push?
- Editierbar oder nur Anzeige?

---

### Zuordnen-View: Backlog-Bereich vergroessern
**Status:** Open
**Prioritaet:** Mittel
**Bereich:** TaskAssignmentView

**Kurzbeschreibung:**
Zweistufiger Flow: Erst Focus Block auswaehlen, dann Tasks prominent anzeigen.

**Offene Fragen:**
- Zweistufiger Flow oder Split-View?
- Full-Screen Task-Auswahl nach Block-Selection?

---

### Reihenfolge im Focus Block veraenderbar
**Status:** Open
**Prioritaet:** Niedrig
**Bereich:** TaskAssignmentView, FocusLiveView

**Kurzbeschreibung:**
Tasks innerhalb eines Focus Blocks per Drag & Drop umsortierbar.

**Recherche-Frage:** Was ist ein sinnvoller Default? (Eat the Frog, Quick Wins, Prioritaet, Faelligkeit)

---

## Abgeschlossen (Done)

### Kalender auswaehlbar machen (Settings)
**Status:** Done
**Bereich:** Settings, EventKitRepository
**Commit:** 3bcd378

**Kurzbeschreibung:**
User kann auswaehlen, welcher Kalender fuer Focus Blocks verwendet wird.
