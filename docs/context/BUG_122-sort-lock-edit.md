# Context: BUG_122 — Sort-Lock: Nicht alle Task-Attribute editierbar

## Request Summary

Blocked Tasks (Tasks mit Dependency/Blocker) koennen auf iOS keine Inline-Attribute aendern. Die `blockedRow()` in BacklogView uebergibt nur `onEditTap` und `onTitleSave` — alle Badge-Callbacks (Importance, Urgency, Category, Duration) fehlen. macOS ist nicht betroffen, da `makeBacklogRow()` alle Callbacks auch fuer blocked Tasks uebergibt.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/BacklogView.swift:1112-1144` | `blockedRow()` — erstellt BacklogRow OHNE Inline-Edit-Callbacks |
| `Sources/Views/BacklogView.swift:1057-1110` | `backlogRowWithSwipe()` — vollstaendige Version mit allen Callbacks (Referenz) |
| `Sources/Views/BacklogView.swift:988-1054` | Next Up Section — ebenfalls vollstaendig (Referenz) |
| `Sources/Views/BacklogView.swift:613-663` | `updateImportance/Urgency/Category` — die fehlenden Handler |
| `Sources/Views/BacklogRow.swift` | Row-Komponente mit optionalen Callbacks (nil = Badge tut nichts) |
| `Sources/Views/Components/TaskBadges.swift` | ImportanceBadge/UrgencyBadge — rufen `onCycle?()` / `onToggle?()` auf (nil = no-op) |
| `Sources/Services/DeferredSortController.swift` | Freeze/Unfreeze-Mechanismus (funktioniert korrekt) |
| `FocusBloxMac/ContentView.swift:1242-1288` | macOS `makeBacklogRow` — uebergibt alle Callbacks AUCH bei isBlocked=true (kein Bug) |
| `FocusBloxMac/MacBacklogRow.swift` | macOS Row — isBlocked nur visuell (Opacity/Indent), Editing nicht blockiert |

## Existing Patterns

- **Inline Badge Editing:** Badges (Importance, Urgency, Category, Duration) sind direkt tippbar in der BacklogRow. Callbacks sind optional — nil bedeutet Badge rendert, tut aber nichts bei Tap.
- **Deferred Sort:** Nach Badge-Tap wird Sort-Order eingefroren (3s). Task bleibt an Position, Badge aktualisiert sofort. Danach animierte Neupositionierung. Funktioniert korrekt.
- **Blocked Tasks:** Tasks mit `blockerTaskID` erscheinen eingerueckt unter ihrem Blocker. Checkbox ist disabled. Swipe: Edit + Delete + Freigeben.

## Root Cause (Verdacht)

`blockedRow()` (Zeile 1112) wurde als Minimal-Version erstellt — nur Edit-Sheet und Title-Edit. Die Inline-Badge-Callbacks wurden nicht uebergeben, obwohl die Badges trotzdem gerendert werden. Ergebnis: Badges sichtbar aber nicht tippbar.

**Betroffene Attribute auf iOS (blocked row):**
- Importance Badge — NICHT editierbar (onImportanceCycle fehlt)
- Urgency Badge — NICHT editierbar (onUrgencyToggle fehlt)
- Category Badge — NICHT editierbar (onCategoryTap fehlt)
- Duration Badge — NICHT editierbar (onDurationTap fehlt)
- Focus Sprint Button — NICHT verfuegbar (onStartFocusSprint fehlt)
- Complete Checkbox — NICHT verfuegbar (onComplete fehlt) ← INTENTIONAL (blocked)

**macOS:** Nicht betroffen — `makeBacklogRow` uebergibt immer alle Callbacks.

## Dependencies

- **Upstream:** `DeferredSortController` (freeze/unfreeze), `SyncEngine` (updateTask/updateDuration)
- **Downstream:** BacklogRow rendert Badges immer, Funktionalitaet haengt nur von Callback-Uebergabe ab

## Existing Specs

- `docs/specs/features/backlog-010-deferred-sort-controller.md` — DeferredSort Spec
- `docs/specs/features/deferred-list-sorting.md` — Deferred Sorting Feature

## Risks & Considerations

- Fix ist minimal: Callbacks in `blockedRow()` ergaenzen (~6 Zeilen)
- `freezeSortOrder()` sollte auch fuer blocked Tasks funktionieren (sie sind in `backlogTasks` enthalten)
- `onComplete` sollte NICHT ergaenzt werden — blocked Tasks koennen absichtlich nicht completed werden
- `onStartFocusSprint` ist fragwuerdig — sollte ein blocked Task einen Sprint starten koennen?
