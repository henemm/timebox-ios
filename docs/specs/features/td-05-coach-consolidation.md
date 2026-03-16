---
entity_id: td-05-coach-consolidation
type: feature
created: 2026-03-14
updated: 2026-03-14
status: draft
version: "1.0"
tags: [tech-debt, code-sharing, coach-views, viewmodel, consolidation]
---

# TD-05 Coach Views Consolidation (Paket 5)

## Approval

- [ ] Approved

## Purpose

Eliminiert ~120 LoC duplizierter Logik zwischen den macOS und iOS Coach Views, indem drei Shared-Komponenten extrahiert werden und toten Code in MacBacklogRow entfernt wird. Dieses Paket dient gleichzeitig als Pilot, der das `Sources/ViewModels/` Verzeichnis-Pattern etabliert, auf das alle nachfolgenden Konsolidierungs-Pakete aufbauen.

## Source

- **Files (CREATE):**
  - `Sources/ViewModels/CoachBacklogViewModel.swift`
  - `Sources/Views/Components/MonsterIntentionHeader.swift`
  - `Sources/Views/Components/DayProgressSection.swift`
- **Files (MODIFY):**
  - `FocusBloxMac/MacCoachBacklogView.swift`
  - `Sources/Views/CoachBacklogView.swift`
  - `FocusBloxMac/MacCoachReviewView.swift`
  - `Sources/Views/CoachMeinTagView.swift`
  - `FocusBloxMac/MacBacklogRow.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| DailyIntention | Model | Aktuelle Intention laden (CoachBacklogViewModel, MonsterIntentionHeader) |
| IntentionOption | Enum | matchesFilter() fuer relevantTasks/otherTasks Trennung |
| Discipline | Model | Farb-Klassifizierung in CoachBacklogViewModel |
| PlanItem | Model | Task-Objekte fuer Filterung (via PlanItem.init(localTask:) Bridge) |
| AppSettings | Service | coachModeEnabled, activeIntentionFilters AppStorage |

## Aenderungen im Detail

### 1. CoachBacklogViewModel (CREATE)

**Datei:** `Sources/ViewModels/CoachBacklogViewModel.swift`

Extrahiert die Intention-Filter-Logik, die identisch in `MacCoachBacklogView.swift` und `CoachBacklogView.swift` vorhanden ist.

```swift
@Observable
final class CoachBacklogViewModel {
    var primaryIntention: IntentionOption? = nil
    var activeIntentionFilters: [IntentionOption] = []
    var relevantTasks: [PlanItem] = []
    var otherTasks: [PlanItem] = []

    func loadIntention() async { ... }
    func applyFilter(to tasks: [PlanItem]) { ... }
}
```

- `loadIntention()`: Laedt die aktive `DailyIntention` aus SwiftData, leitet `primaryIntention` und `activeIntentionFilters` daraus ab.
- `applyFilter(to:)`: Trennt Tasks anhand `IntentionOption.matchesFilter()` in `relevantTasks` und `otherTasks`.
- Beide View-Dateien (macOS + iOS) ersetzen ihre inline-Logik durch dieses ViewModel.

### 2. MonsterIntentionHeader (CREATE)

**Datei:** `Sources/Views/Components/MonsterIntentionHeader.swift`

Extrahiert den Monster-Header, der identisch in `MacCoachBacklogView.swift` (height: 80) und `CoachBacklogView.swift` (height: 100) vorhanden ist.

```swift
struct MonsterIntentionHeader: View {
    let intention: IntentionOption?
    var height: CGFloat = 100   // iOS-Default; macOS uebergibt 80

    var body: some View {
        // Monster-Bild basierend auf intention
        // Intention-Label oder "Starte deinen Tag"-Hinweis
    }
}
```

- Parameter `height` macht den einzigen Unterschied zwischen den Plattformen konfigurierbar.
- `accessibilityIdentifier("coachMonsterHeader")` wird intern gesetzt.

### 3. DayProgressSection (CREATE)

**Datei:** `Sources/Views/Components/DayProgressSection.swift`

Extrahiert die Tages-Fortschritt-Anzeige ("X Tasks erledigt"), die identisch in `MacCoachReviewView.swift` und `CoachMeinTagView.swift` vorhanden ist.

```swift
struct DayProgressSection: View {
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        // "X Tasks erledigt" Anzeige
        // accessibilityIdentifier("coachDayProgress") intern gesetzt
    }
}
```

- Beide View-Dateien ersetzen ihre inline-Implementierung durch `DayProgressSection(completedCount:totalCount:)`.

### 4. Dead Code Cleanup in MacBacklogRow (MODIFY)

**Datei:** `FocusBloxMac/MacBacklogRow.swift`

Entfernt 7 Callback-Parameter, die nie von einem Caller uebergeben werden:

| Parameter | Typ |
|-----------|-----|
| `onImportanceCycle` | `((Int) -> Void)?` |
| `onUrgencyToggle` | `((String?) -> Void)?` |
| `onCategorySelect` | `((String) -> Void)?` |
| `onDurationSelect` | `((Int) -> Void)?` |
| `dependentCount` | `Int` |
| `effectiveScore` | `Int` |
| `effectiveTier` | `TaskPriorityScoringService.PriorityTier` |

Entfernung ist rein mechanisch — keine Verhaltensaenderung, da die Parameter nie verwendet wurden (~20 LoC Einsparung).

## Scope

| Metrik | Wert |
|--------|------|
| Dateien gesamt | 8 (3 CREATE + 5 MODIFY) |
| LoC hinzugefuegt | ~140 |
| LoC entfernt | ~120 |
| Netto | ~+20 (aber ~120 LoC Duplikation eliminiert) |
| Risiko | NIEDRIG |

## Expected Behavior

- **Input:** Keine Verhaltensaenderung fuer den Endanwender. Coach-Views sehen identisch aus.
- **Output:** Intention-Filter-Logik, Monster-Header und DayProgressSection laufen aus einer einzigen Quelle in `Sources/`.
- **Side effects:** Legt `Sources/ViewModels/` als neues Verzeichnis an (wird von Paketen 1-4 wiederverwendet).

## Test-Plan

Bestehende UI-Tests auf beiden Plattformen validieren die korrekte Verhaltenserhaltung. Kein neues Verhalten — deshalb keine neuen Acceptance-Tests, nur Regression-Validierung.

### Zu validieren (bestehende Tests muessen GRUEN bleiben)

- `CoachBacklogUITests` (iOS): Monster-Header sichtbar, Intention-Filter korrekt
- `MacCoachReviewUITests` (macOS): DayProgress-Anzeige korrekt
- Bestehende Unit Tests fuer `IntentionOption.matchesFilter()`

### Neue Unit Tests

- `CoachBacklogViewModelTests`: `applyFilter()` trennt Tasks korrekt in `relevantTasks` / `otherTasks`

## Nicht im Scope

- Paket 1 (FocusBlockState), Paket 2 (ReviewViewModel), Paket 3 (AssignmentViewModel), Paket 4 (SettingsService) — eigene Tickets
- Model-Divergenz (LocalTask vs PlanItem) — langfristiges Thema, wird hier NICHT geloest
- Visuelle Aenderungen an Coach-Views jeglicher Art

## Known Limitations

- `PlanItem.init(localTask:)` Bridge muss bei macOS-seitigem ViewModel-Einsatz genutzt werden, da macOS intern `LocalTask` (SwiftData) verwendet und iOS `PlanItem` (Sync-Wrapper). Das ViewModel operiert auf `PlanItem`.
- `Sources/ViewModels/` existiert noch nicht — wird durch dieses Ticket angelegt. Kein Xcode-Projekt-Setup-Aufwand benoetigt (Swift Package / Folder-Group genuegt).

## Abhaengigkeiten zu anderen Paketen

| Paket | Richtung | Abhaengigkeit |
|-------|----------|---------------|
| TD-05 (dieses Ticket) | — | Pilot, keine Voraussetzungen |
| Paket 2 (ReviewViewModel) | nachgelagert | Nutzt `Sources/ViewModels/` Pattern von hier |
| Paket 1 (FocusBlockState) | nachgelagert | Nutzt `Sources/ViewModels/` Pattern von hier |
| Paket 3 (AssignmentViewModel) | nachgelagert | Nutzt `Sources/ViewModels/` Pattern von hier |
| Paket 4 (SettingsService) | nachgelagert | Nutzt `Sources/ViewModels/` Pattern von hier |

## Changelog

- 2026-03-14: Initial spec created.
