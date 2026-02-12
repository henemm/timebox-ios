# Bug 46: Planungsgenauigkeit im Review Tab

## User Story

Als Nutzer will ich im Review Tab sehen:
1. Wie oft musste ich Tasks umplanen (Reschedule-Count)?
2. War ich schneller oder langsamer als geplant?

## Vorhandene Daten

- `PlanItem.effectiveDuration` (geplante Minuten)
- `FocusBlock.taskTimes[taskID]` (tatsaechliche Sekunden)
- `LocalTask.assignedFocusBlockID` (aktuelle Zuordnung)

## Fehlende Daten

- `LocalTask.rescheduleCount` - Zaehlvariable fuer Umplanungen

## Implementierung

### 1. LocalTask.swift - Neues Feld
```swift
var rescheduleCount: Int = 0
```
SwiftData Lightweight Migration - Default-Wert, kein Schema-Versioning noetig.

### 2. SyncEngine.swift - Reschedule zaehlen
In `updateAssignedFocusBlock()`: Wenn `assignedFocusBlockID` sich aendert
UND der alte Wert nicht nil war (also nicht erste Zuweisung), dann
`rescheduleCount += 1`.

### 3. ReviewStatsCalculator.swift - Neue Methode
```
computePlanningAccuracy(blocks, allTasks) -> PlanningAccuracyStats
```
- Fuer jeden erledigten Task mit taskTimes-Eintrag:
  actual (Sekunden) vs estimated (Minuten * 60)
- Ergebnis: schneller/langsamer/passend Counts + Durchschnitt
- Reschedule-Stats: Total Reschedules, Tasks mit 1+ Reschedules

### 4. DailyReviewView.swift + MacReviewView.swift - Anzeige
Neue Sektion "Planungsgenauigkeit" mit:
- Balken: X schneller, Y langsamer, Z passend (±10% Toleranz)
- Durchschnittliche Abweichung
- Umplanungen: X Tasks mussten umgeplant werden

## Betroffene Dateien

| Datei | Aenderung | LoC |
|-------|-----------|-----|
| `Sources/Models/LocalTask.swift` | +rescheduleCount | ~2 |
| `Sources/Services/SyncEngine.swift` | Increment bei Reassign | ~8 |
| `Sources/Models/ReviewStatsCalculator.swift` | computePlanningAccuracy() | ~40 |
| `Sources/Views/DailyReviewView.swift` | Planungsgenauigkeit-Sektion | ~40 |
| `FocusBloxMac/MacReviewView.swift` | Planungsgenauigkeit-Sektion | ~40 |

**Gesamt: 5 Dateien, ~130 LoC**
