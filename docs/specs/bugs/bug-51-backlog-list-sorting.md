---
entity_id: bug_51_backlog_list_sorting
type: bugfix
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [ios, macos, backlog, sorting, cross-platform]
---

# Bug 51: Backlog-Liste sortiert unterschiedlich auf iOS und macOS

## Approval

- [ ] Approved

## Purpose

Die "Liste"-Ansicht im Backlog sortiert auf iOS und macOS unterschiedlich. Gewuenscht: Neueste Tasks oben, aelteste unten. Beide Plattformen muessen sich identisch verhalten.

## Source

- **iOS:** `Sources/Services/TaskSources/LocalTaskSource.swift:38`
- **iOS:** `Sources/Services/SyncEngine.swift:18`
- **macOS:** `FocusBloxMac/ContentView.swift:36`

## Root Cause Analyse

### Ist-Zustand

| Aspekt | iOS | macOS |
|--------|-----|-------|
| **Sortier-Feld** | `sortOrder` (manuell, inkrementell) | `createdAt` (Erstelldatum) |
| **Richtung** | Aufsteigend (Aeltestes oben) | Absteigend (Neuestes oben) |
| **Daten-Pipeline** | LocalTaskSource → SyncEngine → PlanItem → BacklogView | @Query direkt auf LocalTask |
| **Ergebnis** | Aelteste Tasks oben | Neueste Tasks oben |

### Ursache

**iOS** nutzt zwei Stellen mit aufsteigender Sortierung:

1. `LocalTaskSource.fetchIncompleteTasks()` (Zeile 38):
   ```swift
   descriptor.sortBy = [SortDescriptor(\.sortOrder)]
   // Default ascending → niedrigste sortOrder (aelteste Tasks) oben
   ```

2. `SyncEngine.sync()` (Zeile 18):
   ```swift
   .sorted { $0.rank < $1.rank }
   // rank = sortOrder → nochmal aufsteigend
   ```

**macOS** nutzt eine separate Daten-Pipeline:
```swift
@Query(sort: \LocalTask.createdAt, order: .reverse)
// createdAt absteigend → neueste Tasks oben (korrekt)
```

### Warum sortOrder aufsteigend = aeltestes oben

`sortOrder` wird beim Erstellen inkrementell vergeben (`getNextSortOrder()` in LocalTaskSource.swift:195-201). Neue Tasks bekommen die hoechste Nummer. Aufsteigende Sortierung zeigt daher die aeltesten Tasks zuerst.

## Soll-Zustand

- Beide Plattformen: Neueste Tasks oben, aelteste unten
- Sortierung nach `createdAt` absteigend (semantisch klar, plattformuebergreifend konsistent)

## Fix-Strategie

### Aenderung 1: LocalTaskSource.swift (Zeile 38)

```swift
// Vorher:
descriptor.sortBy = [SortDescriptor(\.sortOrder)]

// Nachher:
descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
```

### Aenderung 2: SyncEngine.swift (Zeile 18)

```swift
// Vorher:
.sorted { $0.rank < $1.rank }

// Nachher:
.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
```

### macOS: Keine Aenderung noetig

`ContentView.swift:36` sortiert bereits korrekt nach `createdAt` absteigend.

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `Sources/Services/TaskSources/LocalTaskSource.swift` | SortDescriptor aendern |
| `Sources/Services/SyncEngine.swift` | sorted-Closure aendern |

**Scope:** 2 Dateien, ~4 LoC netto

## Risiken

- **Manuelle Sortierung (Drag & Drop):** Bug 22 beschreibt, dass der Edit-Button/onMove nicht funktioniert. `sortOrder` wird aktuell nur beim Erstellen gesetzt. Eine Aenderung der Default-Sortierung hat daher keinen Einfluss auf manuelles Reordering (existiert nicht).
- **PlanItem.rank:** Wird von `sortOrder` abgeleitet. Wenn die Fetch-Sortierung geaendert wird, ist `rank` weiterhin verfuegbar, wird aber nicht mehr fuer die Backlog-Sortierung genutzt.

## Test Plan

1. Task A erstellen (aelter), Task B erstellen (neuer)
2. iOS Backlog "Liste" oeffnen → Task B muss oben stehen
3. macOS Backlog oeffnen → Task B muss oben stehen
4. Reihenfolge muss auf beiden Plattformen identisch sein
