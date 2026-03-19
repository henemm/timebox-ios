---
entity_id: feature-026-priority-sort-coach-boost
type: feature
created: 2026-03-19
updated: 2026-03-19
status: implemented
version: "1.0"
tags: [priority, sorting, coach, monster-mode, overdue, ios, macos]
---

# FEATURE_026: Priority View — Einheitliche Score-Sortierung & Coach-Boost

## Approval

- [x] Approved

## Purpose

Die Priority-View hat drei Inkonsistenzen: (1) Ueberfaellig-Section sortiert nach Datum statt Priority Score, (2) ueberfaellige Daten werden im Badge nicht rot hervorgehoben, (3) Coach-Modus zieht Tasks in eine separate lila Section statt den Score zu boosten. Diese Aenderungen vereinheitlichen die Sortierung auf Priority Score und integrieren den Coach-Boost unsichtbar in das bestehende Tier-System.

## Source

- **Primaere Dateien:** `Sources/Views/BacklogView.swift`, `FocusBloxMac/ContentView.swift`
- **Scoring:** `Sources/Services/TaskPriorityScoringService.swift`
- **Date-Extension:** `Sources/Extensions/Date+DueDate.swift`
- **Row-Views:** `Sources/Views/BacklogRow.swift`, `FocusBloxMac/MacBacklogRow.swift`

## Problem (IST-Zustand)

### 1. Inkonsistente Sortierung
- Ueberfaellig-Section: `.sorted { dueDate }` (aeltestes Datum zuerst)
- Tier-Sections: `.sorted { priorityScore }` (hoechster Score zuerst)
- Erwartung: Ueberall Priority Score

### 2. Ueberfaellige Daten nicht hervorgehoben
- Datum-Badge wird nur bei `isDueToday` rot
- Vergangene Daten (gestern, letzte Woche) bleiben grau
- User erkennt nicht auf einen Blick welche Tasks ueberfaellig sind

### 3. Coach-Boost als separate Section
- Monster-Modus zieht passende Tasks in eigene lila "Coach-Boost" Section
- Tasks erscheinen NICHT mehr in ihren normalen Tiers
- Fuehrt zu Duplikat-Problemen (BUG_107) und unerwarteter Task-Verschiebung

## Solution (SOLL-Zustand)

### 1. Ueberfaellig-Section: Score-Sortierung
```swift
// VORHER:
.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

// NACHHER:
.sorted { effectivePriorityScore(for: $0) > effectivePriorityScore(for: $1) }
```

### 2. Ueberfaellige Daten rot hervorheben
```swift
// Neue Property in Date+DueDate.swift:
var isOverdue: Bool {
    self < Calendar.current.startOfDay(for: Date())
}

// 4 Stellen aktualisiert:
.foregroundStyle((dueDate.isDueToday || dueDate.isOverdue) ? .red : .secondary)
```

### 3. Coach-Modus = Score-Boost (+15)
- Coach identifiziert passende Tasks (Logik bleibt in `CoachBacklogViewModel`)
- Statt eigener Section: `+15` auf Priority Score
- Tasks bleiben in ihren normalen Sections (Next Up, Ueberfaellig, Tiers)
- Ranken dort nur hoeher dank Boost

```swift
static let coachBoostValue = 15

// In effectivePriorityScore / scoreFor:
let boost = coachBoostedIDs.contains(item.id) ? TaskPriorityScoringService.coachBoostValue : 0
return min(100, base + boost)
```

### Warum +15?
- Score-Bereich: 0-100
- Tier-Grenzen: 60 (Sofort), 35 (Bald), 10 (Gelegenheit)
- +15 verschiebt ca. eine Stufe nach oben — spuerbar, nicht dominant
- Vergleichbar mit Neglect-Komponente (0-15)
- Cap bei 100 bleibt

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `TaskPriorityScoringService` | Service | Score-Berechnung + neue `coachBoostValue` Konstante |
| `CoachBacklogViewModel` | ViewModel | `coachBoostedTasks(from:selectedCoach:)` liefert boost-wuerdige Tasks |
| `DeferredSortController` | Service | Frozen Scores fuer stabile UI bei Quick-Edits |
| `Date+DueDate` | Extension | Neue `isOverdue` Property |

## Affected Files

| Datei | Aenderung |
|-------|-----------|
| `Sources/Extensions/Date+DueDate.swift` | `isOverdue` Property |
| `Sources/Services/TaskPriorityScoringService.swift` | `coachBoostValue = 15` |
| `Sources/Views/BacklogView.swift` | Coach-Section entfernt, Score-Boost in `effectivePriorityScore`, Overdue Score-Sort, `tierBacklogTasks` entfernt |
| `Sources/Views/BacklogRow.swift` | `effectiveScore` Parameter, `isOverdue` im Badge |
| `Sources/Views/TaskDetailSheet.swift` | `isOverdue` im Badge |
| `Sources/Views/TaskPreviewView.swift` | `isOverdue` im Badge |
| `FocusBloxMac/ContentView.swift` | Analog zu BacklogView: Coach-Section entfernt, Score-Boost in `scoreFor`, `tierFilteredTasks` entfernt |
| `FocusBloxMac/MacBacklogRow.swift` | `isOverdue` im Badge |

## Expected Behavior

- **Ueberfaellig-Section:** Tasks nach Priority Score absteigend sortiert (hoechster zuerst)
- **Datum-Badge:** Rot bei `isDueToday` ODER `isOverdue` (vergangene Daten)
- **Coach-Modus aktiv:** Passende Tasks bekommen +15 Score, bleiben aber in normalen Sections
- **Coach-Boost Section:** Existiert nicht mehr (kein `coachBoostSection` Accessibility Identifier)
- **MonsterIntentionHeader:** Bleibt sichtbar wenn Coach aktiv
- **Score-Cap:** Maximal 100, auch mit Boost

## Known Limitations

- BUG_107 (Cross-Section-Overlap) wird obsolet — kein Duplikat-Problem mehr da keine separate Section
- Coach-Boost ist nicht visuell gekennzeichnet (kein lila Indikator am Task) — Tasks ranken einfach hoeher

## Changelog

- 2026-03-19: Implementiert (retroaktive Spec)
