# Context: Bug 56 - EditTaskSheet durch TaskFormSheet ersetzen

## Request Summary
EditTaskSheet hat non-optionale State-Variablen (priority: TaskPriority, duration: Int) die nil-Importance auf .low mappen. TaskFormSheet macht es bereits korrekt mit Int?. Fix: EditTaskSheet eliminieren.

## Related Files
| File | Relevance |
|------|-----------|
| `Sources/Views/EditTaskSheet.swift` | LOESCHEN - kaputte Kopie mit non-optionalen States |
| `Sources/Views/TaskDetailSheet.swift` | Einziger Caller von EditTaskSheet (Zeile 86) - umstellen auf TaskFormSheet |
| `Sources/Views/TaskFormSheet.swift` | Korrekte Edit-Form mit Int? - Ersatz fuer EditTaskSheet |
| `Sources/Views/BacklogView.swift` | Caller von TaskDetailSheet (Zeile 283) - onSave Signatur anpassen (8 → 11 Params) |
| `Sources/Services/SyncEngine.swift` | updateTask() - Bug 48 Fix ist korrekt (if let) |

## Existing Patterns

### TaskFormSheet Edit-Mode (korrekt)
- `@State private var priority: Int? = nil` (optional)
- `@State private var duration: Int? = nil` (optional)
- `onSave: (String, Int?, Int?, [String], String?, String, Date?, String?, String, [Int]?, Int?) -> Void` (11 Params inkl. Recurrence)

### EditTaskSheet (kaputt)
- `@State private var priority: TaskPriority` (NON-optional, mappt nil → .low)
- `@State private var duration: Int` (NON-optional)
- `onSave: (String, Int?, Int?, [String], String?, String, Date?, String?) -> Void` (8 Params, OHNE Recurrence)

### Call Chain
1. Matrix-Tap → `taskToEdit` → `TaskDetailSheet` → "Bearbeiten" → `EditTaskSheet` (KAPUTT)
2. Context-Menu/Swipe → `taskToEditDirectly` → `TaskFormSheet` (KORREKT)

## Abhaengigkeiten

### Upstream (was unser Code nutzt)
- `PlanItem.priority` → mappt nil auf .low (fuer Display OK, fuer Edit problematisch)
- `SyncEngine.updateTask()` → Bug 48 Fix korrekt

### Downstream (was unseren Code nutzt)
- `BacklogView.taskToEdit` → sheet mit TaskDetailSheet
- UI Tests: `TaskDetailUITests.swift`, `EditTaskSheetUITests.swift`

## Risiken
- TaskDetailSheet.onSave Signatur muss von 8 auf 11 Params erweitert werden (Recurrence)
- BacklogView Callback muss angepasst werden
- UI Tests fuer EditTaskSheet muessen auf TaskFormSheet umgestellt werden
