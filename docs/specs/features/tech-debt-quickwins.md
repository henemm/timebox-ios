---
entity_id: tech-debt-quickwins
type: refactoring
created: 2026-03-04
updated: 2026-03-04
status: draft
version: "1.0"
tags: [tech-debt, performance, consistency]
---

# Tech-Debt Quick Wins Bundle

## Approval

- [ ] Approved

## Purpose

3 kleine Fixes fuer technische Schulden mit hohem ROI: fehlende SwiftData-Indizes, ein Text-Mismatch bei Recurrence-Anzeige auf macOS, und Dead-Code-Bereinigung.

## Scope

- **Dateien:** 3
- **LoC:** ~+10 / -260
- **Risiko:** LOW (keine Verhaltensaenderung, nur Performance + Konsistenz + Cleanup)

---

## Fix 1: SwiftData @Index auf LocalTask

### Source
- **File:** `Sources/Models/LocalTask.swift`
- **Zeilen:** 12, 14, 62 (Properties ohne Index)

### Problem
LocalTask hat 0 `@Index`-Annotationen. Jede Query (`#Predicate`, `.filter`) scannt den gesamten Store. Bei >500 Tasks wird das spuerbar langsam.

### Aenderung

Attribute-Makro `@Attribute(.spotlight)` ist NICHT noetig — wir brauchen nur `#Index` auf Model-Ebene (SwiftData iOS 26).

```swift
// VORHER (Zeile 7-8):
@Model
final class LocalTask {

// NACHHER:
@Model
final class LocalTask {
    // ... properties ...

    static let indexes: [[IndexColumn<LocalTask>]] = [
        [\.isCompleted],
        [\.isNextUp],
        [\.dueDate],
        [\.isTemplate]
    ]
```

**Hinweis:** Exakte Syntax muss gegen SwiftData iOS 26 API geprueft werden. Alternativ `#Index<LocalTask>([\.isCompleted])` Macro-Syntax.

### Betroffene Queries (profitieren sofort)
- `BacklogView`: `.filter { !$0.isCompleted && !$0.isNextUp }`
- `MacAssignView`: `#Predicate { !$0.isCompleted }`
- `MacPlanningView`: `#Predicate { $0.isNextUp && !$0.isCompleted }`
- `RecurrenceService`: `.filter { $0.isTemplate }`

---

## Fix 2: recurrenceDisplayName Mismatch auf macOS

### Source
- **File:** `FocusBloxMac/MacBacklogRow.swift`
- **Zeilen:** 363-371 (private func recurrenceDisplayName)

### Problem
macOS hat eine **private Kopie** der Recurrence-Anzeigenamen die vom Shared-Enum abweicht:

| Pattern | macOS (MacBacklogRow) | iOS (RecurrencePattern.displayName) |
|---------|----------------------|--------------------------------------|
| biweekly | "Zweiwoechentlich" | "Alle 2 Wochen" |
| weekdays | **fehlt** (zeigt raw "weekdays") | "An Wochentagen" |
| weekends | **fehlt** | "An Wochenenden" |
| quarterly | **fehlt** | "Alle 3 Monate" |
| custom | **fehlt** | "Eigene" |

### Aenderung

**Loeschen** der privaten Funktion `recurrenceDisplayName()` (Zeilen 363-371) und ersetzen durch den Shared-Enum:

```swift
// VORHER (Zeile 109):
Text(recurrenceDisplayName(task.recurrencePattern))

// NACHHER:
Text(RecurrencePattern(rawValue: task.recurrencePattern)?.displayName ?? task.recurrencePattern)
```

Das ist exakt das Pattern das iOS BacklogRow bereits nutzt (Zeile 167).

**Seiteneffekte:** Keine. Nur Text-Output aendert sich fuer `biweekly` ("Zweiwoechentlich" -> "Alle 2 Wochen").

---

## Fix 3: Dead Code in BlockPlanningView loeschen

### Source
- **File:** `Sources/Views/BlockPlanningView.swift`
- **Zeilen:** ~125-257 (2 nie aufgerufene computed properties)

### Problem
Zwei ViewBuilder-Properties (`blockPlanningTimeline`, `smartGapsContent`) sind definiert aber werden **nie in `body` aufgerufen**. Stattdessen wird `timelineContent` genutzt. Das sind ~130 Zeilen toter Code.

Zusaetzlich: 2 Debug-`print()` Statements in `.task` und `.onChange` (Zeilen ~114, ~118).

### Aenderung
- **Loeschen:** `private var blockPlanningTimeline: some View` (~50 LoC)
- **Loeschen:** `private var smartGapsContent: some View` (~40 LoC)
- **Loeschen:** 2x `print("...")` Zeilen

**Seiteneffekte:** Keine. Code wird aktuell nicht ausgefuehrt.

---

## Test-Strategie

### Unit Tests
- **Fix 1 (Indizes):** Kein separater Test noetig — Indizes sind SwiftData-intern, bestehende Tests validieren Query-Ergebnisse
- **Fix 2 (Recurrence):** 1 Unit Test der verifiziert dass `RecurrencePattern.displayName` fuer alle Cases einen nicht-leeren String liefert (existiert moeglicherweise schon)
- **Fix 3 (Dead Code):** Kein Test noetig — Code wird geloescht

### UI Tests
- **Fix 2:** 1 UI Test der auf macOS prueft dass ein wiederkehrender Task den korrekten Recurrence-Text anzeigt

### Build-Validierung
- iOS Build erfolgreich
- macOS Build erfolgreich
- Alle bestehenden Tests weiterhin gruen

---

## Reihenfolge

1. Fix 3 (Dead Code) — Rauschen reduzieren, Build bestaetigen
2. Fix 2 (Recurrence) — Sichtbaren Bug beheben
3. Fix 1 (Indizes) — Performance-Verbesserung

## Changelog

- 2026-03-04: Initial spec created
