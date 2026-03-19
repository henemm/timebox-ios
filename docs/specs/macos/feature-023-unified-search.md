---
entity_id: feature-023-unified-search
type: feature
created: 2026-03-18
updated: 2026-03-19
status: draft
version: "1.1"
tags: [macOS, search, backlog, UI]
---

# FEATURE_023: macOS Suche vereinheitlichen

## Approval

- [ ] Approved

## Purpose

macOS Backlog hat ein Inline-TextField ("Neuer Task...") das wie ein Suchfeld aussieht, aber Tasks erstellt. iOS hat Suche klar ueber der Liste und Task-Erstellung via (+) Button. Diese Inkonsistenz verwirrt User. Fix: Quick-Add Bar entfernen, (+) Toolbar-Button mit TaskFormSheet-Dialog hinzufuegen, Suchfeld wie unter iOS direkt ueber der Task-Liste platzieren (statt `.searchable()` in der Toolbar).

## Aenderungen

### 1. Entfernen: Quick-Add Bar (ContentView.swift)

**Was:** HStack mit TextField "Neuer Task..." + plus.circle.fill Button (Zeilen 387-407)
**Warum:** Verwechslungsgefahr mit Suchfeld, schlechte UX

### 2. Hinzufuegen: (+) Toolbar-Button (ContentView.swift)

**Was:** ToolbarItem mit plus-Button der `showCreateTask` Sheet oeffnet
**Wo:** In der backlogView `.toolbar {}` Section
**Ergebnis:** TaskFormSheet (shared, create mode) oeffnet sich als Sheet

### 3. Anpassen: Keyboard Command (FocusBloxMacApp.swift)

**Was:** Cmd+N oeffnet TaskFormSheet statt TextField zu fokussieren
**Wie:** `focusNewTask` Closure aendern zu Sheet-Toggle

### 4. Aendern: Suchfeld ueber Task-Liste (ContentView.swift)

**Was:** `.searchable()` Modifier entfernen, stattdessen Inline-TextField ueber der Task-Liste (wie iOS)
**Warum:** Konsistenz mit iOS — Suche ist direkt sichtbar, nicht versteckt in der Toolbar
**Wie:** TextField mit Lupe-Icon + Binding an `searchText`, platziert als erstes Element ueber der List

### 5. Behalten

- MenuBarView Quick-Add (Kurzeingabe ueber Menuezeile)
- QuickCapturePanel (Cmd+Shift+Space)

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/ContentView.swift` | Quick-Add Bar entfernen, Sheet-State + Toolbar-Button + Sheet-Presentation hinzufuegen |
| `FocusBloxMac/FocusBloxMacApp.swift` | Cmd+N Action anpassen (optional, falls noetig) |

## Geschaetzter Umfang

- ~20 LoC entfernen (Quick-Add Bar + addTask State)
- ~15 LoC hinzufuegen (Sheet-State, Toolbar-Button, Sheet-Modifier)
- 1-2 Dateien

## Akzeptanzkriterien

1. Kein Inline-TextField mehr in der Backlog-Ansicht
2. (+) Button in der Toolbar oeffnet TaskFormSheet als Sheet
3. Suchfeld direkt ueber der Task-Liste (wie iOS), nicht `.searchable()` in der Toolbar
4. Cmd+N oeffnet TaskFormSheet
5. Menuezeilen Quick-Add und Cmd+Shift+Space bleiben unveraendert

## Changelog

- 2026-03-18: Initial spec created
- 2026-03-19: v1.1 — Suchfeld ueber Task-Liste statt .searchable() (iOS-Konsistenz)
