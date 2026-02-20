# Feature Spec: List-Views aufräumen

**Status:** APPROVED
**Datum:** 2026-02-20
**Workflow:** list-views-cleanup
**Plattformen:** iOS + macOS (möglichst gleich)

---

## Problem

Die Backlog-Ansicht hat 9 ViewModes (iOS) bzw. 9 SidebarFilter (macOS). Viele davon werden kaum genutzt und machen die Navigation unübersichtlich. "Next Up" schwebt als separate Sektion über der Liste statt Teil davon zu sein.

## Gewünschtes Verhalten

### ViewModes (iOS) / SidebarFilter (macOS) — 5 statt 9

| # | View | Beschreibung | Sortierung |
|---|------|-------------|------------|
| 1 | **Priorität** (Default) | Alle Tasks nach Priority Score | Überfällige ganz oben, dann 4 Tiers |
| 2 | **Zuletzt** (NEU) | Alle Tasks nach Aktualität | max(createdAt, modifiedAt) desc |
| 3 | **Überfällig** (NEU) | Nur Tasks mit dueDate < heute | Älteste Frist zuerst |
| 4 | **Wiederkehrend** | Recurring Tasks | Bestehende Logik |
| 5 | **Erledigt** | Completed Tasks (7 Tage) | Bestehende Logik |

### Entfallende Views (komplett löschen)

- list (Standard-Liste)
- eisenhowerMatrix (4 Quadranten)
- category (nach Kategorie)
- duration (nach Dauer)
- dueDate (nach Fälligkeit)
- tbd (unvollständige Tasks)

### Next Up als Section in der Liste

- Next Up erscheint als **erste Section** INNERHALB der List (nicht als separate Komponente darüber)
- Erscheint in allen Views AUSSER "Erledigt"
- Bestehende NextUpSection-Komponente wird als Section-Content wiederverwendet

### Priorität-View: Überfällige ganz oben

In der Priorität-Ansicht werden überfällige Tasks (dueDate < heute) als eigene Sektion VOR den 4 Priority-Tiers angezeigt:

1. **Überfällig** (rot) — Tasks mit abgelaufener Frist
2. Sofort erledigen (60-100)
3. Bald einplanen (35-59)
4. Bei Gelegenheit (10-34)
5. Irgendwann (0-9)

### Neues Feld: modifiedAt

- `LocalTask.modifiedAt: Date?` (optional, CloudKit-kompatibel)
- Wird bei jeder Task-Änderung gesetzt (SyncEngine update-Methoden)
- PlanItem bekommt ebenfalls `modifiedAt: Date?`
- "Zuletzt"-Sortierung: `max(createdAt, modifiedAt ?? .distantPast)`

## Betroffene Dateien

1. `Sources/Models/LocalTask.swift` — modifiedAt Feld
2. `Sources/Models/PlanItem.swift` — modifiedAt Property + Mapping
3. `Sources/Services/SyncEngine.swift` — modifiedAt bei Updates
4. `Sources/Views/BacklogView.swift` — ViewMode Enum, Views, Next Up Integration
5. `FocusBloxMac/ContentView.swift` — Filter-Logik, Views
6. `FocusBloxMac/SidebarView.swift` — SidebarFilter Enum
7. `Sources/Views/NextUpSection.swift` — ggf. Anpassung für Section-Integration

## Scope

- **Netto: ca. -270 LoC** (hauptsächlich Löschung)
- 7 Dateien betroffen
- Keine neuen Dependencies
- Keine Info.plist Änderungen
