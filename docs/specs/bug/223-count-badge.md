---
entity_id: bug_223_count_badge
type: bugfix
created: 2026-04-14
updated: 2026-04-14
status: draft
version: "1.0"
tags: [badge, backlog, score, ux]
---

# Bug #223: Count Badge unklar

## Approval

- [ ] Approved

## Problem

Das Tab-Badge am Backlog zeigt "stale Tasks" (>= 14 Tage alt oder >= 3x verschoben). Der User kann nicht nachvollziehen, welche Tasks gezählt werden, weil:
1. "Stale" ist ein unsichtbares, nicht erklärbares Konzept
2. Die gezählten Tasks haben keine visuelle Kennzeichnung in der Liste
3. macOS hat gar kein Badge

## Lösung

Badge zeigt **Anzahl Tasks mit Priority Tier "doNow" (Score >= 60)** statt "stale Tasks".

### Warum Score statt Fälligkeit

- Viele Tasks haben kein Enddatum → Fälligkeits-Badge wäre oft 0
- Score ist bereits im Frontend sichtbar (PriorityScoreBadge, rot bei doNow)
- Score berücksichtigt alles: Deadline, Wichtigkeit, Dringlichkeit, Alter, Verschiebungen

### Änderungen

#### 1. MainTabView — Badge-Berechnung ersetzen

**Datei:** `Sources/Views/MainTabView.swift`

Vorher:
```swift
private var staleTaskCount: Int {
    let items = backlogTasks.map { PlanItem(localTask: $0) }
    return BacklogHealthService.findStaleTasks(in: items).count
}
```

Nachher:
```swift
private var doNowTaskCount: Int {
    backlogTasks
        .map { PlanItem(localTask: $0) }
        .filter { $0.priorityTier == .doNow }
        .count
}
```

`.badge(staleTaskCount)` → `.badge(doNowTaskCount)`

#### 2. BacklogRow — Visuelle Markierung für doNow-Tasks

**Datei:** `Sources/Views/BacklogRow.swift`

Tasks mit Tier `.doNow` bekommen eine rote Akzent-Markierung (z.B. rote Leading-Edge oder roter Punkt), damit der User sofort sieht "DAS sind die Tasks aus dem Badge".

#### 3. Hygiene-Banner bleibt unverändert

Der Hygiene-Banner ("X Tasks liegen seit Wochen rum") und das Hygiene-Sheet bleiben wie sie sind — die nutzen weiterhin die Stale-Logik. Das sind zwei verschiedene Konzepte:
- Badge = "diese Tasks brauchen JETZT Aufmerksamkeit" (doNow)
- Hygiene = "diese Tasks gammeln rum" (stale)

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/MainTabView.swift` | Badge-Berechnung: stale → doNow |
| `Sources/Views/BacklogRow.swift` | Rote Akzent-Markierung für doNow-Tasks |

## Nicht betroffen

- `BacklogHealthService` — bleibt unverändert (Hygiene nutzt es weiterhin)
- `NotificationService` — App-Icon-Badge bleibt separate Logik
- `BacklogHygieneView` — Hygiene-Sheet bleibt wie es ist

## macOS

macOS hat keine TabView → kein Tab-Badge. Die visuelle Markierung in BacklogRow greift aber auch auf macOS (shared Code). macOS-Sidebar-Badge ist ein separates Thema (nicht in Scope).

## Acceptance Criteria

- [ ] Tab-Badge zeigt Anzahl doNow-Tasks (Score >= 60)
- [ ] doNow-Tasks in der Backlog-Liste sind visuell rot markiert
- [ ] Badge-Zahl stimmt mit Anzahl rot markierter Tasks überein
- [ ] Hygiene-Banner/-Sheet funktioniert weiterhin wie bisher
- [ ] Beide Tab-Layouts (classic + coach) nutzen neue Logik
- [ ] Build erfolgreich (iOS + macOS)

## Changelog

- 2026-04-14: Initial spec created
