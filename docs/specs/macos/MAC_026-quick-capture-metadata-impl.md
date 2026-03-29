---
entity_id: mac_026_quick_capture_metadata_impl
type: implementation
created: 2026-03-28
updated: 2026-03-28
status: draft
version: "1.0"
tags: [macos, quick-capture, metadata, implementation]
---

# MAC_026 — Quick Capture Metadata (Implementation Spec)

> **Scope:** Teilbereich A der Eltern-Spec `MAC-026-quick-capture-enhanced.md`
> **Aufwand:** S (2 Dateien, ~170 LoC)
> **Plattform:** macOS (`FocusBloxMac/`)

## Approval

- [ ] Approved

## Purpose

Das macOS Quick Capture Panel um 4 Metadaten-Felder (Importance, Urgency, Category, Duration) erweitern, sodass macOS Feature-Paritat mit der iOS QuickCaptureView erreicht. Aktuell erlaubt das Panel nur Titel-Eingabe — alle Metadaten fehlen.

## Source

- **File:** `FocusBloxMac/QuickCapturePanel.swift`
- **Identifier:** `struct QuickCapturePanelView`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBloxMac/QuickCapturePanel.swift` | modify | Hauptdatei — State, UI, createTask()-Aufruf erweitern |
| `FocusBloxTests/QuickCaptureMetadataTests.swift` | create | Unit Test fuer Metadaten-Uebergabe |
| `Sources/Helpers/TaskMetadataUI.swift` | shared logic | `ImportanceUI` und `UrgencyUI` — Icons, Farben, Labels |
| `Sources/Models/LocalTask.swift` | model | Task-Felder: importance, urgency, taskType, estimatedDuration |
| `Sources/Models/TaskCategory.swift` | model | `TaskCategory` Enum (income / maintenance / recharge / learning / giving_back) |
| `Sources/Views/CategoryPicker.swift` | shared view | Kategorie-Auswahl — als `.popover()` eingebunden |
| `Sources/Views/DurationPicker.swift` | shared view | Dauer-Auswahl — als `.popover()` eingebunden |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | service | `createTask()` — empfaengt alle Metadaten-Parameter |

## Implementation Details

### 1. State-Variablen hinzufuegen (nach bestehenden States, ~Zeile 130)

```swift
@State private var importance: Int? = nil
@State private var urgency: String? = nil
@State private var taskType: String = "maintenance"
@State private var estimatedDuration: Int? = nil
@State private var showCategoryPicker = false
@State private var showDurationPicker = false
```

### 2. Metadaten-Row im Body (nach TextField, vor Submit-Button)

- Sichtbar nur wenn `!title.isEmpty` (progressive disclosure)
- `HStack` mit 4 Buttons: Importance, Urgency, Category, Duration
- Picker-Buttons nutzen `.popover()` (nicht `.sheet()` — Sheet-Semantik funktioniert nicht in NSPanel)
- Icons und Farben via `ImportanceUI.icon/color/label` und `UrgencyUI.icon/color/label`

**Cycle-Logik Importance:**
```
nil → 1 → 2 → 3 → nil
```

**Cycle-Logik Urgency:**
```
nil → "not_urgent" → "urgent" → nil
```

**Layout:**
```
+------------------------------------------------------------------+
|  [cube.fill]  [ Add task...                              ] [ret] |
|  [!] Importance  [>>] Urgency  [tag] Category  [clock] Duration |
+------------------------------------------------------------------+
```

### 3. Panel-Hoehe anpassen

In `createPanel()`:
- `NSRect` height: `60` → `120`
- `NSHostingView` frame entsprechend anpassen

### 4. addTask() erweitern

```swift
let task = try? await taskSource.createTask(
    title: title,
    importance: importance,
    estimatedDuration: estimatedDuration,
    urgency: urgency,
    taskType: taskType,
    lifecycleStatus: TaskLifecycleStatus.raw.rawValue
)
```

### 5. Reset nach Dismiss/Save

Alle Metadaten-States auf Initialwerte zuruecksetzen:
```swift
importance = nil
urgency = nil
taskType = "maintenance"
estimatedDuration = nil
showCategoryPicker = false
showDurationPicker = false
```

## Expected Behavior

- **Input:** User oeffnet Panel (Cmd+Shift+Space), tippt Titel
- **Output:** Metadaten-Row erscheint, User setzt optional Importance/Urgency/Category/Duration, Return speichert Task mit allen Feldern
- **Side effects:** Task landet in SwiftData mit korrekten Metadaten; CloudKit synct automatisch; Panel schiesst sich zu, alle States werden zurueckgesetzt

## Acceptance Criteria

1. Panel zeigt 4 Metadaten-Buttons (Importance, Urgency, Category, Duration) sobald Titel nicht leer ist
2. Importance cycled korrekt: nil → 1 → 2 → 3 → nil mit korrekten Icons und Farben aus `ImportanceUI`
3. Urgency cycled korrekt: nil → not_urgent → urgent → nil mit korrekten Icons und Farben aus `UrgencyUI`
4. Category-Button oeffnet Popover mit `CategoryPicker`
5. Duration-Button oeffnet Popover mit `DurationPicker`
6. Beim Speichern werden alle gesetzten Metadaten an `createTask()` uebergeben
7. Beim Schliessen (Escape) und nach Speichern (Return) werden alle States zurueckgesetzt
8. macOS Build kompiliert ohne Fehler (`./scripts/sim.sh mac-build`)
9. Unit Test in `QuickCaptureMetadataTests` verifiziert Metadaten-Uebergabe an `createTask()`

## Known Limitations

- Teilbereiche B (Hotkey Library), C (Liquid Glass), D (URL Scheme) sind ausdruecklich nicht im Scope dieser Impl-Spec — siehe Eltern-Spec fuer Details
- Keyboard-Navigation (Tab zwischen Metadaten-Buttons) ist nicht im Scope dieser Iteration
- Panel-Hoehe ist fix auf 120px — kein dynamisches Anpassen bei leerem Titel (wird in C mit Liquid Glass adressiert)

## Changelog

- 2026-03-28: Initial impl spec created (Teilbereich A von MAC-026)
