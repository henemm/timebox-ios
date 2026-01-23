# Context: Daily Review (Tages-Rückblick)

## Request Summary

"Was habe ich heute alles geschafft?" - Übersicht aller erledigten Tasks eines Tages, gruppiert nach Focus Blocks.

## Related Files

| Datei | Relevanz |
|-------|----------|
| `Sources/Models/FocusBlock.swift` | Speichert `completedTaskIDs` pro Block |
| `Sources/Models/CalendarEvent.swift` | Parst completed IDs aus Calendar Notes |
| `Sources/Views/SprintReviewSheet.swift` | **Pattern für Review-UI** (wiederverwendbar) |
| `Sources/Views/FocusLiveView.swift` | `markTaskComplete()` Logik |
| `Sources/Services/EventKitRepository.swift` | `fetchFocusBlocks()`, `updateFocusBlock()` |
| `Sources/Models/PlanItem.swift` | Task-Repräsentation mit `taskType` |
| `Sources/Views/MainTabView.swift` | Tab-Navigation (neuer Tab nötig?) |

## Existing Patterns

### 1. SprintReviewSheet (Block-Review)
- Completion-Ring mit Prozentsatz
- Trennung: Erledigte vs. Unvollendete Tasks
- `StatItem` Component für Statistiken
- `ReviewTaskRow` für Task-Listen

### 2. Completion-Speicherung
```swift
// FocusBlock
var completedTaskIDs: [String]

// In Kalender (Notes-Feld)
"completed:id1|id2|id3"
```

### 3. Data-Fetching
```swift
eventKitRepo.fetchFocusBlocks(for: date) -> [FocusBlock]
```

## Dependencies

**Upstream (was wir nutzen):**
- `EventKitRepository` - Focus Blocks laden
- `FocusBlock` - Completion-Daten
- `PlanItem` - Task-Details (Titel, Dauer, Kategorie)
- `SyncEngine` - Tasks aus verschiedenen Quellen

**Downstream (was uns nutzt):**
- Nichts (neues Feature)

## Existing Specs

- `docs/specs/features/live-activity.md` - Ähnliche FocusBlock-Integration
- `docs/project/stories/timebox-core.md` - User Story Zeile 85-96

## Data Points für Daily Review

**Vorhanden:**
- `block.completedTaskIDs` - Welche Tasks erledigt
- `block.taskIDs` - Welche Tasks geplant waren
- `block.startDate/endDate` - Wann war der Block
- `PlanItem.taskType` - Kategorie (learning, maintenance, etc.)

**Fehlt:**
- Tages-Aggregation (alle Blocks eines Tages)
- Kategorisierte Statistiken
- Historie für Vergleiche

## UI Options

**Option A: Neuer Tab**
```
Backlog | Blöcke | Zuordnen | Fokus | Rückblick
```

**Option B: Unter Fokus-View**
- Toggle zwischen "Aktiv" und "Rückblick"

## Risks & Considerations

1. **Performance**: Alle Blocks + Tasks eines Tages laden
2. **Datenkonsistenz**: Tasks könnten gelöscht worden sein (nur ID vorhanden)
3. **Tab-Überfüllung**: 5 Tabs könnten zu viel sein
4. **Kategorien**: Nicht alle Tasks haben `taskType` (Reminders)

---

## Analysis

### Entscheidung: Neuer Tab "Rückblick"

### Affected Files (with changes)

| Datei | Änderung | Beschreibung |
|-------|----------|--------------|
| `Sources/Views/DailyReviewView.swift` | CREATE | Neues View für Tages-Rückblick |
| `Sources/Views/MainTabView.swift` | MODIFY | 5. Tab hinzufügen |
| `FocusBloxUITests/DailyReviewUITests.swift` | CREATE | UI Tests |

### Wiederverwendbare Components (aus SprintReviewSheet)

- `StatItem` - Statistik-Anzeige (Value + Label + Color)
- `ReviewTaskRow` - Task-Zeile mit Status

### Scope Assessment

- **Dateien:** 3 (1 modify, 2 create)
- **Geschätzte LoC:** +150
- **Risiko:** LOW (isoliertes neues Feature)

### Technical Approach

1. **DailyReviewView** erstellen:
   - Lädt alle FocusBlocks des Tages via `eventKitRepo.fetchFocusBlocks(for: Date())`
   - Aggregiert `completedTaskIDs` aus allen Blocks
   - Zeigt Tages-Statistik (Total erledigt, geplant, %)
   - Listet jeden Block mit seinen erledigten Tasks

2. **UI Struktur:**
   ```
   NavigationStack
   ├── Tages-Header (Datum, Gesamt-Stats)
   ├── ForEach Block
   │   ├── Block-Header (Titel, Zeit, %)
   │   └── Erledigte Tasks Liste
   └── "Keine Blocks heute" wenn leer
   ```

3. **Tab-Integration:**
   - Icon: `chart.bar.fill` oder `clock.arrow.circlepath`
   - Label: "Rückblick"

### Data Flow

```
DailyReviewView
  └── loadData()
      ├── eventKitRepo.fetchFocusBlocks(for: today)
      ├── syncEngine.sync() → allTasks
      └── Für jeden Block:
          └── tasksForBlock(block) → filtered by completedTaskIDs
```
