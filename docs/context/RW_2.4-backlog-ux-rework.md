# Context: RW_2.4 — Backlog UX Rework

## Request Summary
Backlog-Ansicht mit Parkdeck-Metapher: Aktive Tasks (doNow, planSoon) prominent, selten relevante Tasks (eventually, someday) visuell zurueckgestuft hinter ausklappbarem "Parkdeck"-Bereich.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/BacklogView.swift` (~1344 LoC) | Haupt-Backlog-View, enthaelt priorityView mit Tier-Sections, Search, ViewMode Switcher |
| `Sources/Views/BacklogRow.swift` (~316 LoC) | iOS Task-Row, braucht neue Swipe-Action "Parken"/"Aktivieren" |
| `FocusBloxMac/MacBacklogRow.swift` (~323 LoC) | macOS Task-Row, braucht Context Menu Eintraege |
| `FocusBloxMac/ContentView.swift` (~1227 LoC) | macOS Haupt-View, enthaelt eigene Backlog-Tier-Sections |
| `Sources/Services/TaskPriorityScoringService.swift` (~151 LoC) | PriorityTier enum (doNow/planSoon/eventually/someday) — Score-Logik bleibt UNVERAENDERT |

## Existing Patterns

### Tier-basierte Sections (aktuell)
- `priorityView` in BacklogView.swift (Z.1054-1119): Iteriert ueber `PriorityTier.allCases`, filtert Tasks pro Tier, zeigt alle 4 Tiers gleichberechtigt
- macOS ContentView (Z.457-484): Identisches Muster mit `tierTasks` Filter

### Swipe Actions (iOS)
- Leading: "Next Up" (gruen) → `updateNextUp(for:isNextUp:true)`
- Trailing: "Loeschen" + "Bearbeiten"
- Pattern: `backlogRowWithSwipe()` Helper (Z.966-1018)

### Context Menu (macOS)
- macOS nutzt Context Menus statt Swipe Actions (bestehendes Platform-Pattern)

### Section Headers
- Collapsible Sections existieren NICHT im aktuellen Code — alle Sections sind immer offen
- Badge-Pattern: `Text("\(count)").capsule()` in Section Headers

### Search
- `matchesSearch()` (Z.79-87): Durchsucht title, tags, category — muss ALLE Tasks durchsuchen inkl. Parkdeck

## Dependencies
- **Upstream:** `TaskPriorityScoringService.PriorityTier` (Score-Ranges: doNow 60-100, planSoon 35-59, eventually 10-34, someday 0-9)
- **Upstream:** `DeferredSortController`, `DeferredCompletionController` (Environment Objects)
- **Upstream:** `PlanItem` Model, `SyncEngine`

## Downstream
- macOS ContentView Backlog-Section muss analog angepasst werden
- Existing UI Tests: `BacklogViewUITests.swift`, `BacklogRowRedesignUITests.swift`, `BacklogSwipeActionsUITests.swift`

## Existing Specs
- `docs/specs/rework/2.4-backlog-ux-rework.md` — Feature Spec mit Akzeptanzkriterien

## Key Design Decisions
1. **Aktiv = doNow + planSoon** (Score >= 35) — immer sichtbar
2. **Parkdeck = eventually + someday** (Score < 35) — collapsed by default, Badge mit Anzahl
3. **Suche durchsucht ALLE Tasks** (inkl. Parkdeck, auch wenn collapsed)
4. **Swipe/Drag zum Parken/Aktivieren** — kein neues Datenfeld noetig, basiert auf PriorityTier
5. **Lazy Loading** fuer Parkdeck (nicht rendern wenn collapsed)
6. **5 bestehende ViewModes bleiben** als Filter verfuegbar

## Risks & Considerations
- BacklogView ist schon 1344 LoC (TD_001 God-View) — Aenderungen muessen minimal-invasiv sein
- Parkdeck-Filterlogik muss in `Sources/` (shared), nicht iOS-spezifisch
- macOS braucht eigene Parkdeck-UI (collapsible Section in Content Area)
- Score-basierte Zuordnung: Tasks koennen zwischen Aktiv/Parkdeck wechseln wenn sich Score aendert
