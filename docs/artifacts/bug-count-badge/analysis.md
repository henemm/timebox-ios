# Bug #227: Count-Badge Inkonsistenz — Analyse

## User-Erwartung
Badge, Tab-Zahl und Liste zeigen immer exakt dieselbe Menge — ohne Ausnahme, ohne Sonderfälle, ohne Erklärungsbedarf. "Eine Zahl, eine Bedeutung."

## Root Cause
Es gibt **drei völlig unabhängige Zähllogiken**, die verschiedene Dinge messen:

| Badge | Datei | Zählt | Filter |
|-------|-------|-------|--------|
| App-Icon (Homescreen) | `NotificationService.swift:106` | Überfällige Tasks | `dueDate < heute`, nicht NextUp, kein FocusBlock |
| Tab-Badge (Backlog-Tab) | `MainTabView.swift:16` + `BacklogBadgeService.swift` | DoNow-Tasks | Score >= 60, nicht completed/parked/template |
| Backlog-Liste "Dringend" | `BacklogView.swift:105` | Sichtbare DoNow-Tasks | Score >= 60, nicht NextUp, kein FocusBlock, nicht überfällig |

### Konkrete Divergenzen

| Dimension | App-Icon | Tab-Badge | Liste "Dringend" |
|-----------|----------|-----------|-------------------|
| Kriterium | überfällig (Datum) | hoher Score | hoher Score |
| isParked | **nicht gefiltert** | gefiltert | gefiltert |
| isNextUp | gefiltert | **nicht gefiltert** | gefiltert |
| assignedFocusBlockID | gefiltert | **nicht gefiltert** | gefiltert |
| Update-Timing | nur bei App-Foreground | live (@Query) | live (async) |

### Beispiele
- Task mit Score 80, bereits in FocusBlock: Tab-Badge zählt ihn, Liste zeigt ihn NICHT
- Task mit dueDate gestern, Score 30: App-Icon zählt ihn, Tab-Badge NICHT
- Geparkter überfälliger Task: App-Icon zählt ihn, Tab-Badge und Liste NICHT

## Hypothesen
1. **Hauptursache:** Drei verschiedene Semantiken unter demselben visuellen Konzept
2. **Tab-Badge zu hoch:** Ignoriert isNextUp und assignedFocusBlockID
3. **App-Icon zählt anders:** Basiert auf Datum statt Score
4. **Timing-Divergenz:** App-Icon nur bei Foreground, Tab-Badge live

## Blast Radius
- iOS Tab-Badge: `BacklogBadgeService.swift` + `MainTabView.swift`
- iOS App-Icon: `NotificationService.swift` + 2 Aufrufstellen
- macOS Sidebar: Eigene Logik in `ContentView.swift` (teilweise betroffen)
- Widgets/watchOS: NICHT betroffen

## Vorgeschichte
Issue #223 (Commit `97651f3`) hat `BacklogBadgeService` eingeführt und Tab-Badge auf doNow umgestellt — dabei aber die Inkonsistenz zwischen den 3 Zählern nicht behoben.

## Empfehlung
Eine einheitliche Zähllogik für alle Badges: "doNow-Tasks die im Backlog sichtbar sind" (Score >= 60, nicht completed, nicht parked, nicht template, nicht NextUp, kein FocusBlock).
