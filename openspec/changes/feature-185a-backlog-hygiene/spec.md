---
entity_id: backlog_hygiene_slice1
type: feature
created: 2026-04-12
updated: 2026-04-12
status: draft
version: "1.0"
tags: [backlog, hygiene, coach]
github_issue: "#213"
---

# Backlog-Hygiene — Erkennung + Aufräum-View (Slice 1)

## Approval

- [ ] Approved

## Purpose

Stale Tasks im Backlog erkennen (zu alt, zu oft verschoben) und dem User eine kompakte Aufräum-Sitzung anbieten, in der er pro Task entscheidet: Parken, Löschen oder Behalten.

## User-Erwartung (User-Advocate)

Der User öffnet das Backlog und sieht einen dezenten Hinweis: "3 Tasks liegen seit 2+ Wochen unangetastet. Aufräumen?" Er tippt darauf und durchläuft eine Karten-Sitzung: pro Task wird Name, Alter und Verschiebungen angezeigt, mit 3 klaren Aktionen. Am Ende eine kurze Zusammenfassung.

## Scope

| Constraint | Limit |
|-----------|-------|
| Geänderte Dateien | 5 |
| LoC (netto) | ~250 |

## Neue Dateien

| Datei | Zweck |
|-------|-------|
| `Sources/Services/BacklogHealthService.swift` | Identifiziert stale Tasks |
| `Sources/Views/BacklogHygieneView.swift` | Aufräum-Karten-UI |

## Geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Models/AppSettings.swift` | 2 neue Settings: `backlogStaleAgeDays`, `backlogStaleRescheduleCount` |
| `Sources/Views/BacklogView.swift` | Hygiene-Banner + Navigation zu HygieneView |
| `Sources/Views/SettingsView.swift` | UI für Hygiene-Schwellenwerte |

## Implementation Details

### 1. BacklogHealthService

```swift
@MainActor
struct BacklogHealthService {
    /// Findet Tasks die "stale" sind:
    /// - createdAt älter als `staleAgeDays` UND nicht completed/parked/template
    /// - ODER rescheduleCount >= `staleRescheduleCount`
    static func findStaleTasks(
        in tasks: [PlanItem],
        staleAgeDays: Int = 14,
        staleRescheduleCount: Int = 3
    ) -> [PlanItem]
}
```

**Logik:**
- Task ist stale wenn: `daysSinceCreation >= staleAgeDays` ODER `rescheduleCount >= staleRescheduleCount`
- Ausgeschlossen: `isCompleted`, `isParked`, `isTemplate`, recurring templates
- Sortierung: älteste zuerst

### 2. BacklogHygieneView

Karten-basierte Aufräum-Sitzung:

```
┌─────────────────────────┐
│  Backlog aufräumen       │
│  Task 1 von 3            │
│                          │
│  "Steuererklärung"       │
│  Erstellt vor 23 Tagen   │
│  3× verschoben           │
│                          │
│  ┌────────┐ ┌────────┐  │
│  │ Parken │ │Löschen │  │
│  └────────┘ └────────┘  │
│  ┌────────────────────┐  │
│  │    Behalten         │  │
│  └────────────────────┘  │
└─────────────────────────┘
```

**Aktionen:**
- **Parken**: Setzt `isParked = true` auf dem LocalTask
- **Löschen**: Löscht den Task aus SwiftData
- **Behalten**: Überspringt, zeigt "Wird in X Tagen wieder vorgeschlagen"

**Nach letztem Task → Zusammenfassung:**
```
Backlog aufgeräumt!
1 geparkt · 1 gelöscht · 1 behalten
```

### 3. AppSettings-Erweiterung

```swift
// MARK: - Backlog Hygiene
@AppStorage("backlogStaleAgeDays") var backlogStaleAgeDays: Int = 14
@AppStorage("backlogStaleRescheduleCount") var backlogStaleRescheduleCount: Int = 3
```

### 4. BacklogView-Integration

- Banner oberhalb der Task-Liste wenn `staleTasks.count > 0`:
  ```
  "3 Tasks liegen seit 2+ Wochen rum. Aufräumen?"
  ```
- Button öffnet `BacklogHygieneView` als Sheet
- Auch als Toolbar-Button "Aufräumen" (manuell startbar, auch ohne stale Tasks)

### 5. SettingsView-Erweiterung

Neue Sektion "Backlog-Hygiene":
- Stepper: "Tasks vorschlagen nach X Tagen" (7-90, Default 14)
- Stepper: "Nach X Verschiebungen" (1-10, Default 3)

## Expected Behavior

- **Input:** User tippt auf Hygiene-Banner oder Toolbar-Button
- **Output:** Aufräum-Sheet mit Karten pro stale Task
- **Side effects:** Tasks werden geparkt oder gelöscht in SwiftData

## Edge Cases

- 0 stale Tasks → Banner nicht sichtbar, Toolbar-Button zeigt leeren State
- Alle Tasks "Behalten" → Zusammenfassung zeigt "0 geparkt, 0 gelöscht, 3 behalten"
- Task wird während Sitzung extern geändert → ignoriert (Snapshot beim Start)

## Acceptance Criteria

- [ ] `BacklogHealthService` erkennt stale Tasks (Alter > Schwellenwert ODER rescheduleCount >= Schwellenwert)
- [ ] Schwellenwert konfigurierbar in Settings (Default: 14 Tage, 3× verschoben)
- [ ] Aufräum-View zeigt betroffene Tasks als Karten mit Alter + Verschiebungen
- [ ] Aktion "Parken" setzt `isParked = true`
- [ ] Aktion "Löschen" entfernt Task
- [ ] Aktion "Behalten" überspringt mit Hinweis auf nächsten Vorschlag
- [ ] Zusammenfassung am Ende der Sitzung
- [ ] Banner in BacklogView bei stale Tasks
- [ ] Manuell startbar über Toolbar-Button
- [ ] Platform: iOS + macOS (shared View in Sources/)

## Changelog

- 2026-04-12: Initial spec created (Slice 1 of #185)
