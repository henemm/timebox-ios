---
entity_id: coach-review-macos
type: feature
created: 2026-03-14
updated: 2026-03-14
status: draft
version: "1.0"
tags: [monster-coach, macos, phase-6c]
---

# Feature Spec: Phase 6c — MorningIntentionView in macOS

## Approval

- [ ] Approved

## Purpose

Die MorningIntentionView (Morgen-Intention setzen + Monster-Grafik) ist nur auf iOS nutzbar. macOS-Nutzer koennen im Coach-Modus keine Intention setzen — damit fehlt die Grundlage fuer Backlog-Filter, Tages-Nudges und Abend-Reflexion. Phase 6c schliesst diese Luecke.

## Source

- **File (CREATE):** `FocusBloxMac/MacCoachReviewView.swift`
- **File (MODIFY):** `FocusBloxMac/ContentView.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `MorningIntentionView` | Shared View | Wird direkt eingebettet (Sources/Views/) |
| `DailyIntention` | Shared Model | Intention laden/speichern |
| `IntentionOption` | Shared Enum | Intentions-Auswahl |
| `Discipline` | Shared Model | Monster-Mapping |
| `MacCoachBacklogView` | macOS View | Liest intentionFilterOptions (downstream) |
| `ContentView` | macOS View | Routing: Review-Tab conditional |
| `NotificationService` | Shared Service | Nudge/Evening Scheduling (via MorningIntentionView) |

## Implementation Details

### 1. MacCoachReviewView.swift (CREATE, ~80 LoC)

```
ScrollView > VStack(spacing: 16):
  1. MorningIntentionView()          ← shared, direkt eingebettet
  2. dayProgressSection              ← "X Tasks erledigt" (HStack)
```

**Properties:**
- `@Environment(\.modelContext)` — SwiftData Zugriff
- `@Query` oder `@State` — Tasks laden
- `todayCompletedCount` computed — heute erledigte Tasks zaehlen

**NICHT enthalten (spaetere Phasen):**
- EveningReflectionCard (→ Phase 6d)
- NavigationStack (macOS nutzt NavigationSplitView extern)
- `.withSettingsToolbar()` (macOS hat Preferences-Menu)

### 2. ContentView.swift (MODIFY, ~15 LoC)

**Aenderung 1: Review-Case conditional (mainContentView)**
```swift
// VORHER:
case .review:
    MacReviewView()

// NACHHER:
case .review:
    if coachModeEnabled {
        MacCoachReviewView()
    } else {
        MacReviewView()
    }
```

**Aenderung 2: Toolbar-Label conditional**
```swift
// Review-Sektion im Picker zeigt "Mein Tag" statt "Review" bei Coach-Modus
```

**Aenderung 3: intentionJustSet Tab-Wechsel**
```swift
// Neuer onChange-Observer:
@AppStorage("intentionJustSet") private var intentionJustSet: Bool = false

.onChange(of: intentionJustSet) { _, newValue in
    if newValue {
        selectedSection = .backlog
        intentionJustSet = false
    }
}
```

## Expected Behavior

- **Coach OFF:** Review-Tab zeigt MacReviewView (unveraendert)
- **Coach ON:** Review-Tab zeigt MacCoachReviewView mit MorningIntentionView + Tages-Fortschritt
- **Intention setzen:** User waehlt Chips → "Intention setzen" → App wechselt zu Backlog-Tab (via intentionJustSet)
- **Intention bereits gesetzt:** Kompakte Ansicht mit Monster-Bild + "Aendern"-Button
- **Toolbar-Label:** "Review" (Coach OFF) / "Mein Tag" (Coach ON)
- **Side effects:**
  - `intentionFilterOptions` wird geschrieben → MacCoachBacklogView filtert Tasks
  - Notifications werden geplant (Daily Nudges, Evening Reminder)

## Accessibility Identifiers

| Element | Identifier | Herkunft |
|---------|-----------|----------|
| Intention Card | `morningIntentionCard` | shared MorningIntentionView |
| Intention Chips | `intentionChip_<rawValue>` | shared MorningIntentionView |
| Set-Button | `setIntentionButton` | shared MorningIntentionView |
| Edit-Button | `editIntentionButton` | shared MorningIntentionView |
| Monster-Bild | `monsterImage` | shared MorningIntentionView |
| Tages-Fortschritt | `coachDayProgress` | MacCoachReviewView (NEU) |

## Known Limitations

- Kein Abend-Spiegel (EveningReflectionCard) — kommt in Phase 6d
- Kein voller CoachMeinTagView-Ausbau — kommt in Phase 6e
- MorningIntentionView Chip-Labels koennten auf kleinen macOS-Fenstern umbrechen (LazyVGrid mit 2 Spalten)

## Testplan

4 UI Tests (macOS):

1. **Coach OFF:** Review-Tab zeigt MacReviewView (KEIN morningIntentionCard)
2. **Coach ON:** Review-Tab zeigt morningIntentionCard
3. **Intention setzen:** Chip waehlen → setIntentionButton → App wechselt zu Backlog
4. **Toolbar-Label:** Coach ON → "Mein Tag" Label im Navigation-Picker

## Scope

- Files: 2 (1 CREATE, 1 MODIFY)
- Estimated LoC: +80 neue, ~15 modifiziert
- Risk Level: LOW

## Changelog

- 2026-03-14: Initial spec created
