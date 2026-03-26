# Context: RW_2.1d — DayView Evening Mode

## Request Summary
Abend-Modus fuer DayView implementieren: Tagesrueckblick mit Zusammenfassung erledigter/unerledigter Tasks, Timeline des Tages (gruen/grau/orange), und Stubs fuer Success Story (4.2) und Failure Protocol (4.3).

## Related Files

### Core DayView (direkt betroffen)
| File | Relevance |
|------|-----------|
| `Sources/Views/DayView.swift` | Hauptdatei — Evening-Placeholder (Zeile 66-71) ersetzen durch echten Content |
| `FocusBloxUITests/DayViewUITests.swift` | UI Tests erweitern fuer Evening Mode |
| `FocusBloxTests/DayPhaseTests.swift` | Unit Tests fuer DayPhase.from() — bereits vorhanden |

### Bestehende DayView-Infrastruktur (wiederverwendbar)
| File | Relevance |
|------|-----------|
| `Sources/Views/TimelineView.swift` | Timeline-Komponente (6:00-22:00) — Basis fuer Tages-Timeline im Abendmodus |
| `Sources/Views/ScheduledTaskBlock.swift` | Orange Bloecke fuer geplante Tasks |
| `Sources/Views/EventBlock.swift` | Kalender-Event-Bloecke |
| `Sources/Models/TimelineItem.swift` | Unified Model fuer Timeline Items |
| `Sources/Models/GapFinder.swift` | Freie Zeitluecken finden |
| `Sources/Models/CalendarEvent.swift` | Kalender-Events |
| `Sources/Models/FocusBlock.swift` | Focus Sprint Bloecke |
| `Sources/Models/PlanItem.swift` | Task-Wrapper mit isCompleted, isNextUp, isScheduled |
| `Sources/Models/ReviewStatsCalculator.swift` | Category-Stats + PlanningAccuracy — Pattern fuer Zusammenfassung |

### Services (Daten laden)
| File | Relevance |
|------|-----------|
| `Sources/Services/EventKitRepository.swift` | Kalender-Events + FocusBlocks laden |
| `Sources/Services/SyncEngine.swift` | Tasks synchronisieren |
| `Sources/Services/LocalTaskSource.swift` | SwiftData Task-Quelle |

### Navigation
| File | Relevance |
|------|-----------|
| `Sources/Views/MainTabView.swift` | iOS Tab-Integration (bereits vorhanden) |
| `FocusBloxMac/SidebarView.swift` | macOS Sidebar-Integration (bereits vorhanden) |

## Existing Patterns

1. **Phasen-Pattern in DayView:** Morning/Daytime haben jeweils eigenen `@ViewBuilder var xxxContent`, eigene `loadXxxData() async` Methode, 4 States (loading/permission/empty/content)
2. **Launch-Argument fuer Tests:** `-morningEndHour 24` erzwingt Morning, `-morningEndHour 0 -eveningStartHour 24` erzwingt Daytime — analog fuer Evening: `-eveningStartHour 0`
3. **Timeline-Reuse:** Daytime nutzt `TimelineView` read-only — Evening kann gleiche Komponente mit Farb-Overlay nutzen
4. **ReviewStatsCalculator:** Bestehende Stats-Logik fuer Category-Minutes und PlanningAccuracy

## Dependencies
- **Upstream:** EventKitRepository, SyncEngine, LocalTaskSource, GapFinder, TimelineView, PlanItem
- **Downstream:** Stubs fuer RW_4.2 (SuccessStoryView) und RW_4.3 (FailureQuickSelectView) — werden als Platzhalter angelegt

## Existing Specs
- `docs/specs/rework/2.1-day-view.md` — Haupt-Spec mit UX-Konzept fuer alle Modi
- `docs/specs/rework/2.1a-day-view-skeleton.md` — Phase A: DayPhase enum + Skeleton
- `docs/specs/rework/2.1b-day-view-morning-mode.md` — Phase B: Morning Mode
- `docs/specs/rework/2.1c-day-view-daytime-timeline.md` — Phase C: Daytime Timeline
- `docs/specs/rework/4.1-soft-evening-reset.md` — Evening Reset Service (eigenes Ticket)
- `docs/specs/rework/4.2-success-story-generator.md` — Success Story (Stub in 2.1d)
- `docs/specs/rework/4.3-failure-protocol.md` — Failure Protocol (Stub in 2.1d)

## Risks & Considerations

1. **Scope-Begrenzung:** 2.1d soll Stubs fuer 4.2/4.3 erstellen, NICHT die volle Implementierung. Success Story = Platzhalter-Card, Failure Protocol = leeres UI-Skelett.
2. **Tages-Timeline im Abendmodus:** Spec sagt "gruen (erledigt), grau (Kalender), orange (geplant/nicht geschafft)". Benoetigt farbliche Unterscheidung in TimelineView — moeglicherweise neue Parameter oder eigene View.
3. **Completed Tasks:** PlanItem hat `isCompleted`, aber kein `completedDate`. Filtern auf "heute erledigt" koennte schwierig sein — muss in Analyse geprueft werden.
4. **macOS:** DayView ist shared. Evening-Content muss auf beiden Plattformen funktionieren (kein `#if os(iOS)` noetig, da keine iOS-only APIs).
5. **Daten-Loading:** loadEveningData() braucht: erledigte Tasks des Tages, unerledigte Next-Up Tasks, Kalender-Events, Focus-Blöcke — aehnlich wie Morning + Daytime kombiniert.
