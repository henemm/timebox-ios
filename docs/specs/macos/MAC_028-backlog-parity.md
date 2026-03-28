---
entity_id: mac_028_backlog_parity
type: feature
created: 2026-03-28
updated: 2026-03-28
status: draft
version: "1.0"
tags: [macos, backlog, parkdeck, stacking, parity]
---

# MAC-028: macOS Backlog Paritat (Parkdeck + Stacking)

## Approval

- [ ] Approved

## Purpose

macOS Backlog erhaelt Feature-Paritat mit iOS fuer zwei zentrale UX-Konzepte: die Parkdeck-Metapher (niedrig-priorisierte und manuell geparkte Tasks in einer collapsed Sektion) und Recurring Stacking (visuelle Gruppierung verpasster Recurring-Instanzen mit Prioritaets-Badge). Beide Features existieren auf iOS, fehlen auf macOS vollstaendig.

## Ist-Zustand

### Feature-Gap: macOS vs iOS Backlog

| Verhalten | iOS | macOS |
|-----------|-----|-------|
| Parkdeck-Sektion (collapsed, low-prio/geparkt) | Ja | Nein (flat Tier-Sektionen) |
| Context Menu "Park" / "Activate" | Ja (Swipe) | Nein (Actions fehlen) |
| Stacking-Gruppierung nach recurrenceGroupID | Ja | Nein |
| Stacking-Badge (x2 / x3+ orange) | Ja | Nein |
| Row-Tint bei >=3 Instanzen (orange) | Ja | Nein |
| Stacked Completion (nur aelteste Instanz) | Ja | Nein |

`parkTask()` und `activateTask()` sind bereits in `ContentView.swift` (Zeilen 866–883) vorhanden und koennen direkt genutzt werden.

## Scope: Was diese Spec abdeckt

### Sub-Feature 1: Parkdeck-Sektion (~80 LoC, ContentView.swift)

**Problem:** macOS zeigt alle Tasks in flachen Tier-Sektionen (doNow, planSoon, eventually, someday). Tasks mit niedrigem Tier oder manuellem Park-Flag verstopfen die aktive Ansicht.

**Loesung:**

Neue Aufteilung der Task-Listen:

```
activeTasks    = Tasks mit Tier .doNow oder .planSoon, isParked == false
parkdeckTasks  = Tasks mit Tier .eventually oder .someday ODER isParked == true
```

UI-Struktur in `ContentView`:
- Bestehende aktive Sektionen bleiben (doNow, planSoon — nur aktiveTasks gefiltert)
- Neue Parkdeck-Sektion am Ende der Backlog-Liste:
  - Header: "Parkdeck" + Badge mit Anzahl parkdeckTasks
  - Collapsed by default (`@State var isParkdeckExpanded = false`)
  - DisclosureGroup oder manueller Toggle
  - Expandiert: zeigt alle parkdeckTasks als MacBacklogRow
- Context Menu pro Task-Row:
  - Aktive Task: "In Parkdeck legen" → `parkTask(task)`
  - Geparkte Task: "Aktivieren" → `activateTask(task)`
  - Beide Aktionen bereits in ContentView vorhanden

**Betroffene Dateien:**

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/ContentView.swift` | Filterfunktionen, Parkdeck-Sektion UI, Context Menu Park/Activate (~80 LoC) |

### Sub-Feature 2: Recurring Stacking (~50 LoC, ContentView.swift + MacBacklogRow.swift)

**Problem:** Verpasste Recurring-Tasks erscheinen als separate Eintraege und erzeugen visuelle Unordnung. iOS gruppiert sie zu einem "Representative" mit Badge.

**Loesung:**

Gruppierungslogik (in ContentView, vor Render):

```
1. Tasks mit recurrenceGroupID gruppieren
2. Pro Gruppe: aelteste Instanz (kleinstes dueDate) = Representative
3. Representative bekommt stackedInstanceCount = Anzahl Instanzen in Gruppe - 1
4. Nicht-Representative-Instanzen werden aus der Render-Liste entfernt
5. stackedInstanceCount ist kein persistierter Wert — wird on-the-fly berechnet
```

Priority Boost am Representative:
```
effectiveScore += TaskPriorityScoringService.stackingBoost(count: stackedInstanceCount)
// stackingBoost: +5 pro Extra-Instanz, max +15 (d.h. ab 4 Instanzen: +15)
```

Badge-Darstellung in `MacBacklogRow`:
```
if stackedInstanceCount == 1:
    Capsule "x2", secondary gray, klein
if stackedInstanceCount >= 2:
    Capsule "x{n+1}", orange foreground + orange.opacity(0.12) background
Row-Tint:
    stackedInstanceCount >= 2 → .orange.opacity(0.06) als listRowBackground
```

Stacked Completion:
- Completion-Action (Checkbox-Tap) → completed wird nur am Representative gesetzt
- Alle anderen Instanzen der Gruppe bleiben unveraendert
- Nach Completion verschwindet Representative → naechstaelteste Instanz wird neuer Representative

**Betroffene Dateien:**

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/ContentView.swift` | Stacking-Gruppierungslogik, stackedInstanceCount Berechnung, Priority Boost (~35 LoC) |
| `FocusBloxMac/MacBacklogRow.swift` | Badge-View (Capsule x2/x3+), orange Row-Tint (~15 LoC) |

## Gesamt-Scope

**2 Dateien, ~130–150 LoC Production — innerhalb Scoping-Limits.**

| Datei | Change Type | Geschaetzte LoC |
|-------|-------------|-----------------|
| `FocusBloxMac/ContentView.swift` | MODIFY | ~115 |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | ~15 |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask.isParked: Bool` | Model Property (Zeile 126) | Filter-Kriterium fuer Parkdeck |
| `LocalTask.recurrenceGroupID: String?` | Model Property (Zeile 69) | Gruppierungsschluessel fuer Stacking |
| `LocalTask.priorityTier` | Model Property | Unterscheidung activeTasks vs parkdeckTasks |
| `TaskPriorityScoringService.stackingBoost()` | Service Method (Zeilen 158–160) | Priority Boost pro Extra-Instanz (+5, max +15) |
| `DeferredCompletionController` | Controller (bereits injected) | Completion-Action fuer Stacked Completion |
| `parkTask()` | ContentView Method (Zeile 866) | Task in Parkdeck verschieben |
| `activateTask()` | ContentView Method (Zeile 883) | Task aus Parkdeck aktivieren |
| `FocusBloxMac/MacBacklogRow.swift` | Target View | Empfaengt `stackedInstanceCount`, rendert Badge + Tint |
| `FocusBloxMac/ContentView.swift` | Target View | Parkdeck-Sektion + Stacking-Logik |
| `docs/specs/rework/2.4-backlog-ux-rework.md` | Reference | iOS Parkdeck-Implementierungsdetails |
| `docs/specs/rework/3.5-recurring-stacking.md` | Reference | iOS Stacking-Implementierungsdetails |

## Implementation Details

### Filterfunktionen (ContentView)

```swift
// Parkdeck-Filter (isInParkdeck entspricht iOS-Logik)
private var activeTasks: [LocalTask] {
    allTasks.filter {
        !$0.isParked &&
        ($0.priorityTier == .doNow || $0.priorityTier == .planSoon)
    }
}

private var parkdeckTasks: [LocalTask] {
    allTasks.filter {
        $0.isParked ||
        $0.priorityTier == .eventually ||
        $0.priorityTier == .someday
    }
}
```

### Stacking-Gruppierung (ContentView)

```swift
// Wird auf activeTasks + parkdeckTasks angewendet, bevor gerendert wird
private func applyStacking(_ tasks: [LocalTask]) -> [(task: LocalTask, stackedCount: Int)] {
    var grouped: [String: [LocalTask]] = [:]
    var ungrouped: [LocalTask] = []

    for task in tasks {
        if let gid = task.recurrenceGroupID {
            grouped[gid, default: []].append(task)
        } else {
            ungrouped.append(task)
        }
    }

    var result: [(task: LocalTask, stackedCount: Int)] = ungrouped.map { ($0, 0) }

    for (_, group) in grouped {
        let sorted = group.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let representative = sorted.first!
        let extraCount = sorted.count - 1
        result.append((representative, extraCount))
    }

    return result
}
```

### Badge-View (MacBacklogRow)

```swift
// Parameter: stackedInstanceCount: Int (0 = kein Badge)
if stackedInstanceCount == 1 {
    Text("x2")
        .font(.caption2)
        .padding(.horizontal, 5)
        .background(Capsule().fill(.secondary.opacity(0.2)))
        .foregroundStyle(.secondary)
} else if stackedInstanceCount >= 2 {
    Text("x\(stackedInstanceCount + 1)")
        .font(.caption2.bold())
        .padding(.horizontal, 5)
        .background(Capsule().fill(.orange.opacity(0.12)))
        .foregroundStyle(.orange)
}
```

### Parkdeck-Sektion (ContentView)

```swift
// Am Ende der Backlog-Liste, nach aktiven Sektionen
DisclosureGroup(isExpanded: $isParkdeckExpanded) {
    ForEach(applyStacking(parkdeckTasks), id: \.task.id) { item in
        MacBacklogRow(task: item.task, stackedInstanceCount: item.stackedCount)
            .contextMenu {
                Button("Aktivieren") { activateTask(item.task) }
            }
    }
} label: {
    HStack {
        Text("Parkdeck")
            .font(.headline)
        if !parkdeckTasks.isEmpty {
            Text("\(parkdeckTasks.count)")
                .font(.caption)
                .padding(.horizontal, 6)
                .background(Capsule().fill(.secondary.opacity(0.15)))
        }
    }
}
```

Active Tasks erhalten Context Menu Eintrag "In Parkdeck legen":
```swift
.contextMenu {
    // ... bestehende Eintraege ...
    Button("In Parkdeck legen") { parkTask(item.task) }
}
```

## Expected Behavior

### Parkdeck-Sektion

- **Input:** Backlog-View oeffnen
- **Output:** Aktive Tasks (doNow, planSoon, nicht geparkt) in bestehenden Sektionen; Parkdeck-Sektion collapsed am Ende mit Badge-Count
- **Expand:** Tap auf Parkdeck-Header klappt Sektion auf/zu
- **Park via Context Menu:** Rechtsklick auf aktive Task → "In Parkdeck legen" → Task verschwindet aus aktiver Sektion, erscheint im Parkdeck
- **Activate via Context Menu:** Rechtsklick auf geparkte Task → "Aktivieren" → Task verschwindet aus Parkdeck, erscheint in aktiver Sektion gemaess Tier
- **Side effects:** `isParked` Flag wird per `parkTask()` / `activateTask()` persistiert

### Stacking

- **Input:** Mehrere Tasks mit gleichem recurrenceGroupID in der Backlog-Liste
- **Output:** Nur die aelteste Instanz (fruehestes dueDate) wird angezeigt, mit Badge
- **Badge x2 (1 Extra):** Kleine graue Capsule rechts am Row-Titel
- **Badge x3+ (>=2 Extra):** Orange Capsule, Row-Hintergrund leicht orange getintet
- **Completion:** Checkbox-Tap auf Representative → nur Representative wird abgehakt; naechste Instanz der Gruppe rueckt zum neuen Representative auf
- **Priority Boost:** stackedInstanceCount * 5, max +15 — beeinflusst Sortierung innerhalb der Sektionen
- **Side effects:** Keine Persistierung des stackedInstanceCount — wird bei jedem Render neu berechnet

## Accessibility Identifiers

Fuer UI Tests werden folgende Identifier benoetigt:

| Element | Identifier | Typ |
|---------|-----------|-----|
| Parkdeck-Sektion Header | `parkdeckSectionHeader` | Button (DisclosureGroup Toggle) |
| Parkdeck Badge-Count | `parkdeckBadgeCount` | Text |
| Task-Row im Parkdeck | `parkdeckRow_<taskID>` | ListRow |
| Stacking Badge auf Row | `stackingBadge_<taskID>` | Text |
| Context Menu "In Parkdeck legen" | "In Parkdeck legen" | MenuItem (by label) |
| Context Menu "Aktivieren" | "Aktivieren" | MenuItem (by label) |

## Test Plan

### Parkdeck Tests

1. **Parkdeck-Sektion existiert:** Backlog oeffnen → `parkdeckSectionHeader` ist vorhanden
2. **Parkdeck collapsed by default:** `parkdeckSectionHeader` expandiert = false beim ersten Laden
3. **Task parken via Context Menu:** Rechtsklick auf aktive Task → "In Parkdeck legen" → Task nicht mehr in aktiver Sektion, Parkdeck-Badge-Count erhoehen sich um 1
4. **Task aktivieren via Context Menu:** Parkdeck expandieren → Rechtsklick → "Aktivieren" → Task verschwindet aus Parkdeck, erscheint in aktiver Sektion
5. **isParked persistiert:** Nach Parken: App-Neustart → Task bleibt im Parkdeck

### Stacking Tests

6. **Stacking-Badge erscheint:** Task mit recurrenceGroupID + 1 Extra-Instanz → `stackingBadge_<id>` vorhanden, Text "x2"
7. **Orange Badge bei >=3:** Task mit >=2 Extra-Instanzen → Badge-Text "x3" (oder hoeher), orange Farbe
8. **Nur Representative sichtbar:** 3 Tasks gleicher recurrenceGroupID → nur 1 Row in der Liste
9. **Stacked Completion:** Checkbox auf Representative → nur Representative completed, Gruppe hat jetzt N-1 Instanzen, naechste aelteste Instanz ist neuer Representative
10. **Priority Boost wirkt auf Sortierung:** Gestackter Task erscheint hoeher als ungestackter Task mit gleichem Basis-Score

## Known Limitations

- `stackedInstanceCount` wird nicht persistiert — bei jedem Render neu berechnet. Bei sehr grossen Listen (>500 Tasks) koennte dies zu Performance-Kosten fuehren. Akzeptabel fuer aktuellen Scope.
- Stacking gilt nur fuer Tasks mit `recurrenceGroupID` — manuell duplizierte Tasks ohne gleiche ID werden nicht gestackt.
- Parkdeck-Expanded-State wird nicht persistiert — Sektion ist nach App-Neustart immer collapsed. Bewusste Entscheidung (Less clutter by default).
- Context Menu auf macOS zeigt Park/Activate nur im Backlog, nicht in anderen Views. Kein cross-view Scope.
- `priorityTier` Enum-Cases muessen mit iOS-Definitionen uebereinstimmen — Abweichungen werden nicht extra abgefangen.

## Ausdruecklich NICHT im Scope

| Feature | Warum nicht |
|---------|-------------|
| iOS Parkdeck aendern | iOS ist bereits fertig, kein Scope |
| Parkdeck auf Planning View oder Focus View | Nur Backlog-View, kein Cross-View |
| Drag & Drop ins Parkdeck | Separates Feature, zu grosser Scope |
| Recurring Stacking auf iOS anpassen | iOS fertig, kein Scope |
| Neues Datenmodell fuer stackedInstanceCount | Bewusst ephemer (on-the-fly) |

## Risiken

| Risiko | Mitigation |
|--------|-----------|
| `applyStacking()` filtert Tasks aus, die eigentlich angezeigt werden sollten | Unit Test: Anzahl gerenderter Rows == Anzahl unique recurrenceGroupIDs + ungrouped Tasks |
| `parkTask()` / `activateTask()` muessen korrekte Tier-Werte setzen | Vor Implementation: Zeilen 866–883 in ContentView lesen und Seiteneffekte auf priorityTier pruefen |
| DisclosureGroup auf macOS verhalt sich anders als auf iOS | Visuellen Test mit Screenshot nach erster Implementation |
| recurrenceGroupID-Vergleich ist case-sensitive | Sicherstellen dass IDs konsistent UUID-Format haben (kein Mixed-Case) |

## Changelog

- 2026-03-28: Initial spec created
