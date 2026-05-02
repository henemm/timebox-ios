---
entity_id: overdue-marker
type: feature
created: 2026-05-01
updated: 2026-05-01
status: draft
version: "1.0"
tags: [backlog, badge, counter, overdue, ios, macos]
---

# Overdue Marker — Roter Punkt & Counter auf Überfälligkeits-Logik

## Approval

- [x] Approved (Henning, 2026-05-01)

## Purpose

Roter Punkt an einem Task und alle Counter (iOS Tab-Badge, macOS Sidebar-Badge, iOS App-Icon-Badge) wechseln von der Score-basierten `isDoNow`-Logik auf eine uhrzeit-präzise Überfälligkeitsprüfung: `dueDate < jetzt`. Damit zeigt der Counter immer exakt so viele Tasks wie der User rote Punkte im Backlog sieht — diese Kern-Invariante darf niemals brechen. Geschlossene Issues: #288, #294, #296.

## Source

Kein einzelnes File — dieses Feature ändert mehrere koordinierte Stellen:

- **File:** `Sources/Models/PlanItem.swift` — neue Property `isOverdueNow`
- **File:** `Sources/Services/BacklogBadgeService.swift` — Filter auf `isOverdueNow` umstellen
- **File:** `Sources/Services/NotificationService.swift` — `countDoNowBadgeTasks` an `BacklogBadgeService` delegieren
- **File:** `Sources/Views/BacklogRow.swift` — Punkt-Bedingung von `isDoNow` auf `isOverdueNow`
- **File:** `Sources/Views/MainTabView.swift` — 60s-Timer für Live-Refresh
- **File:** `FocusBloxMac/ContentView.swift` — Counter-Filter + 60s-Timer
- **File:** `FocusBloxMac/MacBacklogRow.swift` — Roter Punkt neu hinzufügen (fehlt bisher)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `PlanItem` | model | Quelle der `dueDate`-Property; bekommt neue `isOverdueNow`-Property |
| `BacklogBadgeService` | service | Zentrale Counter-Logik; wird auf `isOverdueNow` umgestellt |
| `NotificationService` | service | App-Icon-Badge; delegiert Filter an `BacklogBadgeService` statt eigene Kopie |
| `BacklogRow` (iOS) | view | Rendert roten Punkt; Bedingung wechselt auf `isOverdueNow` |
| `MacBacklogRow` (macOS) | view | Bekommt erstmals roten Punkt (fehlte bisher) |
| `MainTabView` (iOS) | view | Tab-Badge-Host; bekommt 60s-Timer für Live-Update |
| `ContentView` (macOS) | view | Sidebar-Badge-Host; bekommt 60s-Timer + neuen Filter |
| `StackingCounterBar` | view | Zeigt "X Instanzen aufgelaufen" für Recurring-Tasks (#279) — bleibt unverändert |
| `Date+DueDate.swift` | extension | Bestehende `isOverdue`-Property ist tagesgranular — wird NICHT genutzt; neue Property in `PlanItem` ist uhrzeit-präzise |

## Implementation Details

### 1. Neue Property `PlanItem.isOverdueNow`

```swift
// Sources/Models/PlanItem.swift
var isOverdueNow: Bool {
    guard let dueDate else { return false }
    return dueDate < Date()
}
```

Uhrzeit-präzise. Tasks ohne `dueDate` liefern `false`.

### 2. `BacklogBadgeService` — Filter umstellen

```swift
// Vorher: tasks.filter { $0.isDoNow && !$0.isDone }
// Nachher:
func countOverdueTasks(_ tasks: [PlanItem]) -> Int {
    tasks.filter { $0.isOverdueNow && !$0.isDone }.count
}
```

### 3. `NotificationService` — Delegieren statt duplizieren

`countDoNowBadgeTasks()` (eigene Score-Kopie) wird entfernt. Stattdessen ruft `NotificationService` `BacklogBadgeService.countOverdueTasks(_:)` auf. Einzige Counter-Quelle der Wahrheit.

### 4. `BacklogRow` (iOS) — Bedingung tauschen

```swift
// Vorher: if item.isDoNow { ... roten Kreis zeigen }
// Nachher: if item.isOverdueNow { ... roten Kreis zeigen }
```

Score-Badge in der Row (`isDoNow`-basiert) bleibt unverändert.

### 5. `MacBacklogRow` (macOS) — Roten Punkt hinzufügen

Visuell identisch zu iOS: roter Circle, 8×8 pt, links der Checkbox, nur sichtbar wenn `item.isOverdueNow`.

### 6. Live-Update — 60s-Timer

In `MainTabView` (iOS) und `ContentView` (macOS):

```swift
@State private var timerTick = Date()
let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

// In View:
.onReceive(timer) { _ in timerTick = Date() }
```

Der Badge-Count wird neu berechnet sobald `timerTick` sich ändert (State-Update → View-Refresh).

### 7. Was NICHT geändert wird

- `isDoNow` bleibt erhalten — weiterhin Grundlage für Score-Tier-Sektionen und MenuBar
- Sortier-Logik: unverändert
- Score-Badge in `BacklogRow`/`MacBacklogRow`: unverändert
- MenuBar-Sektion: nutzt bereits tagesgranulare Überfälligkeits-Logik — kein Eingriff
- `StackingCounterBar`: unverändert

## Kern-Invariante

**Counter-Zahl = Anzahl roter Punkte im Backlog. Immer. Ohne Ausnahme.**

Wenn diese Invariante bricht, ist das Feature kaputt. Alle Tests müssen diese Invariante gegen echte Daten prüfen — nicht nur UI-Anzeige.

## Expected Behavior

### Roten Punkt anzeigen

- **Input:** Task mit `dueDate` = gestern 12:00 Uhr, `isDone = false`
- **Output:** Roter Punkt sichtbar (iOS `BacklogRow` + macOS `MacBacklogRow`)

- **Input:** Task mit `dueDate` = morgen 09:00 Uhr
- **Output:** Kein roter Punkt

- **Input:** Task ohne `dueDate`
- **Output:** Kein roter Punkt

### Uhrzeit-Präzision

- **Input:** Task mit `dueDate` = heute 14:00 Uhr; aktuelle Uhrzeit = 13:59
- **Output:** Kein roter Punkt, nicht im Counter
- **Input:** Gleicher Task; aktuelle Uhrzeit = 14:01
- **Output:** Roter Punkt sichtbar, Counter +1 (spätestens nach 60s Live-Update)

### Counter-Konsistenz

- **Input:** 3 Tasks mit `dueDate` in der Vergangenheit, alle `isDone = false`
- **Output:** Counter = 3, exakt 3 rote Punkte im Backlog sichtbar
- **Side effects:** iOS Tab-Badge = 3, macOS Sidebar-Badge = 3, iOS App-Icon-Badge = 3

### Sofortiges Verschwinden bei Mutation

- **Input:** Task mit rotem Punkt wird abgehakt (`isDone = true`)
- **Output:** Punkt verschwindet sofort, Counter -1 synchron

- **Input:** Task mit rotem Punkt bekommt `dueDate` auf morgen verschoben
- **Output:** Punkt verschwindet sofort, Counter -1 synchron

### Tasks ohne dueDate

- **Input:** Task ohne `dueDate`
- **Output:** Kein Punkt, nicht im Counter — kein anderer Hinweis

### Recurring / Stacking

- **Input:** Recurring-Task mit `stackedInstanceCount >= 2`, `dueDate` in der Vergangenheit
- **Output:** Genau 1 roter Punkt am Master-Task; Counter zählt Master einmal; `StackingCounterBar` zeigt "X Instanzen aufgelaufen" separat

### Plattform-Parität

- **Input:** Identischer Task-Zustand auf iOS und macOS
- **Output:** Gleiche Anzahl roter Punkte sichtbar, gleicher Counter-Wert

## Acceptance Criteria (TDD-Grundlage)

| # | Szenario | Erwartetes Ergebnis |
|---|----------|---------------------|
| AC-1 | `dueDate` gestern → `isOverdueNow` | `true` |
| AC-2 | `dueDate` morgen → `isOverdueNow` | `false` |
| AC-3 | `dueDate` nil → `isOverdueNow` | `false` |
| AC-4 | `dueDate` heute 14:00, jetzt 13:59 → `isOverdueNow` | `false` |
| AC-5 | `dueDate` heute 14:00, jetzt 14:01 → `isOverdueNow` | `true` |
| AC-6 | 3 überfällige Tasks → `BacklogBadgeService.countOverdueTasks` | `3` |
| AC-7 | Task abgehakt → Counter | -1 synchron |
| AC-8 | `dueDate` auf morgen → Counter | -1 synchron |
| AC-9 | Task ohne `dueDate` → Counter | 0 Beitrag |
| AC-10 | Recurring mit `stackedInstanceCount=3`, überfällig → Counter | `1` (nur Master) |
| AC-11 | iOS Tab-Badge = macOS Sidebar-Badge für identische Datenlage | Gleicher Wert |
| AC-12 | macOS `MacBacklogRow`: überfälliger Task → roter Punkt sichtbar | UI-Element vorhanden |
| AC-13 | Tap auf Checkbox eines überfälligen Tasks → roter Punkt + Counter | sofort -1 (nicht erst nach 3s-Commit) |
| AC-14 | Cancel der Pending-Completion (Undo) → roter Punkt + Counter | synchron zurück (+1) |

## Known Limitations

- **Live-Update-Granularität:** 60 Sekunden. Ein Task der um 14:00:00 fällig wird, erscheint frühestens um 14:01:00 im Counter — akzeptabel, bewusst gewählt (Battery/Performance-Trade-off).
- **"Seit X Tagen überfällig"-Kontext:** Beim Antippen eines überfälligen Tasks ist kein Kontext sichtbar. Das ist ein User-Advocate-Wunsch, aber bewusst aus dieser Story ausgeschlossen — separates Ticket.
- **Scope-Hinweis:** 7 Code-Dateien überschreiten das CLAUDE.md-Limit von 5. Begründung: Punkt und Counter müssen auf beiden Plattformen konsistent sein; `NotificationService`-Konsolidierung ist zwingend für die Kern-Invariante. Akzeptiert.
- **App-Icon-Badge & Pending:** Der App-Icon-Badge wird über `NotificationService` ohne View-Context aktualisiert und hat keinen Zugriff auf den `DeferredCompletionController`. Während der 3s-Pending-Phase reflektiert das App-Icon-Badge daher kurz noch den alten Wert; nach dem Commit (3s) ist es wieder synchron mit Tab-/Sidebar-Badge. In-App-UI (Tab-Badge iOS, Sidebar-Badge macOS, roter Punkt) ist sofort konsistent (AC-13/AC-14).

## Changelog

- 2026-05-01: Initial spec created (Issues #288, #294, #296)
- 2026-05-02: AC-13/AC-14 ergänzt — Pending-Completion synchron aus Counter ausschließen (Punkt + Tab-/Sidebar-Badge sofort, nicht erst nach 3s-Commit). User-Advocate-Anforderung.
