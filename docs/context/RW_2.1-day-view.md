# Context: RW_2.1 — Tagesansicht ("Dein Tag")

## Request Summary
Neuer Screen als zentraler Tageseinstieg: Morgens Kalender-Luecken + Task-Vorschlaege, tags Timeline mit Restprogramm, abends Reflexion mit Success Story + Failure Quick-Select.

## Abhaengigkeiten — KRITISCH
| Story | Status | Auswirkung |
|-------|--------|------------|
| RW_0.2 BehavioralProfileService | ERLEDIGT | Liefert Affinitaet/Kapazitaet — verfuegbar |
| RW_2.2 NextUpSuggestionService | OFFEN | Morgen-Modus braucht Task-Vorschlaege — FEHLT |
| RW_4.2 Success Story Generator | OFFEN | Abend-Modus braucht Success Story — FEHLT |
| RW_4.3 Failure Protocol | OFFEN | Abend-Modus braucht Failure Quick-Select — FEHLT |

**Konsequenz:** Morgen- und Abend-Modus koennen nur Platzhalter/Stubs zeigen bis 2.2/4.2/4.3 fertig sind. Die Grundstruktur (View, Modi-Wechsel, Timeline, Kalender-Luecken) ist aber vollstaendig umsetzbar.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/MainTabView.swift` | AppTab enum + TabView — neuer Tab `.dayView` hinzufuegen |
| `FocusBloxMac/SidebarView.swift` | MainSection enum — neuer Sidebar-Eintrag "Dein Tag" |
| `Sources/Models/AppSettings.swift` | Neue Settings: `morningEndHour`, `eveningStartHour` |
| `Sources/Services/EventKitRepository.swift` | `fetchCalendarEvents(for:)`, `fetchFocusBlocks(for:)` |
| `Sources/Services/BehavioralProfileService.swift` | `profile(tasks:focusBlocks:calendarEvents:)` — Kapazitaet/Affinitaet |
| `Sources/Models/GapFinder.swift` | `findFreeSlots(minMinutes:maxMinutes:)` — Kalender-Luecken |
| `Sources/Views/TimelineView.swift` | Wiederverwendbare Timeline 6:00-22:00 mit Drag/Drop |
| `Sources/Views/ScheduledTaskBlock.swift` | Geplante Tasks auf Timeline darstellen |
| `Sources/Models/TimelineItem.swift` | Unified Timeline-Items + Collision Detection |
| `Sources/Services/FocusBlockActionService.swift` | `startImmediate()` — Focus Sprint aus DayView starten |
| `Sources/Models/LocalTask.swift` | `scheduledDate`, `scheduledDuration`, `isScheduled` |

## Existing Patterns
- **Tab-Views:** `AppTab` enum mit cases, TabView mit `.tabItem { Label() }` + `.tag()`
- **Daten laden:** `@Environment(\.modelContext)` + `@Environment(\.eventKitRepository)`, Daten in `.task { }` laden
- **Timeline:** `TimelineView` ist wiederverwendbar (zeigt Events + FocusBlocks + ScheduledTasks)
- **macOS Navigation:** `MainSection` enum in SidebarView, ContentView switcht auf selectedSection
- **Settings:** `@AppStorage("key")` Properties in AppSettings

## Dependencies (Upstream)
- EventKitRepository (Kalender-Events)
- GapFinder (freie Slots)
- BehavioralProfileService (User-Profile)
- FocusBlockActionService (Sprint starten)
- LocalTask Model (geplante Tasks)

## Dependencies (Downstream)
- MainTabView (neuer Tab)
- SidebarView (neuer macOS-Eintrag)
- AppSettings (neue Einstellungen)

## Risks & Considerations
1. **XL-Aufwand** — in 4 Phasen gesplittet (RW_2.1a-d)
2. **Fehlende Abhaengigkeiten** — Stories 2.2, 4.2, 4.3 noch nicht implementiert
3. **Cross-Platform** — iOS Tab + macOS Sidebar muessen beide funktionieren
4. **Timeline Wiederverwendung** — TimelineView ist komplex (1400+ LoC), DayView sollte sie konsumieren, nicht duplizieren
5. **Modi-Wechsel** — Morgen/Tag/Abend basiert auf Uhrzeit + Settings, muss fliessend sein

---

## Analysis: RW_2.1a — Grundstruktur + Modi-Wechsel

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/AppSettings.swift` | MODIFY | +morningEndHour, +eveningStartHour (@AppStorage) |
| `Sources/Views/DayView.swift` | CREATE | Shared View mit DayPhase enum (morning/day/evening), Platzhalter-Content |
| `Sources/Views/MainTabView.swift` | MODIFY | AppTab enum +.day, neuer Tab-Eintrag |
| `FocusBloxMac/SidebarView.swift` | MODIFY | MainSection enum +.day mit icon |
| `FocusBloxMac/ContentView.swift` | MODIFY | mainContentView switch +.day case |

### Scope Assessment
- Files: 5 (1 CREATE, 4 MODIFY)
- Estimated LoC: +81
- Risk Level: LOW

### Technical Approach
- DayView als SHARED View in Sources/Views/ (wie RefinerView — kein Mac-Wrapper noetig)
- DayPhase enum in DayView.swift, Phase berechnet via Calendar.current.component(.hour)
- Settings-UI fuer morningEndHour/eveningStartHour NICHT in Phase A (keine sichtbare Wirkung)
- Reihenfolge: AppSettings → DayView → MainTabView → SidebarView + ContentView

### Dependencies
- Upstream: AppSettings (morningEndHour/eveningStartHour)
- Downstream: MainTabView, SidebarView, ContentView

### Open Questions
- Keine — Phase A ist klar definiert
