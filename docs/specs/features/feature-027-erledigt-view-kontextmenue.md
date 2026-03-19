---
entity_id: feature-027-erledigt-view-kontextmenue
type: feature
created: 2026-03-19
updated: 2026-03-19
status: draft
version: "1.0"
tags: [ui, backlog, completed, context-menu, swipe, ios, macos]
---

# FEATURE_027: Erledigt-View Kontextmenue & Swipe-Aktionen

## Approval

- [x] Approved

## Purpose

Die "Erledigt"-View soll wie ein Papierkorb funktionieren: primaere Aktion ist Wiederherstellen, Loeschen ist sekundaer. Aktuell fehlen Kontextmenues auf beiden Plattformen, macOS hat keine Moeglichkeit Tasks wiederherzustellen, und iOS zeigt unnoetige Inline-Buttons.

## Ist-Zustand

### iOS (`BacklogView.swift`)
- `CompletedTaskRow`: 2 Inline-Buttons (blauer Undo + roter Trash) in jeder Zeile
- Links-Swipe: "Wiederherstellen" (orange, Full-Swipe)
- Rechts-Swipe: "Loeschen" (rot, Full-Swipe)
- Kein Kontextmenue

### macOS (`ContentView.swift`)
- `taskRowWithSwipe()` wird fuer ALLE ViewModes verwendet — auch Erledigt
- Links-Swipe: "Next Up" (semantisch falsch fuer erledigte Tasks)
- Rechts-Swipe: "Loeschen" + "Bearbeiten"
- Kontextmenue: Generisches `backlogContextMenu` (Als erledigt markieren, Kategorie, Next Up, Loeschen) — alles falsch fuer bereits erledigte Tasks
- **Kein Weg erledigte Tasks wiederherzustellen!**

## Soll-Zustand (beide Plattformen einheitlich)

### Swipe-Aktionen
| Richtung | Aktion | Full-Swipe | Tint |
|----------|--------|------------|------|
| Links | Wiederherstellen | Ja | Orange |
| Rechts | Loeschen | **Nein** | Rot (destructive) |

### Kontextmenue (langer Druck / Rechtsklick)
1. **Wiederherstellen** (Icon: `arrow.uturn.backward.circle`) — prominenter erster Eintrag
2. `Divider`
3. **Loeschen** (Icon: `trash`, role: `.destructive`) — letzter Eintrag, rot

### Inline-Buttons
- **Entfernen** — keine Buttons mehr in der Zeile (iOS `CompletedTaskRow`)
- Swipe + Kontextmenue sind ausreichend

### CompletedTaskRow (iOS) — Vereinfacht
- Checkmark Icon (gruen)
- Titel (strikethrough, secondary)
- "Erledigt vor [Zeit]" (tertiary)
- Keine Action-Buttons rechts

## Aenderungen

### iOS: `Sources/Views/BacklogView.swift`
1. **CompletedTaskRow**: `onUncomplete` und `onDelete` Callbacks entfernen, Buttons entfernen
2. **completedView**: Kontextmenue hinzufuegen (Wiederherstellen + Loeschen)
3. **Rechts-Swipe**: `allowsFullSwipe` von `true` auf `false` aendern

### macOS: `FocusBloxMac/ContentView.swift`
1. **Neue Funktion** `completedTaskRowWithSwipe(task:)` — eigene Swipe-Aktionen fuer erledigte Tasks
2. **Erledigt-Section**: `completedTaskRowWithSwipe` statt `taskRowWithSwipe` verwenden
3. **Neues Kontextmenue** `completedContextMenu(for:)` — nur Wiederherstellen + Loeschen
4. **Neue Funktion** `uncompleteTask(id:)` — nutzt `SyncEngine.uncompleteTask()`

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `Sources/Views/BacklogView.swift` | CompletedTaskRow vereinfachen, Kontextmenue, Swipe anpassen |
| `FocusBloxMac/ContentView.swift` | completedTaskRowWithSwipe, completedContextMenu, uncompleteTask |

## Scoping

- **2 Dateien** betroffen
- **~80 LoC** Aenderungen geschaetzt (Entfernen + Hinzufuegen)
- Keine neuen Dependencies
- Keine neuen Permissions

## Changelog

- 2026-03-19: Initial spec created
