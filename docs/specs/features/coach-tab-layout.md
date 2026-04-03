---
entity_id: coach-tab-layout
type: feature
created: 2026-04-01
updated: 2026-04-03
status: implemented
version: "1.0"
tags: [ui, tabs, navigation, coach]
---

# Coach-Tab Layout (Variante C) — Reversibler Prototyp

## Approval

- [ ] Approved

## Purpose

Die App hat aktuell 5 Tabs (Backlog, Blox, Tag, Focus, Review) mit deutlichen Überschneidungen. Dieses Feature konsolidiert auf 4 Tabs (Backlog, Planen, Focus, Coach) als Feature-Flag-geschützten Prototyp, um das Konzept im Alltag zu testen.

**Psychologischer Hintergrund:** Die App bildet einen emotionalen Tagesbogen ab (Morgen=Intention, Tagsüber=Unterstützung, Abend=Reflexion). Aktuell ist dieser Bogen über 3+ Tabs verteilt. Der Coach-Tab bündelt ihn an einem Ort.

## Motivation

| Problem | Aktuell | Coach-Layout |
|---------|---------|-------------|
| Morgen-Ritual über 3 Tabs | Backlog + Blox + Tag/Morgen | Backlog + Coach |
| Doppelte Timeline tagsüber | Blox + Tag/Tagsüber | Planen (eine Timeline) |
| Abend-Reflexion in 2 Tabs | Tag/Abend + Review | Coach (eine Reflexion) |
| Freie Lücken doppelt | Blox + Tag/Morgen | Coach (einmal) |

## Tab-Struktur

| Tab | Icon | Inhalt | Basis |
|-----|------|--------|-------|
| **Backlog** | `list.bullet` | Unverändert | BacklogView |
| **Planen** | `calendar` | Timeline + Kalender + Block-Erstellung | BlockPlanningView (umbenannt) |
| **Focus** | `target` | Timer + aktiver Block | FocusLiveView (unverändert) |
| **Coach** | `sparkles` | Emotionale Tages-Timeline | **NEU**: CoachView |

## Source

- **Neue Datei:** `Sources/Views/CoachView.swift`
- **Geänderte Dateien:**
  - `Sources/Views/MainTabView.swift` (conditional Layout)
  - `Sources/Views/ContentView.swift` (useCoachLayout durchreichen)
  - `Sources/FocusBloxApp.swift` (Feature-Flag + Deep-Link-Mapping)
  - `Sources/Views/SettingsView.swift` (Toggle im Entwickler-Bereich)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| DayView | View | Morning/Daytime/Evening Logik wird als Datenquelle wiederverwendet |
| DailyReviewView | View | Completion Ring + Stats werden als Datenquelle wiederverwendet |
| MorningCoachingSection | View | AI-Vorschläge (direkt eingebettet) |
| SuccessStoryView | View | Abend-Reflexion (direkt eingebettet) |
| DayTimelineBar | View | Tages-Visualisierung (direkt eingebettet) |
| GapFinder | Service | Freie Lücken berechnen |
| NextUpSuggestionService | Service | Morgen-Vorschläge |
| BehavioralProfileService | Service | User-Profil für Vorschläge |

## Implementation Details

### Feature Flag

```swift
// In FocusBloxApp:
@AppStorage("useCoachTabLayout") private var useCoachTabLayoutSetting = false

// Auch per Launch-Argument für UI Tests:
ProcessInfo.processInfo.arguments.contains("--coach-tab-layout")
```

### CoachView Struktur

```
CoachView (ScrollViewReader → ScrollView, auto-scroll zu aktueller Phase)
│
├── MorningSection (orange Hintergrund wenn aktiv)
│   ├── "Was soll heute zählen?" (Intention)
│   ├── MorningCoachingSection (AI-Vorschläge)
│   ├── Freie Lücken (aus GapFinder)
│   └── Next-Up Tasks (heute geplant)
│
├── DaytimeSection (blau Hintergrund wenn aktiv)
│   ├── Block-Status: "X von Y Blöcken erledigt"
│   ├── Nächster Block (Uhrzeit + Titel)
│   └── Bereits erledigte Tasks (motivierend)
│
└── EveningSection (lila Hintergrund wenn aktiv)
    ├── DayTimelineBar (Tages-Visualisierung)
    ├── Erledigte Tasks (narrativ)
    ├── SuccessStoryView (AI-generiert)
    └── Kompakter Completion Ring (%, Blocks)
```

**Alle Sections immer sichtbar, scrollbar, KEIN Collapse.**
Auto-Scroll zur aktuellen Tagesphase beim Öffnen.
Aktive Phase hat farbigen Hintergrund + "Jetzt"-Badge.

### MainTabView

Conditional Rendering basierend auf `useCoachLayout`:
- `false` → klassisches 5-Tab Layout (Backlog, Blox, Tag, Focus, Review)
- `true` → Coach 4-Tab Layout (Backlog, Planen, Focus, Coach)

### AppTab Enum

Erweitert um `.plan` und `.coach` Cases für das neue Layout.

### Deep-Link-Mapping

Alle bestehenden `selectedTab = .day` / `.blox` Referenzen werden über Helper-Properties gemappt:
- `dayTab` → `.coach` (Coach-Layout) oder `.day` (klassisch)
- `bloxTab` → `.plan` (Coach-Layout) oder `.blox` (klassisch)

## Expected Behavior

- **Feature Flag OFF (default):** App zeigt 5 Tabs wie bisher. Keine sichtbare Änderung.
- **Feature Flag ON:** App zeigt 4 Tabs (Backlog, Planen, Focus, Coach).
- **Coach Tab Morgens:** Intention-Frage, AI-Vorschläge, freie Lücken, geplante Tasks.
- **Coach Tab Tagsüber:** Block-Status, erledigte Tasks (motivierend).
- **Coach Tab Abends:** Timeline-Bar, erledigte Tasks narrativ, Success Story, kompakte Stats.
- **Rückgängig:** Settings → Entwickler → Toggle aus → sofort 5 Tabs.

## Known Limitations

- Coach-Tab ist ein **Prototyp** zum Testen — kein finales Feature
- Wochenübersicht nur als kompakter Ring, nicht als vollständiges Review-Dashboard
- Bestehende UI Tests testen nur das klassische Layout (Coach-Tests sind neu)

## macOS

Der Coach-Tab ist auch auf macOS verfügbar:

- `FocusBloxMac/SidebarView.swift`: `MainSection` enum hat `.coach` Case
- `FocusBloxMac/ContentView.swift`: `useCoachTabLayout` Feature-Flag + `visibleSections` computed property
- `FocusBloxMac/MacSettingsView.swift`: Toggle für Coach-Tab Layout in den Einstellungen
- Shared Views (`DayIntention`, `IntentionSuggestionService`, `SuccessStoryService`, `SuccessStoryView`) wurden zum `FocusBloxMac` Target hinzugefügt
- `Sources/Views/CoachView.swift`: `.withSettingsToolbar()` und `.taskDataChanged`-Notification sind mit `#if os(iOS)` guards versehen

**macOS-Tests:**
- `FocusBloxMacUITests/MacCoachTabLayoutUITests.swift` (5 UI Tests)
- `FocusBloxMacTests/MacCoachVisibleSectionsTests.swift` (3 Unit Tests)

## Rückgängig machen

1. Settings → Entwickler → "Coach-Tab Layout" Toggle auf **aus**
2. App zeigt sofort wieder 5 Tabs (iOS) bzw. klassische Sidebar ohne Coach (macOS)
3. Kein Code gelöscht, kein Datenverlust
4. Alternativ: Feature Flag komplett entfernen → alles zurück wie vorher

## Changelog

- 2026-04-01: Initial spec created (Prototyp Variante C)
- 2026-04-03: macOS-Implementierung abgeschlossen (#197) — Coach-Tab in Sidebar, Feature-Flag-Toggle in MacSettingsView, shared Views zum Mac-Target hinzugefügt; Status auf `implemented` gesetzt
