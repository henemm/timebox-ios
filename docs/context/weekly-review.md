# Context: Weekly Review (Wochen-Rückblick)

## Request Summary

"Womit habe ich meine Woche verbracht?" - Zeit-Analyse nach Kategorie für die aktuelle Woche.

## Related Files

| Datei | Relevanz |
|-------|----------|
| `Sources/Views/DailyReviewView.swift` | **Pattern für Review-UI** (ähnliche Struktur) |
| `Sources/Views/SprintReviewSheet.swift` | Wiederverwendbare Components (StatItem, ReviewTaskRow) |
| `Sources/Models/FocusBlock.swift` | `completedTaskIDs`, `taskIDs`, `startDate` |
| `Sources/Models/PlanItem.swift` | `taskType` für Kategorisierung, `effectiveDuration` |
| `Sources/Services/EventKitRepository.swift` | `fetchFocusBlocks(for: date)` |
| `Sources/Views/MainTabView.swift` | Tab-Navigation (ggf. erweitern) |

## Existing Patterns

### 1. DailyReviewView (Tages-Review)
- NavigationStack mit ScrollView
- Stats-Header mit Completion-Ring
- Block-Cards mit Task-Listen
- Empty State bei keinen Daten
- `.withSettingsToolbar()`

### 2. Kategorien (taskType)
```swift
// 5 Kategorien verfügbar:
"income"       // Geld verdienen (dollarsign.circle)
"maintenance"  // Schneeschaufeln (wrench.and.screwdriver)
"recharge"     // Energie aufladen (battery.100)
"learning"     // Lernen (book)
"giving_back"  // Weitergeben (gift)
```

### 3. Data-Fetching
```swift
// Pro Tag:
eventKitRepo.fetchFocusBlocks(for: date) -> [FocusBlock]

// Für Woche: 7x aufrufen (Mo-So)
```

## Dependencies

**Upstream (was wir nutzen):**
- `EventKitRepository` - Focus Blocks laden
- `FocusBlock` - Completion-Daten, Zeitdaten
- `PlanItem` - Task-Details (taskType, effectiveDuration)
- `SyncEngine` - Tasks laden

**Downstream (was uns nutzt):**
- Nichts (neues Feature)

## Data Points für Weekly Review

**Vorhanden:**
- `block.completedTaskIDs` - Welche Tasks erledigt
- `block.startDate` - Wann war der Block (für Wochentag)
- `task.taskType` - Kategorie
- `task.effectiveDuration` - Geplante Dauer

**Berechnung:**
- Zeit pro Kategorie = Summe(effectiveDuration) aller completed Tasks dieser Kategorie
- Completion Rate = completed / total Tasks
- Aktivste Tage = Blocks pro Wochentag

## UI Options

**Option A: Eigener Tab** (wie DailyReview)
- Pro: Konsistent mit Tages-Rückblick
- Contra: 6 Tabs könnten zu viel sein

**Option B: Segment in DailyReviewView**
- Toggle zwischen "Heute" und "Diese Woche"
- Pro: Weniger Tabs
- Contra: Komplexere View

**Empfehlung:** Option B - Segmented Control in bestehendem Rückblick-Tab

---

## Analysis

### Entscheidung: Segmented Control in DailyReviewView

### Affected Files (with changes)

| Datei | Änderung | Beschreibung |
|-------|----------|--------------|
| `Sources/Views/DailyReviewView.swift` | MODIFY | Segmented Picker, Weekly Stats, Category Charts |
| `FocusBloxUITests/DailyReviewUITests.swift` | MODIFY | Tests für Wochen-Ansicht |

### Scope Assessment

- **Dateien:** 2 (beide modify)
- **Geschätzte LoC:** ~150 (in bestehender Datei)
- **Risiko:** LOW (Erweiterung bestehender View)

### Technical Approach

1. **Segmented Picker** hinzufügen: "Heute" | "Diese Woche"
2. **Weekly Stats** berechnen:
   - Alle Blocks der Woche laden (Mo-So)
   - Tasks nach Kategorie gruppieren
   - Zeit pro Kategorie summieren
3. **Category Chart** anzeigen:
   - Horizontale Balken pro Kategorie
   - Farbkodierung wie in CreateTaskView
4. **Wochentag-Übersicht:**
   - Mini-Statistik pro Tag (optional)
