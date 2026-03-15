---
entity_id: discipline-override
type: feature
created: 2026-03-15
updated: 2026-03-15
status: draft
version: "1.0"
tags: [coach, discipline, context-menu, cross-platform]
---

# Discipline Override

## Approval

- [ ] Approved

## Purpose

Nutzer koennen die automatisch berechnete Disziplin (Konsequenz/Mut/Fokus/Ausdauer) eines Tasks per Long-Press/Context-Menu im CoachBacklogView manuell ueberschreiben. Die Kreisfarbe des Checkboxes aendert sich sofort. Override hat Vorrang vor Auto-Berechnung, kann jederzeit zurueckgesetzt werden.

## Source

- **File:** `Sources/Models/Discipline.swift` (Resolution-Logik)
- **File:** `Sources/Views/CoachBacklogView.swift` (iOS Context Menu)
- **File:** `FocusBloxMac/MacCoachBacklogView.swift` (macOS Context Menu)
- **Identifier:** `Discipline.resolveOpen()`, `SyncEngine.updateDiscipline()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask` | SwiftData Model | Neues Feld `manualDiscipline: String?` speichert Override |
| `PlanItem` | Struct | Bridge-Objekt reicht `manualDiscipline` durch |
| `Discipline` | Enum | `resolveOpen()` prueft Override vor Auto-Berechnung |
| `SyncEngine` | Service | `updateDiscipline()` persistiert Override |
| `CoachBacklogView` | View (iOS) | Context Menu auf `coachRow()` |
| `MacCoachBacklogView` | View (macOS) | Context Menu auf `coachRow()` |

## Affected Files

| File | Change | LoC |
|------|--------|-----|
| `Sources/Models/LocalTask.swift` | MODIFY — `var manualDiscipline: String?` Feld | +2 |
| `Sources/Models/PlanItem.swift` | MODIFY — Feld mappen in `init(localTask:)` | +3 |
| `Sources/Models/Discipline.swift` | MODIFY — `resolveOpen()` Methode | +12 |
| `Sources/Views/CoachBacklogView.swift` | MODIFY — Context Menu + Override-Callback | +25 |
| `FocusBloxMac/MacCoachBacklogView.swift` | MODIFY — Context Menu + Override-Callback | +25 |
| `Sources/Services/SyncEngine.swift` | MODIFY — `updateDiscipline()` Methode | +8 |
| **Summe** | | **+75** |

**NICHT betroffen:**
- `BacklogRow.swift` / `MacBacklogRow.swift` — empfangen bereits `disciplineColor: Color?`, keine Aenderung
- `CoachBacklogViewModel` — Filter-Logik nutzt keine Discipline (eigene Regeln pro Coach)
- Review-Views — zeigen erledigte Tasks, kein Override sinnvoll

## Implementation Details

### 1. Model: LocalTask (SwiftData)

```swift
// In LocalTask.swift — neues optionales Feld
var manualDiscipline: String?
// CloudKit-kompatibel: String? mit Default nil, Lightweight Migration automatisch
```

### 2. Bridge: PlanItem

```swift
// In PlanItem — neues Property
let manualDiscipline: String?

// In init(localTask:) ergaenzen:
self.manualDiscipline = localTask.manualDiscipline
```

### 3. Resolution: Discipline.resolveOpen()

```swift
/// Override hat Vorrang. Faellt auf Auto-Berechnung zurueck wenn nil oder ungueltig.
static func resolveOpen(
    manualDiscipline: String?,
    rescheduleCount: Int,
    importance: Int?
) -> Discipline {
    if let manual = manualDiscipline,
       let discipline = Discipline(rawValue: manual) {
        return discipline
    }
    return classifyOpen(rescheduleCount: rescheduleCount, importance: importance)
}
```

### 4. Persistence: SyncEngine.updateDiscipline()

```swift
func updateDiscipline(itemID: String, discipline: String?) throws {
    guard let task = try findTask(byID: itemID) else { return }
    task.manualDiscipline = discipline
    task.modifiedAt = Date()
    try modelContext.save()
}
```

### 5. UI: Context Menu auf coachRow()

```swift
// Auf coachRow() in CoachBacklogView (und analog MacCoachBacklogView):
.contextMenu {
    Section("Disziplin") {
        ForEach(Discipline.allCases, id: \.self) { d in
            Button {
                updateDiscipline(for: item, discipline: d.rawValue)
            } label: {
                Label(d.displayName, systemImage: d.icon)
            }
        }
        if item.manualDiscipline != nil {
            Divider()
            Button {
                updateDiscipline(for: item, discipline: nil)
            } label: {
                Label("Zuruecksetzen", systemImage: "arrow.counterclockwise")
            }
        }
    }
}
```

### 6. Discipline-Farbe in coachRow() (beide Plattformen)

```swift
// VORHER:
let discipline = Discipline.classifyOpen(rescheduleCount:..., importance:...)

// NACHHER:
let discipline = Discipline.resolveOpen(
    manualDiscipline: item.manualDiscipline,  // PlanItem bzw. LocalTask
    rescheduleCount: item.rescheduleCount,
    importance: item.importance
)
```

## Expected Behavior

- **Input:** Long-Press auf Task-Row im CoachBacklogView (iOS) oder Right-Click (macOS)
- **Output:** Context Menu mit 4 Disziplin-Optionen (Konsequenz, Ausdauer, Mut, Fokus) + "Zuruecksetzen" (nur sichtbar wenn Override aktiv)
- **Side effects:**
  - Checkbox-Kreisfarbe aendert sich sofort
  - Override wird via CloudKit synchronisiert (iOS ↔ macOS)
  - Coach-Sektionszuordnung bleibt UNVERAENDERT (Troll/Feuer/Eule/Golem filtern nach eigenen Regeln)
  - "Zuruecksetzen" entfernt Override → Auto-Berechnung greift wieder

## Test Plan

### Unit Tests (Discipline.resolveOpen)
1. Override "konsequenz" → gibt .konsequenz zurueck (ignoriert Auto-Berechnung)
2. Override "mut" → gibt .mut zurueck
3. Override "fokus" → gibt .fokus zurueck
4. Override "ausdauer" → gibt .ausdauer zurueck
5. Override nil → faellt auf classifyOpen() zurueck
6. Override ungueltiger String → faellt auf classifyOpen() zurueck

### UI Tests (iOS — CoachBacklogViewUITests)
1. Long-Press auf Task zeigt Context Menu mit Disziplin-Optionen
2. Auswahl einer Disziplin aendert Checkbox-Farbe

### UI Tests (macOS — MacCoachBacklogUITests)
1. Right-Click auf Task zeigt Context Menu mit Disziplin-Optionen
2. Auswahl einer Disziplin aendert Checkbox-Farbe

## Known Limitations

- Override aendert nur die Kreisfarbe, nicht die Coach-Sektion (gewollt — Sektionen folgen Coach-Logik)
- Fokus ist bei offenen Tasks per Auto-Berechnung nicht erreichbar (braucht Duration-Vergleich) — Override ermoeglicht es
- Context Menu nur im Coach-Modus (CoachBacklogView), nicht im normalen BacklogView

## Changelog

- 2026-03-15: Initial spec created
