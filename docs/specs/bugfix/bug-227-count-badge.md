---
entity_id: bug-227-count-badge
type: bugfix
created: 2026-04-15
updated: 2026-04-15
status: draft
version: "1.0"
tags: [badge, scoring, consistency]
---

# Bug #227: Count-Badge Inkonsistenz + Overdue-Score-Anpassung

## Approval

- [ ] Approved

## Purpose

Alle Badge-Zähler (App-Icon, Tab-Badge, macOS Sidebar) auf eine einheitliche Score-basierte Logik umstellen. Zusätzlich den Deadline-Score für überfällige Tasks von 25 auf 35 erhöhen.

## Änderung 1: Overdue-Score erhöhen

**Datei:** `Sources/Services/TaskPriorityScoringService.swift`

Zeile 103: `case ...0: return 25` → `case ...0: return 35`

**Auswirkung:** Überfällige Tasks mit mindestens "dringend" markiert erreichen automatisch doNow (>= 60). Nur komplett unwichtige oder unbewertete Tasks bleiben darunter.

## Änderung 2: App-Icon-Badge auf doNow umstellen

**Datei:** `Sources/Services/NotificationService.swift`

`countOverdueBadgeTasks()` (Zeile 85-102) ersetzen: Statt überfällige Tasks (dueDate < heute) zu zählen, soll die Methode doNow-Tasks zählen — mit denselben Filtern wie `BacklogBadgeService.countDoNowTasks()`:
- `!isCompleted && !isParked && !isTemplate`
- `!isNextUp && assignedFocusBlockID == nil`
- `priorityTier == .doNow` (Score >= 60)

Methode umbenennen: `countOverdueBadgeTasks` → `countDoNowBadgeTasks`

## Änderung 3: Tab-Badge Filter ergänzen

**Datei:** `Sources/Services/BacklogBadgeService.swift`

Filter in `countDoNowTasks()` erweitern um:
- `!task.isNextUp`
- `task.assignedFocusBlockID == nil`

Damit zählt der Tab-Badge nur Tasks die tatsächlich im Backlog sichtbar sind.

## Änderung 4: macOS Sidebar-Badge auf doNow umstellen

**Datei:** `FocusBloxMac/ContentView.swift`

`overdueCount` (Zeile 145-151) auf dieselbe doNow-Logik umstellen wie `BacklogBadgeService.countDoNowTasks()`.

## Expected Behavior

- **Tab-Badge** = Anzahl Tasks in der "Dringend"-Sektion der Backlog-Liste
- **App-Icon-Badge** = identisch mit Tab-Badge
- **macOS Sidebar** = identisch mit Tab-Badge
- **Eine Zahl, eine Bedeutung:** doNow-Tasks die im Backlog sichtbar sind

## Side Effects

- Tasks die bisher nur durch Datum als "überfällig" im App-Icon gezählt wurden, aber niedrigen Score haben, verschwinden aus dem App-Icon-Badge
- Überfällige Tasks mit mittlerer/hoher Wichtigkeit erscheinen durch den höheren Score (+35) häufiger als doNow und werden somit weiterhin im Badge gezählt

## Known Limitations

- App-Icon-Badge wird nur bei App-Foreground aktualisiert (bestehendes Verhalten, nicht Teil dieses Fixes)

## Changelog

- 2026-04-15: Initial spec created
