---
entity_id: bug-289-menubar-popover-filter
type: bugfix
created: 2026-04-25
updated: 2026-04-25
status: draft
version: "1.0"
tags: [macos, menubar, filter, swiftdata]
bugs: [289, 287]
---

# Bug #289 + #287 — MenuBar-Popover zeigt falsche Aufgaben

## Approval

- [ ] Approved

## Purpose

Fixes zwei zusammenhängende Bugs: Das macOS MenuBar-Popover zeigt Aufgaben, die im Hauptfenster nicht sichtbar sind (Bug #289), und beim Abhaken eines wiederkehrenden Tasks erscheint eine neue Instanz als scheinbarer "Ersatz" statt die Liste zu verkürzen (Bug #287). Beide Bugs haben denselben Root Cause: `MenuBarView` umgeht die zentrale Filter-Logik des Hauptfensters.

## Problem (in Hennings Sprache)

**Symptom 1 (Bug #289):** Im Popover erscheinen Aufgaben, die im Hauptfenster unsichtbar sind — zum Beispiel wiederkehrende Tasks mit einem Fälligkeitsdatum in der Zukunft, oder Aufgaben, die sich noch im Entwurfs-Status befinden. Der User weiss nicht, welcher Ansicht er trauen soll.

**Symptom 2 (Bug #287):** Wenn ein wiederkehrender Task abgehakt wird, scheint er "die Position zu tauschen" statt zu verschwinden. Was tatsächlich passiert: Die alte Instanz wird als erledigt markiert, aber eine neue (future-dated) Instanz wird sofort angelegt — und das Popover zeigt diese neue Instanz, weil der Filter sie nicht herausfiltert.

## Source

- **File:** `FocusBloxMac/MenuBarView.swift`
- **Identifier:** `struct MenuBarView` — `@Query`-Deklarationen Zeile 25–31

## Root Cause

`MenuBarView` nutzt zwei direkte `@Query`-Deklarationen, die SwiftData ohne Filter-Anpassung befragen:

```swift
// IST (fehlerhaft):
@Query(filter: #Predicate<LocalTask> { !$0.isCompleted && $0.isNextUp })
private var nextUpTasks: [LocalTask]

@Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isNextUp })
private var backlogTasks: [LocalTask]
```

Das Hauptfenster nutzt `LocalTaskSource.fetchIncompleteTasks()` (Zeile 45), das zusätzlich filtert:

```swift
return allIncomplete.filter { $0.isVisibleInBacklog && $0.lifecycleStatus != "raw" }
```

Fehlende Filter im Popover:
- `isVisibleInBacklog == true` — filtert Templates und future-dated Recurring Tasks
- `lifecycleStatus != "raw"` — filtert Refiner-Entwurfs-Tasks
- `assignedFocusBlockID == nil` — filtert Tasks, die einem FocusBlock zugewiesen sind
- `blockerTaskID == nil` — filtert blockierte Sub-Tasks

**Wichtiger technischer Constraint:** `isVisibleInBacklog` ist eine Computed Property auf `LocalTask`. SwiftData `#Predicate` kann Computed Properties nicht verwenden. Der Fix muss als Post-Fetch-Filter in Swift implementiert werden — analog zu `LocalTaskSource.fetchIncompleteTasks()`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBloxMac/MenuBarView.swift` | View | Enthält den fehlerhaften @Query-Filter — hier wird der Fix angewendet |
| `LocalTask.isVisibleInBacklog` | Computed Property | Zentrale Filter-Logik, die das Popover bisher umgeht |
| `LocalTaskSource.fetchIncompleteTasks()` | Function | Referenz-Implementierung — Post-Fetch-Filter muss analog funktionieren |
| `FocusBloxTests/MenuBarFilterTests.swift` | Test (NEU) | Unit Tests für alle 7 Akzeptanz-Kriterien |

## Implementation Details

**Lösung:** `@Query` bleibt für DB-Effizienz erhalten. Neue computed properties filtern die rohen Query-Ergebnisse nach denselben Regeln wie das Hauptfenster.

```swift
// NEU — Post-Fetch-Filter als Computed Properties:
private var filteredBacklogTasks: [LocalTask] {
    backlogTasks.filter {
        $0.isVisibleInBacklog
        && $0.lifecycleStatus != "raw"
        && $0.assignedFocusBlockID == nil
        && $0.blockerTaskID == nil
    }
}

private var filteredNextUpTasks: [LocalTask] {
    nextUpTasks.filter {
        $0.isVisibleInBacklog
        && $0.lifecycleStatus != "raw"
        && $0.assignedFocusBlockID == nil
        && $0.blockerTaskID == nil
    }
}
```

`backlogPreview` und `nextUpPreview` (die View-Properties, die die angezeigten Tasks liefern) werden auf `filteredBacklogTasks` bzw. `filteredNextUpTasks` umgestellt — statt bisher direkt auf `backlogTasks` / `nextUpTasks`.

Der `toggleComplete`-Handler benötigt keine Änderung. SwiftData feuert @Query automatisch nach `completeTask()`. Die neu angelegte Recurrence-Instanz hat ein Future-DueDate und wird durch `isVisibleInBacklog=false` vom Post-Fetch-Filter herausgefiltert — Bug #287 ist damit implizit mitgelöst.

## Expected Behavior

- **Input:** SwiftData-Abfrage aller nicht-erledigten Tasks
- **Output:** Nur Tasks, die auch im Hauptfenster-Backlog bzw. Hauptfenster-Heute-Liste sichtbar sind
- **Side effects:** Keine. Keine Änderung am Datenmodell, kein Einfluss auf iOS.

## Akzeptanz-Kriterien

| # | Szenario | Erwartetes Ergebnis |
|---|----------|---------------------|
| AK1 | Recurring Task mit `dueDate` >= morgen | NICHT im Popover sichtbar |
| AK2 | Task mit `lifecycleStatus = "raw"` | NICHT im Popover sichtbar |
| AK3 | Task mit `assignedFocusBlockID != nil` | NICHT im Popover-Backlog sichtbar |
| AK4 | Task mit `isTemplate = true` | NICHT im Popover sichtbar |
| AK5 | Recurring Task mit `dueDate = heute` | Im Popover sichtbar (Positiv-Test) |
| AK6 | Abhaken eines wiederkehrenden Tasks | Neue Future-Instanz erscheint NICHT als Ersatz im Popover |
| AK7 | Filter-Konsistenz | Task-Liste im Popover ist exakt die Schnittmenge mit dem Hauptfenster-Backlog bzw. -NextUp |

Alle 7 Akzeptanz-Kriterien werden als Unit-Tests in `FocusBloxTests/MenuBarFilterTests.swift` abgedeckt.

## Affected Files

| Datei | Änderung |
|-------|----------|
| `FocusBloxMac/MenuBarView.swift` | Edit — Post-Fetch computed properties + Preview-Umstellung |
| `FocusBloxTests/MenuBarFilterTests.swift` | NEU — Unit Tests für alle 7 AK |

Geschätzte Änderungsgrösse: ~50 LoC total.

## Out of Scope

- `toggleComplete` Refresh-Pattern Refactoring (separater Bug, falls relevant)
- Sortier-Divergenz Popover (`createdAt`) vs. Hauptfenster (Priority-Score)
- Generelle MenuBarView-Architektur-Verbesserungen
- iOS-Plattform (nicht betroffen)
- **Automatisierter UI-Test fuer NSStatusItem-Popover:** TCC-Profile (`scripts/focusblox-uitest-tcc.mobileconfig`) grants nur `Accessibility`, nicht `AppleEvents`. Test-Runner kann FocusBloxMac nicht via osascript ansteuern. Erweiterung des TCC-Profiles waere ein separater Infrastruktur-Bug. Unit-Tests + manuelle Screenshot-Verifikation decken den Bug-Fix vollstaendig ab.

## Definition of Done

- [ ] Alle 7 Akzeptanz-Kriterien als Unit-Tests grün (`./scripts/sim.sh unit MenuBarFilterTests`)
- [ ] macOS Build erfolgreich (`./scripts/sim.sh mac-build`)
- [ ] Vorher/Nachher-Screenshots in `docs/artifacts/bug-289-menubar-popover-filter/` (manuelle Verifikation des Popovers)
- [ ] GitHub Issue #289 geschlossen mit Commit-Reference
- [ ] GitHub Issue #287 geschlossen mit Commit-Reference

## UI-Verifikation

Da das macOS NSStatusItem-Popover nicht via XCUITest erreichbar ist (TCC-Sandbox blockiert AppleEvents-Automation aus dem Test-Runner), erfolgt die UI-Verifikation manuell per Screenshot:

- **Vorher:** `docs/artifacts/bug-289-menubar-popover-filter/menubar_popover_BEFORE.png` — zeigt "Zehnagel behandel" + andere unsichtbare Tasks im Popover
- **Nachher:** `docs/artifacts/bug-289-menubar-popover-filter/menubar_popover_AFTER.png` — wird nach Implementation erzeugt; muss zeigen, dass diese Tasks NICHT mehr im Popover erscheinen

Screenshot-Workflow (manuell, ausserhalb XCUITest):
1. App mit `-UITesting` starten: `./scripts/sim.sh mac-build && open <path>/FocusBloxMac.app --args -UITesting -MockData`
2. MenuBar-Klick via osascript: `osascript -e 'tell application "System Events" to tell process "FocusBloxMac" to click menu bar item 1 of menu bar 2'`
3. Screenshot: `screencapture -x /tmp/popover.png`

## Known Limitations

- Der Post-Fetch-Filter muss bei jeder Erweiterung von `LocalTaskSource.fetchIncompleteTasks()` synchron gehalten werden. Langfristig wäre eine gemeinsame Filter-Funktion sauberer — das ist aber Out of Scope für diesen Fix.

## Changelog

- 2026-04-25: Initial spec created (basierend auf Analyse-Artefakt bug-289-menubar-popover-filter/analysis.md)
