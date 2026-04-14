---
entity_id: bug-219-hygiene-repeat
type: bugfix
created: 2026-04-14
updated: 2026-04-14
status: implemented
version: "1.0"
tags: [backlog, hygiene, grace-period]
---

# Bug #219: Tasks werden zur Hygiene vorgeschlagen, obwohl bereits bearbeitet

## Approval

- [ ] Approved

## Purpose

Fix: `keepTask()` in BacklogHygieneView persistiert `hygieneReviewedAt` nicht. Tasks tauchen sofort wieder als stale auf statt nach der Grace Period.
Zusätzlich: Grace Period ist hardcoded 30 Tage, soll aber `backlogStaleAgeDays` (konfigurierbar, Default 14) nutzen.

## Source

- **File:** `Sources/Views/BacklogHygieneView.swift`
- **Identifier:** `keepTask()`
- **File:** `Sources/Services/BacklogHealthService.swift`
- **Identifier:** `hygieneReviewGraceDays`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| LocalTask | Model | `hygieneReviewedAt: Date?` Feld |
| PlanItem | Model | Read-only Mapping von LocalTask |
| BacklogHealthService | Service | `findStaleTasks()` mit Grace-Period-Filter |
| AppSettings | Config | `backlogStaleAgeDays` (konfigurierbar, Default 14) |

## Implementation Details

### Fix 1: keepTask() persistiert hygieneReviewedAt

```swift
private func keepTask() {
    if let task = currentTask, let localTask = findLocalTask(id: task.id) {
        localTask.hygieneReviewedAt = Date()
        localTask.modifiedAt = Date()
        try? modelContext.save()
    }
    actions.append(.kept)
    // ... rest bleibt gleich
}
```

### Fix 2: Grace Period nutzt backlogStaleAgeDays

```swift
// BacklogHealthService.swift
// VORHER: static let hygieneReviewGraceDays = 30
// NACHHER: kein hardcoded Wert mehr

static func findStaleTasks(
    in tasks: [PlanItem],
    staleAgeDays: Int = 14,
    staleRescheduleCount: Int = 3
) -> [PlanItem] {
    // ...
    if let reviewedAt = task.hygieneReviewedAt {
        let daysSinceReview = calendar.dateComponents([.day], from: reviewedAt, to: now).day ?? 0
        if daysSinceReview < staleAgeDays {  // statt hygieneReviewGraceDays
            return false
        }
    }
}
```

### Nicht geändert:
- `splitCompleted()`: Split-Abbruch soll NICHT als reviewed gelten. Erfolgreicher Split setzt `isCompleted=true` → Task wird ohnehin rausgefiltert.
- UI-Hint (Z.139): Zeigt bereits `backlogStaleAgeDays` → ist jetzt korrekt.

## Expected Behavior

- **Input:** User klickt "Behalten" im Hygiene-Dialog
- **Output:** Task bekommt `hygieneReviewedAt = Date()`, wird für `backlogStaleAgeDays` Tage (Default 14) nicht mehr als stale vorgeschlagen
- **Side effects:** TabBar Badge (iOS) und Sidebar Badge (macOS) aktualisieren sich korrekt

## Acceptance Criteria

1. Nach "Behalten" wird `hygieneReviewedAt` auf dem LocalTask gesetzt
2. Task taucht nicht mehr als stale auf innerhalb der Grace Period
3. Grace Period = `backlogStaleAgeDays` (konfigurierbar, Default 14)
4. UI-Hint zeigt korrekten Wert
5. Bestehende Unit Tests bleiben grün (mit angepasster Grace Period)
6. Build kompiliert auf iOS und macOS

## Known Limitations

- macOS hat keinen Hygiene-Dialog (separates Feature-Gap)
- Split-Abbruch zählt nicht als reviewed (Product-Entscheidung)

## Changelog

- 2026-04-14: Initial spec created
- 2026-04-14: Implemented — keepTask() setzt hygieneReviewedAt, Grace Period nutzt staleAgeDays
