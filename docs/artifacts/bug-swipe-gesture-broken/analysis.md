# Bug: Swipe-Geste funktioniert nicht mehr (iOS Backlog)

## Symptom
Swipe-Gesten funktionieren ploetzlich nicht mehr in allen iOS Backlog-Views (alle Ansichten ausser Next Up).

## Agenten-Ergebnisse (5 parallele Investigationen)

### Agent 1: Wiederholungs-Check
- Keine frueheren iOS-Swipe-Bugs gefunden (nur macOS Bug 53 + Bug 78)
- Swipe Actions waren zuvor korrekt implementiert (seit Feb 2026)
- Der letzte Commit `cc567bf` ("Task-Abhaengigkeiten iOS Views") hat die View-Struktur geaendert

### Agent 3: Alle Schreiber
- **ROOT CAUSE GEFUNDEN:** In `backlogRowWithSwipe()` (Zeile 863-912) wurde ein `ForEach(blockedTasks)` ZWISCHEN `BacklogRow` und `.swipeActions()` eingefuegt
- Commit `cc567bf` hat dies eingefuehrt

### Agent 4: Szenarien
- **BESTAETIGT:** Das ForEach-Placement ist der einzige CRITICAL-Severity-Fund
- Alle anderen bekannten Swipe-Breaking-Patterns (DragGesture, NavigationLink, EditMode etc.) sind NICHT vorhanden

### Agent 5: Blast Radius
- 3 Dateien mit `.swipeActions()`: BacklogView.swift, NextUpSection.swift, ContentView.swift (macOS)
- Nur `backlogRowWithSwipe()` ist betroffen — Next Up und Completed View sind OK

## Hypothesen

### Hypothese 1: ForEach zwischen BacklogRow und .swipeActions (HOECHSTE WAHRSCHEINLICHKEIT)

**Beschreibung:** In `backlogRowWithSwipe()` (BacklogView.swift:863-912) produziert der `@ViewBuilder` ZWEI Views:
1. `BacklogRow(...)` (Zeile 865-878) — die eigentliche Task-Zeile
2. `ForEach(blockedTasks(...))` (Zeile 880-882) — geblockte Abhaengigkeiten

Die Modifier `.swipeActions()`, `.contextMenu()`, `.listRowInsets()` etc. (Zeile 883-911) haengen am `ForEach`, NICHT am `BacklogRow`.

In SwiftUI gilt: In einem `@ViewBuilder` mit mehreren Views werden Modifier auf die LETZTE View angewendet. Der BacklogRow bekommt daher KEINE Swipe Actions.

**Beweis DAFUER:**
- Commit `cc567bf` ist der juengste Commit und hat genau diese Struktur eingefuehrt
- Die Next Up Section (Zeile 795-843) ist NICHT betroffen — dort haengen `.swipeActions()` direkt am `BacklogRow`
- Die Completed View (Zeile 1131-1174) ist NICHT betroffen — kein ForEach dazwischen

**Beweis DAGEGEN:**
- Keiner. Die Code-Struktur ist eindeutig.

**Wahrscheinlichkeit:** SEHR HOCH (95%)

### Hypothese 2: iOS 26.2 SwiftUI Regression

**Beschreibung:** SwiftUI 7 koennte eine Aenderung bei `.swipeActions()` in `@ViewBuilder`-Kontexten haben.

**Beweis DAFUER:** Keine dokumentierten Regressionen gefunden.
**Beweis DAGEGEN:** Das Problem korreliert 1:1 mit dem Code-Change.

**Wahrscheinlichkeit:** NIEDRIG (5%)

### Hypothese 3: View Identity Problem durch ForEach

**Beschreibung:** Die `PlanItem`-IDs koennten sich aendern und Swipe-State zuruecksetzen.

**Beweis DAFUER:** ForEach nutzt implizites Identifiable.
**Beweis DAGEGEN:** Wuerde auch Next Up betreffen, tut es aber nicht.

**Wahrscheinlichkeit:** SEHR NIEDRIG (<1%)

## Wahrscheinlichste Ursache

**Hypothese 1: ForEach zwischen BacklogRow und .swipeActions()**

Eingefuehrt durch Commit `cc567bf` (feat: Task-Abhaengigkeiten iOS Views).

### Betroffener Code (BacklogView.swift:863-912):
```swift
@ViewBuilder
private func backlogRowWithSwipe(_ item: PlanItem) -> some View {
    BacklogRow(...)          // <-- DIESE View braucht .swipeActions

    ForEach(blockedTasks(for: item.id)) { blocked in
        blockedRow(blocked)
    }
    .listRowInsets(...)      // <-- Haengt am ForEach
    .swipeActions(...)       // <-- Haengt am ForEach, NICHT am BacklogRow!
    .contextMenu { ... }     // <-- Haengt am ForEach, NICHT am BacklogRow!
}
```

### Nicht betroffener Code (Next Up, Zeile 795-843):
```swift
ForEach(nextUpTasks) { item in
    BacklogRow(...)
    .swipeActions(...)       // <-- Haengt direkt am BacklogRow = FUNKTIONIERT
}
```

## Blast Radius

| View | Betroffen? | Grund |
|------|-----------|-------|
| Backlog (alle Sortierungen) | JA | Nutzt `backlogRowWithSwipe()` |
| Next Up Section | NEIN | Swipe direkt am BacklogRow |
| Completed View | NEIN | Kein ForEach dazwischen |
| macOS ContentView | NICHT GEPRUEFT | Eigene Implementierung |

## Vorgeschlagener Fix

`.swipeActions()` und `.contextMenu()` VOR den `ForEach` verschieben, direkt an den `BacklogRow`:

```swift
@ViewBuilder
private func backlogRowWithSwipe(_ item: PlanItem) -> some View {
    BacklogRow(...)
        .swipeActions(edge: .leading, ...) { ... }
        .swipeActions(edge: .trailing, ...) { ... }
        .contextMenu { ... }

    ForEach(blockedTasks(for: item.id)) { blocked in
        blockedRow(blocked)
    }
    .listRowInsets(...)
    .listRowBackground(...)
    .listRowSeparator(.hidden)
}
```

## Dateien die geaendert werden muessen
- `Sources/Views/BacklogView.swift` — `backlogRowWithSwipe()` Funktion (~Zeile 863-912)
