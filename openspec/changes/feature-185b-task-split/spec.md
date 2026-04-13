---
entity_id: backlog_hygiene_slice2
type: feature
created: 2026-04-13
updated: 2026-04-13
status: draft
version: "1.0"
tags: [backlog, hygiene, ai, split]
github_issue: "#214"
---

# Backlog-Hygiene — Split-UI mit AI (Slice 2)

## Approval

- [ ] Approved

## Purpose

User kann zu große/vage Tasks in kleinere, machbare Sub-Tasks aufteilen. Apple Foundation Models generiert Vorschläge, User kann diese bearbeiten, ergänzen oder neu generieren lassen.

## User-Erwartung (User-Advocate)

In der Aufräum-Sitzung (BacklogHygieneView) erscheint neben Parken/Löschen/Behalten ein vierter Button "Aufteilen". Der User tippt darauf und sieht nach kurzer Lade-Animation 3-5 konkrete Sub-Task-Vorschläge unter dem Original-Titel. Jeder Vorschlag ist direkt editierbar, löschbar per Swipe, und neue können manuell hinzugefügt werden. Ein "Nochmal"-Button generiert neue Vorschläge. "Erstellen" legt die Sub-Tasks im Backlog an und markiert den alten Task als erledigt — mit klarer, verständlicher Botschaft.

## Scope

| Constraint | Limit |
|-----------|-------|
| Geänderte Dateien | 4 |
| LoC (netto) | ~230 |

## Neue Dateien

| Datei | Zweck |
|-------|-------|
| `Sources/Views/TaskSplitView.swift` | Split-UI: AI-Vorschläge, editierbar, Erstellen-Flow |

## Geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Services/TaskSplitService.swift` | Bereits als POC erstellt — minor Anpassungen |
| `Sources/Views/BacklogHygieneView.swift` | "Aufteilen"-Button hinzufügen |
| `FocusBloxUITests/TaskSplitUITests.swift` | UI Tests für Split-Flow |

## Implementation Details

### 1. TaskSplitView

Neuer Sheet-View, präsentiert von BacklogHygieneView:

**Layout:**
- Header: Original-Task-Titel (nicht editierbar, als Kontext)
- AI-Lade-Indikator während Generierung
- Liste: Editierbare Sub-Task-Vorschläge (TextField pro Item)
- Swipe-to-Delete für ungewollte Vorschläge
- "Hinzufügen"-Button für manuelle Einträge
- "Nochmal vorschlagen"-Button (regeneriert AI-Vorschläge)
- Footer: "Erstellen"-Button (prominent) + Info-Text

**State:**
- `@State var suggestions: [(title: String, minutes: Int)]`
- `@State var isLoading: Bool`
- `@State var showConfirmation: Bool`

**Flow:**
1. View erscheint → AI generiert sofort Vorschläge
2. User editiert/löscht/ergänzt
3. "Erstellen" → Sub-Tasks als neue LocalTasks anlegen
4. Original-Task: `isCompleted = true`, `completedAt = Date()`
5. Dismiss + nächster Task in Hygiene-Sitzung

### 2. BacklogHygieneView-Änderung

Neuer "Aufteilen"-Button neben den bestehenden Aktionen:
- Nur sichtbar wenn `TaskSplitService.isAvailable`
- Öffnet `TaskSplitView` als Sheet
- Nach Split: Task gilt als "aufgeteilt" → HygieneAction `.split`

### 3. TaskSplitService (Anpassung)

POC bereits vorhanden. Keine weiteren Änderungen nötig.

## Acceptance Criteria

- [ ] AC1: "Aufteilen"-Button in Aufräum-View (nur wenn AI verfügbar)
- [ ] AC2: AI generiert 3-5 Sub-Task-Vorschläge mit Zeitschätzung
- [ ] AC3: Vorschläge sind editierbar (Titel ändern)
- [ ] AC4: Vorschläge sind löschbar (Swipe-to-Delete)
- [ ] AC5: Manuell neue Sub-Tasks hinzufügbar
- [ ] AC6: "Nochmal"-Button generiert neue Vorschläge
- [ ] AC7: "Erstellen" legt Sub-Tasks im Backlog an
- [ ] AC8: Original-Task wird als erledigt markiert
- [ ] AC9: Klarer Info-Text: "Dein ursprünglicher Task wird als erledigt markiert"
- [ ] AC10: Lade-Animation während AI-Generierung

## Nicht im Scope

- Zeitschätzungs-Editor pro Sub-Task (wird aus AI übernommen)
- Drag & Drop Reihenfolge
- Undo nach Erstellen
