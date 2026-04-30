# Context: Bug 295 — List-Section-Bodies fehlen im Accessibility-Tree

## Request Summary

In der iOS Backlog-View (`Sources/Views/BacklogView.swift`, Mode `.priority`) sind die Rows der Sektionen **Überfällig**, **Dringend**, **Bald**, **Später**, **Geparkt** nicht im XCUITest-Accessibility-Tree erreichbar — obwohl `.onAppear` feuert, die Daten korrekt sind und die Section-Header sichtbar sind. Nur die erste Section (Heute / NextUp) liefert ihre Items in den Tree. Konsequenz: Bug 279 (Stacking-Badge) lässt sich UI-test-technisch nicht beweisen, und potenziell ist es auch ein realer User-Pain-Point auf Device. Dasselbe Symptom auf macOS.

## Diagnose-Werte (Issue #295)

```
staticWochen=0, anyWochen=0
allMockStatic=4, allMockAny=4   (von ~16 MOCK-Tasks)
taskTitleIds=4                  (= alle 4 nextUp-Tasks)
badgeIds=0                      (kein stackingBadge_)
ueberfaelligHeader=1            (Header IST da)
```

→ Section-Header rendert ✓, Section-Body-Rows fehlen aus dem a11y-Tree ✗.

`onAppear` der Wochenreview-Row meldet `stackedCount=3` — Row ist also lifecycle-erstellt, aber nicht im Tree erreichbar. `swipeUp` / `swipeDown` ändern daran nichts.

## Related Files

| File | Relevanz |
|------|----------|
| `Sources/Views/BacklogView.swift` | iOS-View, betroffen. `priorityView` ist `List` mit 5+ Sections (Heute, Hygiene-Banner, Überfällig, Dringend, Bald, Später, Geparkt). Lines 1198–1292. |
| `FocusBloxMac/ContentView.swift` | macOS-Pendant, dieselbe Section-Struktur. Lines 460–592. |
| `Sources/Views/BacklogRow.swift` | Row-Komponente — rendert StackingBadge bei `stackedInstanceCount >= 2` (Z. 228-230). |
| `Sources/Views/Components/TaskBadges.swift` | `StackingBadge` mit `accessibilityIdentifier("stackingBadge_\(taskId)")` (Z. 187-204). |
| `Sources/FocusBloxApp.swift` | UITesting-Mock-Daten (Z. 917-1036): Series 1 (x2), Series 2 (x3 Wochenreview), Series 3 (x1). |
| `FocusBloxUITests/BacklogStackingUITests.swift` | RED-Tests die scheitern: greifen auf `app.staticTexts.matching(...)` für Badge / Wochenreview zu — Elemente nicht im Tree. |
| `docs/artifacts/bug-279-stacking-badge-missing/` | Frühere Analyse + RED-Test-Logs. `analysis.md`, `previous-attempts.md`, `ui-test-red-ios.txt`, `ui-test-red-mac.txt`. |
| `Sources/Views/TaskAssignmentView.swift` | Einziges Beispiel im Codebase: ScrollView + LazyVStack (Z. 55, 109) — möglicher Lösungs-Patternreferenz. |

## Existing Patterns

- **`.accessibilityElement(children: .contain)`** wird im Codebase 30+ Mal verwendet (DayView, CoachView, TaskAssignmentView, MacTimelineView, …). Auf Sections in Listen aber **nicht** systematisch.
- **List + Section + Header** wird in mehreren Views genutzt; nur `nextUpListSection` (BacklogView.swift:1084) hat einen `.accessibilityIdentifier` auf dem Header. Sections mit Body-Items (Tier-Sektionen, Geparkt) tragen keinen.
- **ScrollView + LazyVStack** existiert im Codebase nur in `TaskAssignmentView.swift` — würde swipeActions / listRowInsets ersetzen (großer Umbau).
- **macOS** verwendet `List(selection:)` mit denselben Sections — gleiches Symptom laut Issue.

## Mock-Daten-Setup (für RED-Tests)

- Series 1 (groupID `uitest-recurring-group-1`): "Taeglich lesen" — Template + 2 Children (heute, gestern) → Tier `.doNow`/`.planSoon` → **Sektion "Dringend" / "Bald"**.
- Series 2 (groupID `uitest-recurring-group-2`): "Wochenreview" — Template + 3 Children (heute, -7T, -14T) → 2 Children sind überfällig → **Sektion "Überfällig"**.
- Series 3: "Zweiwochentlich aufraeumen" — 1 Child → kein Stacking.

Alle 3 Sektionen liegen NACH der ersten Section ("Heute") und genau dort verschwinden die Rows aus dem a11y-Tree.

## Dependencies

- **Upstream:** SwiftUI `List` auf iOS 26 / macOS 26. Verhalten ist SDK-Implementierungsdetail (UICollectionView-basierte List), nicht von uns kontrolliert.
- **Downstream:** Alle UI-Tests die auf Rows in nicht-NextUp-Sektionen zugreifen (Bug 279, ggf. zukünftige Tier-Tests, BacklogParkdeckUITests, BacklogSwipeActionsUITests, etc.).

## Existing Specs

- `docs/specs/bugfix/bug-279-recurring-stacking.md` — Bug 279 (Symptom: Stacking-Badge fehlt). #295 ist die *Ursache* warum 279 nicht UI-testbar ist.

## Lösungs-Optionen (Issue-Vorschläge — noch nicht entschieden)

| Option | Aufwand | Risiko |
|--------|---------|--------|
| A) `List` → `ScrollView { LazyVStack }` | hoch — swipeActions, listRowInsets, refreshable müssen neu gebaut werden | hoch (UX-Regression Swipe) |
| B) `.accessibilityElement(children: .contain)` auf jeder Section | gering | unklar ob es das Problem behebt |
| C) `.listSectionSpacing` / `listStyle` Variation | gering | unklar |
| D) Section-Body als `LazyVStack` innerhalb von `List` | mittel | unklar |

Ohne empirische Probe lässt sich nicht sagen welche Option den Bug behebt.

## Risks & Considerations

- **iOS 26 SDK-Verhalten** ist möglicherweise neu / Beta-spezifisch — vorher hat es vielleicht funktioniert. Git-Log auf Section-Verhalten prüfen.
- **macOS-Parität** ist Pflicht (Memory-Regel `feedback_platform-parity.md`). Lösung muss auf beiden Plattformen funktionieren.
- **Cross-View-Refresh** (CLAUDE.md): Bei macOS-Änderungen `taskDataChanged`-Notification beachten.
- **Scope-Guard**: Max 5 Code-Dateien, ±250 LoC. Option A überschreitet das deutlich → bei A: Ticket splitten.
- **Real-User-Auswirkung** unklar — Issue erwähnt manuellen Befund "Badge nicht sichtbar". Phase 2 muss prüfen: ist der Badge-Render auf Device kaputt, oder nur die a11y-Sichtbarkeit?
- **Vorrangig zu klären (Phase 2)**: Welche Option löst den Bug *minimal-invasiv* (B + C zuerst probieren, A nur wenn alles andere scheitert).

## Next Step

Phase 2 — Analyse: Root Cause finden via empirischer Probe (jeweils Option B/C live ausprobieren), bevor Spec geschrieben wird.
