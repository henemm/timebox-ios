# NextUp Long Press Preview

## Problem
NextUpRow und DraggableTaskRow zeigen nur Titel + Dauer. Der User kann keine Attribute (Wichtigkeit, Dringlichkeit, Kategorie, Tags, Frist, Beschreibung) sehen, ohne den Task zu bearbeiten.

## Loesung
`.contextMenu(menuItems:preview:)` auf NextUpRow und DraggableTaskRow. Die Preview zeigt alle Task-Attribute als read-only Ansicht.

## Scope
- **iOS only** (macOS NextUp nutzt bereits MacBacklogRow mit vollen Attributen)
- **Nur NextUp-Darstellungen** (NextUpRow, DraggableTaskRow)
- **Nicht** BacklogRow (zeigt bereits alles)

## Betroffene Stellen
1. `Sources/Views/NextUpSection.swift` — NextUpRow (Zeile 83-122)
2. `Sources/Views/TaskAssignmentView.swift` — DraggableTaskRow (Zeile 561+)

## Neue Datei
- `Sources/Views/TaskPreviewView.swift` — Shared read-only Preview-View

## TaskPreviewView zeigt
- Titel (fett, mehrzeilig)
- Kategorie (Icon + Name, farbig)
- Wichtigkeit (Icon + Label)
- Dringlichkeit (Icon + Label)
- Dauer (mit Icon)
- Tags (alle, nicht nur 2)
- Frist/Due Date (mit Kalender-Icon)
- Wiederkehrend-Badge (falls recurring)
- Priority Score
- Beschreibung (falls vorhanden, max 3 Zeilen)

## Context Menu Aktionen
NextUpRow: Bearbeiten, Aus Next Up entfernen, Loeschen
DraggableTaskRow: Bearbeiten (via Edit Sheet), Loeschen

## Aenderungen (~3 Dateien, ~120 LoC)
1. **NEU** `TaskPreviewView.swift` (~80 LoC) — Read-only Attribut-Ansicht
2. **EDIT** `NextUpSection.swift` (~15 LoC) — `.contextMenu` auf NextUpRow + Callbacks durchreichen
3. **EDIT** `TaskAssignmentView.swift` (~15 LoC) — `.contextMenu` auf DraggableTaskRow

## Tests
- Unit Test: TaskPreviewView rendert mit allen PlanItem-Attributen
- UI Test: Long Press auf NextUpRow zeigt Preview
