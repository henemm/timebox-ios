# Bug 295 — Analyse: List-Section-Bodies fehlen im Accessibility-Tree

## Symptom (Hennings Beobachtung)

In der Backlog-View der App fehlt das Stacking-Badge auf wiederkehrenden Aufgaben (z.B. "Wochenreview" das 3× überfällig ist). Außerdem berichten unsere automatisierten Tests, dass sie die Aufgaben in den Sektionen **Überfällig**, **Dringend**, **Bald**, **Später**, **Geparkt** gar nicht "sehen". Nur die obere Sektion **Heute** liefert vollständige Daten.

## User-Erwartung (User Advocate)

Der User will auf einen Blick sehen, was wartet. **Überfällige Aufgaben müssen sofort alarmieren**. Das Stacking-Badge ist sein wichtigster Vertrauensanker: "Die App weiß, dass ich den Wochenreview dreimal verpasst habe — warum zeigt sie mir das nicht laut und deutlich?"

Wenn Backlog-Sektionen visuell stumm bleiben (= keine Badges, keine Sortierung sichtbar), verliert er das Vertrauen, dass die App ihn richtig priorisiert. Test-Befunde sind ihm egal — fehlende Badges sind sein Schmerz.

## Diagnose-Werte (aus Issue #295)

```
staticWochen=0, anyWochen=0
allMockStatic=4, allMockAny=4   (von ~16 MOCK-Tasks → nur 4 NextUp im Tree)
taskTitleIds=4
badgeIds=0                      (kein stackingBadge_)
ueberfaelligHeader=1            (Section-Header IST sichtbar)
```

`onAppear` der Wochenreview-Row meldet `stackedCount=3` → Row IST gerendert, ist aber im Accessibility-Tree unsichtbar.

## Hypothesen (Team-Analyse)

### Hypothese A — Strukturell: backlogRowWithSwipe liefert TupleView

`Sources/Views/BacklogView.swift:1090-1156` — `backlogRowWithSwipe(_:)` ist mit `@ViewBuilder` markiert und enthält am Ende einen `ForEach` für blockierte Dependents (Z. 1153-1155):

```swift
@ViewBuilder
private func backlogRowWithSwipe(_ item: PlanItem) -> some View {
    VStack { … }
        .listRowInsets(…)
        .swipeActions(…)
        .contextMenu { … }
    // Render blocked dependents directly after this task
    ForEach(blockedTasks(for: item.id)) { blocked in
        blockedRow(blocked)
    }
}
```

Dadurch liefert die Funktion bei jedem Aufruf ein `TupleView<(VStack…, ForEach)>` zurück. Im `Section { ForEach { backlogRowWithSwipe(item) } }`-Pattern verarbeitet List jede Iteration als 2 Elemente — ein bekanntes Pattern, das in iOS 26 die a11y-Tree-Propagierung der nicht-ersten Section unterbrechen kann.

**Beleg:** `nextUpListSection` (Z. 1004-1087) — die EINZIGE Section die im Tree erscheint — verwendet `backlogRowWithSwipe` NICHT, sondern rendert ein einzelnes `VStack` inline pro Row.

### Hypothese B — Accessibility-Modifier: fehlendes `.contain` auf Sections

Die "Heute"-Section trägt `.accessibilityIdentifier("nextUpSection")` auf ihrem Header (Z. 1084). Die anderen Sections (Überfällig, Tier, Geparkt-iOS) tragen **gar keine** Section/Header-IDs. Auf macOS hat die Geparkt-Section dagegen eine ID auf dem Header (`geparktSectionHeader`).

Im Codebase wird `.accessibilityElement(children: .contain)` 30+ Mal verwendet (DayView, CoachView, …) als Standard-Pattern für Container, aber **nie auf Sections in Listen**.

### Hypothese C — iOS-26-SDK-Verhalten

iOS 26 Deployment Target wurde mit Commit `5dcc8e3` (2026-01-23) eingeführt. SwiftUI List nutzt seitdem aggressivere Virtualisierung — Off-Screen-Sections werden aus dem AX-Tree ausgeblendet. Da auch sichtbare Sections betroffen sind (Header da, Body nicht), ist das nicht die alleinige Ursache, aber möglicherweise verschärfend.

`docs/reference/learnings.md` Z. 147 dokumentiert ein verwandtes Muster: Section-Level `.accessibilityIdentifier` überschreibt Identifier von Kind-Elementen.

### Verworfen — TaskBadges.swift:297

Schreiber-Agent vermutete `.accessibilityElement(children: .combine)` auf einem Container. Verifiziert: Die `.combine` ist nur auf dem **PriorityScoreBadge** selbst (Z. 297), nicht auf einem Row-Container. Sie kombiniert nur Image+Text in dem Badge — das ist gewollt und kann nicht die Row verstecken.

## Spannung zwischen den Hypothesen

| Agent | Sagt: |
|-------|-------|
| Datenfluss-Trace | "Strukturelle Ursache in `backlogRowWithSwipe` (TupleView)" |
| Schreiber | "Fehlendes `.accessibilityElement(children: .contain)` auf Sections" |
| Wiederholungs-Check | "Möglicher iOS-26-SDK-Faktor" |

**Auflösung:** A und B widersprechen sich nicht — sie sind 2 mögliche Eintrittspunkte für dasselbe Symptom. C verschärft beide. Der minimal-invasive Fix-Test ist B (1-2 Zeilen pro Section), der strukturelle Fix-Test ist A (ForEach aus dem Helper herauslösen). Empirische Probe muss klären, welcher der entscheidende Hebel ist.

## Wahrscheinlichste Ursache

**Hypothese B mit Hypothese A als Verschärfer.**

Begründung:
- Hypothese B erklärt, warum die erste Section funktioniert (Header trägt ID — wirkt vermutlich implizit als a11y-Container)
- Hypothese A erklärt, warum NUR die Sections mit `backlogRowWithSwipe` betroffen sind und NextUp nicht
- Hypothese C macht das Verhalten in iOS 26 strenger als in iOS 18

## Lösungsoptionen (mit Risiko)

| Option | Beschreibung | Risiko | Aufwand |
|--------|--------------|--------|---------|
| **B** | `.accessibilityElement(children: .contain)` auf jeder Section setzen | LOW | 1 Datei, ~10 LoC, beidseitig (iOS+macOS) |
| **A1** | Trailing `ForEach` aus `backlogRowWithSwipe` herauslösen → in jeden Aufrufer | MED | 1 Datei iOS, ~30 LoC |
| **A2** | `backlogRowWithSwipe` ohne `@ViewBuilder` und ohne ForEach + separate Funktion `blockedRowsFor(item)` | MED | 1 Datei iOS, ~30 LoC |
| **C** | `.listStyle(.plain)` → `.listStyle(.insetGrouped)` oder `.listSectionSpacing(.compact)` | LOW | 1 Zeile, aber UX-Änderung |
| **D** | List → ScrollView { LazyVStack } | HIGH | 8+ UI-Tests brechen, swipeActions/refreshable verloren | inakzeptabel ohne Ticket-Split |

## Blast Radius

Bei den empfohlenen Optionen B und A:
- ✅ Swipe-Actions bleiben unberührt
- ✅ Pull-to-Refresh bleibt unberührt
- ✅ macOS Multi-Select bleibt unberührt (`List(selection:)`)
- ✅ UI-Tests die `app.collectionViews` nutzen brechen NICHT (List bleibt List)
- ✅ Performance unverändert

Aktuell potenziell betroffene UI-Tests (würden GREEN nach Fix):
- `BacklogStackingUITests.test_seriesWithThreeInstances_showsBadgeX3`
- `BacklogStackingUITests.test_seriesWithTwoInstances_showsBadgeX2`
- `BacklogStackingUITests.test_stackedSeries_rendersAsSingleRow`
- `BacklogSwipeActionsUITests` (mehrere Tests die auf nicht-NextUp-Tasks zugreifen)
- ggf. `BacklogParkdeckUITests.test_geparktSection_existsAndIsOpen` für Body-Items

## Empfehlung für Phase 3 (Fix-Vorschlag)

**Stufenweiser Ansatz:**

1. **Schritt 1 (probieren):** Hypothese B umsetzen — `.accessibilityElement(children: .contain)` auf jede Backlog-`Section` (Überfällig, Dringend, Bald, Später, Geparkt) auf iOS UND macOS. Tests laufen lassen.
2. **Schritt 2 (falls B nicht reicht):** Zusätzlich Hypothese A1 — Trailing `ForEach` für blockierte Tasks aus `backlogRowWithSwipe` herauslösen, sodass die Funktion eine einzelne View liefert.

Die Spec sollte beide Schritte als gemeinsame Implementation beschreiben, mit dem expliziten Hinweis: nach Schritt 1 messen, ob Tests grün sind; bei Erfolg Schritt 2 zurückstellen.

## Scope-Schätzung

- **Dateien:** 2 Code-Dateien (`Sources/Views/BacklogView.swift`, `FocusBloxMac/ContentView.swift`)
- **LoC:** +20 / -5 (Schritt 1) ggf. +30 / -15 (Schritt 2)
- **Test-Dateien:** 1-2 (Erweiterung `BacklogStackingUITests` und/oder neu `BacklogSectionsA11yUITests`)
- **Risiko:** LOW

## Nächster Schritt

Henning präsentieren (Checkpoint 1) → bei "stimmt" weiter zu `/03-write-spec`.
