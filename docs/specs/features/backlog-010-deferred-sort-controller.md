# BACKLOG-010: Shared DeferredSortController

## Problem
Deferred-Sort-Freeze ist auf iOS (BacklogView.swift) und macOS (ContentView.swift) separat implementiert. ~95% identische Logik, unterschiedlicher Code. Hat direkt zu 2 Regressionen gefuehrt.

## Loesung
Shared `DeferredSortController` in `Sources/Services/` extrahieren. Beide Plattformen nutzen denselben Controller.

## Aenderungen

### NEU: Sources/Services/DeferredSortController.swift (~50 LoC)
- `@MainActor @Observable` Klasse
- `freeze(scores:)` — Snapshot aufnehmen (Guard: nicht ueberschreiben)
- `effectiveScore(id:liveScore:)` — Frozen oder Live Score zurueckgeben
- `scheduleDeferredResort(id:onUnfreeze:)` — 3s Timer, 2-Phasen Unfreeze
- `isPending(_:)` — Check ob ID im Pending-Set

### AENDERN: Sources/Views/BacklogView.swift
- ENTFERNEN: `@State frozenSortSnapshot`, `@State pendingResortIDs`, `@State resortTimer`
- ENTFERNEN: `freezeSortOrder()`, `scheduleDeferredResort()`, `effectivePriorityScore()`, `effectivePriorityTier()`
- HINZUFUEGEN: `@Environment(DeferredSortController.self) var deferredSort`
- AENDERN: Alle Badge-Update-Funktionen nutzen `deferredSort.freeze()` + `deferredSort.scheduleDeferredResort()`
- AENDERN: Sort-Closures nutzen `deferredSort.effectiveScore()`
- FIX: `updateCategory()` bekommt `freeze()` Call (fehlte bisher)

### AENDERN: FocusBloxMac/ContentView.swift
- ENTFERNEN: `@State frozenSortSnapshot`, `@State pendingResortIDs`, `@State resortTimer`
- ENTFERNEN: `freezeSortOrder()`, `scheduleDeferredResort()`, `scoreFor()`
- ENTFERNEN: `displayedRegularTasks` (toter Wrapper, BACKLOG-012)
- HINZUFUEGEN: `@Environment(DeferredSortController.self) var deferredSort`
- AENDERN: 4 Badge-Callbacks nutzen Controller
- AENDERN: UUID→String Migration (6 Stellen)
- AENDERN: `filteredTasks`/`regularFilteredTasks` Sort-Closures nutzen `deferredSort.effectiveScore()`

### AENDERN: App-Einstiegspunkte (je +3 LoC)
- FocusBloxApp: `@State var deferredSort = DeferredSortController()` + `.environment(deferredSort)`
- FocusBloxMacApp: analog

## Nicht betroffen
- TaskPriorityScoringService
- PlanItem.priorityScore
- Widget-Scoring
- Bestehende UI Tests (testen Verhalten, nicht Implementierung)

## Acceptance Criteria
- Build erfolgreich auf iOS + macOS
- Alle bestehenden Tests GRUEN
- Grep nach `freezeSortOrder`, `scheduleDeferredResort` in Views: 0 Treffer
- Grep nach `DeferredSortController`: Treffer in BacklogView, ContentView, beide Apps
