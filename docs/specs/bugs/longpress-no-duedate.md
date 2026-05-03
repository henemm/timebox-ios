---
entity_id: bug-longpress-no-duedate
type: bug
created: 2026-05-03
updated: 2026-05-03
status: draft
version: "1.0"
tags: [backlog, contextmenu, longpress, preview]
---

# Bug: Long-Press zeigt keine Preview-Karte bei Tasks ohne Fälligkeitsdatum

## Approval

- [ ] Approved

## Purpose

Folge-Bug zu Feature #300 (commit `527f441e`). Im Backlog erscheint die `TaskPreviewView`-Karte beim Long-Press nicht, wenn ein Task kein `dueDate` gesetzt hat. SwiftUI deaktiviert den gesamten `.contextMenu(menuItems:preview:)`-Modifier — inklusive `preview:` — wenn die `menuItems`-Closure eine leere View liefert. Da der einzige Menu-Eintrag ("Verschieben") an `item.dueDate != nil` gebunden ist, haben alle Tasks ohne Fälligkeitsdatum einen leeren contextMenu-Body, womit Long-Press vollständig deaktiviert wird.

## Source

- **File:** `Sources/Views/BacklogView.swift`
- **Identifier:** `.contextMenu { ... } preview: { TaskPreviewView(task: item) }` — zwei Stellen

| Stelle | Zeile | Sektion |
|--------|-------|---------|
| A | 1123–1129 | "Heute"-Sektion (`nextUpTasks`) |
| B | 1208–1214 | Backlog-Hauptliste (`backlogRowWithSwipe`) |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `BacklogView` | module | Enthält beide betroffenen `.contextMenu`-Aufrufe |
| `TaskPreviewView` | module | Wird als `preview:` angezeigt — tut nichts, wenn contextMenu deaktiviert ist |
| `postponeMenu(for:)` | function | Liefert die "Verschieben"-Optionen — nur sinnvoll bei Tasks mit `dueDate` |
| `taskToEditDirectly` | state | Edit-Auslöser an Stelle A (NextUp-Sektion) |
| `handleEditTap(_:)` | function | Edit-Auslöser an Stelle B (Hauptliste) |

## Root Cause

SwiftUI's `.contextMenu(menuItems:preview:)` API: Wenn `menuItems` eine leere View zurückgibt, wird der gesamte Modifier deaktiviert — der `preview:`-Block wird nicht gezeigt und Long-Press löst kein Haptic-Feedback aus.

Aktueller Code (beide Stellen identisch):

```swift
.contextMenu {
    if item.dueDate != nil {
        postponeMenu(for: item)
    }
} preview: {
    TaskPreviewView(task: item)
}
```

Bei `item.dueDate == nil` → leerer `menuItems`-Body → kein Long-Press, keine Preview.

## Implementation Details

An beiden Stellen wird vor dem bedingten `postponeMenu`-Block ein unbedingter "Bearbeiten"-Button eingefügt. Damit ist der contextMenu-Body nie leer und die Preview-Karte erscheint für alle Tasks.

**Stelle A (Zeile 1123, NextUp-Sektion) — verwendet `taskToEditDirectly`:**

```swift
.contextMenu {
    Button { taskToEditDirectly = item } label: {
        Label("Bearbeiten", systemImage: "pencil")
    }
    if item.dueDate != nil {
        postponeMenu(for: item)
    }
} preview: {
    TaskPreviewView(task: item)
}
```

**Stelle B (Zeile 1208, Hauptliste `backlogRowWithSwipe`) — verwendet `handleEditTap(_:)`:**

```swift
.contextMenu {
    Button { handleEditTap(item) } label: {
        Label("Bearbeiten", systemImage: "pencil")
    }
    if item.dueDate != nil {
        postponeMenu(for: item)
    }
} preview: {
    TaskPreviewView(task: item)
}
```

Die Edit-Aktion folgt dem jeweiligen bestehenden Pfad der Swipe-Aktion ("Bearbeiten") an derselben Stelle — kein neuer Code-Pfad wird eingeführt.

## Expected Behavior

**Benutzer-Sicht:**

- Long-Press auf einen beliebigen Task-Titel im Backlog (Hauptliste UND "Heute"-Sektion) zeigt **immer** die `TaskPreviewView`-Karte — unabhängig davon, ob der Task ein `dueDate` hat.
- Das "Verschieben"-Untermenü erscheint **nur** wenn `dueDate != nil` (unverändert).
- Der neue "Bearbeiten"-Eintrag im contextMenu startet die Inline-Bearbeitung (entspricht Swipe-Aktion "Bearbeiten").

**Zustand vorher:**
- Long-Press auf Task ohne `dueDate` → kein Feedback, keine Karte, kein Menü
- Long-Press auf Task mit `dueDate` → Preview + "Verschieben"-Menü (funktioniert)

**Zustand nachher:**
- Long-Press auf Task ohne `dueDate` → Preview + "Bearbeiten"-Button
- Long-Press auf Task mit `dueDate` → Preview + "Bearbeiten"-Button + "Verschieben"-Menü

**Input:** Long-Press-Geste auf `taskTitle_<uuid>` im Backlog
**Output:** `taskPreviewCard` sichtbar im UI-Baum
**Side effects:** `taskToEditDirectly` / `handleEditTap` wird ausgelöst wenn "Bearbeiten" getippt wird (keine ungewollten Side-Effects durch das Hinzufügen allein)

## Acceptance Criteria (Test-Grundlage)

1. **AC-1:** Long-Press auf einen Task MIT `dueDate` zeigt `taskPreviewCard` (Regression: muss weiterhin funktionieren)
2. **AC-2:** Long-Press auf einen Task OHNE `dueDate` zeigt `taskPreviewCard`
3. **AC-3:** Nach Long-Press auf Task ohne `dueDate` ist das "Verschieben"-Menü NICHT sichtbar
4. **AC-4:** Nach Long-Press auf Task mit `dueDate` ist das "Verschieben"-Menü sichtbar
5. **AC-5:** Tap auf "Bearbeiten" im contextMenu öffnet die Bearbeitungsansicht

## Test-Strategie

**Problem mit bestehendem Test:**
`testBacklogMainListLongPressShowsPreview` ist falsch-grün. Er greift auf den ersten `taskTitle_`-Treffer zu, was Mock-Task `backlogTask1` ist — dieser hat `dueDate = Date()` und funktioniert deshalb auch mit dem Bug.

**Neuer Pflicht-Test:**
Ein UI-Test muss den Mock-Task `backlogTask2` (Titel: `[MOCK] Backlog Task 2`, kein `dueDate`, kein `isNextUp`) gezielt per Accessibility-Identifier ansprechen und nach Long-Press `taskPreviewCard` prüfen.

Dieser Test MUSS ohne den Fix **rot** sein (Silent-Pass-Prüfung durch Adversary).

**Vorgehen Identifier:**
`backlogTask2` hat Titel `[MOCK] Backlog Task 2`. Der Row-Identifier folgt dem Muster `taskTitle_<uuid>`. Der Test muss den passenden Identifier per Titel-Query oder gespeicherter UUID finden — nicht blind den ersten Treffer nehmen.

## Out of Scope

- **macOS (`FocusBloxMac/ContentView.swift:1079`):** Dasselbe `if task.dueDate != nil`-Pattern existiert dort ebenfalls. Auf macOS gibt es kein `.preview:`-Äquivalent, Long-Press-Preview ist iOS-only. Kein Fix im Rahmen dieses Bugs.
- **`postponeMenu` für Tasks ohne `dueDate` sinnvoll machen** ("Auf heute setzen" etc.) — separates Backlog-Item.

## Known Limitations

- Mock-Daten: `backlogTask2` erscheint nur wenn Mock-Modus aktiv ist. UI-Test muss im Mock-Modus laufen.

## Changelog

- 2026-05-03: Initial spec created
