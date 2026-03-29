# Context: MAC_026 — Enhanced Quick Capture (Metadaten)

## Request Summary
macOS Quick Capture Panel hat nur Titel + Next Up. iOS hat volle Metadaten (Importance, Urgency, Category, Duration). Paritaet herstellen.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxMac/QuickCapturePanel.swift` | **Zu aendern** — enthalt QuickCaptureController + eigene abgespeckte QuickCaptureView (nur Titel + NextUp) |
| `Sources/Views/QuickCaptureView.swift` | **Referenz** — Shared iOS View mit allen Metadaten-Buttons (Importance, Urgency, Category, Duration, NextUp) |
| `Sources/Helpers/TaskMetadataUI.swift` | Shared Helper: `ImportanceUI` + `UrgencyUI` (icon, color, label) |
| `Sources/Views/CategoryPicker.swift` | Shared Picker fuer Kategorie-Auswahl (Grid mit 5 Optionen) |
| `Sources/Views/DurationPicker.swift` | Shared Picker fuer Dauer-Auswahl (5/15/30/60 Min) |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | `createTask()` akzeptiert bereits alle Metadata-Parameter |
| `FocusBloxMac/FocusBloxMacApp.swift` | URL Scheme Handler (`focusblox://add` → nur Panel oeffnen, keine Parameter) |

## Kern-Problem: Namenskonflikt
`FocusBloxMac/QuickCapturePanel.swift` definiert eine eigene `struct QuickCaptureView` (Zeile 128). `Sources/Views/QuickCaptureView.swift` definiert ebenfalls eine `struct QuickCaptureView`. Im macOS-Target gewinnt die lokale Version — die shared Version mit Metadaten wird ignoriert.

## Existing Patterns
- **iOS QuickCaptureView** nutzt `ImportanceUI`/`UrgencyUI` aus `TaskMetadataUI.swift` fuer Icons/Farben
- **Cycle-Buttons** (Importance: nil→1→2→3→nil, Urgency: nil→not_urgent→urgent→nil) sind in der iOS View inline implementiert
- **CategoryPicker/DurationPicker** werden als `.sheet()` praesentiert — auf macOS muessten sie als Popover oder inline funktionieren (kein Sheet in NSPanel)
- **createTask()** in LocalTaskSource akzeptiert bereits: importance, estimatedDuration, urgency, taskType
- **macOS addTask()** ruft derzeit nur `createTask(title:taskType:lifecycleStatus:)` auf — ohne Metadaten

## Dependencies
- **Upstream:** `LocalTaskSource.createTask()`, `ImportanceUI`, `UrgencyUI`, `TaskCategory`, `CategoryPicker`, `DurationPicker`
- **Downstream:** URL Scheme Handler in FocusBloxMacApp, MenuBarView Quick Add

## Existing Specs
- `docs/specs/macos/MAC-026-quick-capture-enhanced.md` — Draft Spec (umfangreich, 4 Teilbereiche A-D)

## Risiken & Ueberlegungen
1. **Namenskonflikt** — Zwei `QuickCaptureView` Structs. Bleibt bestehen (kein Problem solange macOS-View lokal bleibt)
2. **Sheet in NSPanel** — CategoryPicker/DurationPicker nutzen `.presentationDetents` — auf macOS mit `.popover()` aufrufen, Detents werden ignoriert (kein Crash)
3. **Panel-Hoehe** — Aktuell fix 60px → ~120px mit Metadaten-Row
4. **sensoryFeedback** — auf macOS ein No-Op, kein Crash
5. **Kein macOS UI Test moeglich** — BUG_111 blockiert macOS UI Tests. Unit Tests + mac-build muessen reichen

## Analysis

### Type
Feature (macOS Paritaet)

### Scope-Entscheidung: Nur Teilbereich A
Die existierende Spec hat 4 Teilbereiche. Empfehlung: **Nur A (Metadata-Eingabe)**.
- **B (KeyboardShortcuts Library):** Externe Dependency, freigabepflichtig. Aktueller Hotkey funktioniert.
- **C (Liquid Glass):** Styling-only, eigenes Ticket.
- **D (URL Scheme):** Anderer Code-Pfad, eigenes Ticket.

### Design-Entscheidung: Option B (lokale View erweitern)
Shared QuickCaptureView hat iOS-Sheet-Semantik (.presentationDetents, .dismiss()) die in NSPanel nicht funktioniert.
→ Lokale macOS-View in QuickCapturePanel.swift erweitern mit Metadaten-Buttons. Shared Helpers (ImportanceUI, UrgencyUI, TaskCategory) nutzen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxMac/QuickCapturePanel.swift` | MODIFY | State-Variablen, Metadaten-Row (4 Buttons), Panel-Hoehe, createTask()-Aufruf erweitern |
| `FocusBloxTests/QuickCaptureMetadataTests.swift` | CREATE | Unit Test fuer Metadaten-Uebergabe |

### Scope Assessment
- Files: 2 (1 modify + 1 create)
- Estimated LoC: +170
- Risk Level: LOW

### Technical Approach
1. State-Variablen hinzufuegen: importance, urgency, taskType, estimatedDuration, showCategoryPicker, showDurationPicker
2. Metadaten-Row mit 4 Cycle/Popover-Buttons (Pattern aus iOS View kopieren)
3. `.popover()` statt `.sheet()` fuer CategoryPicker/DurationPicker
4. Panel-Hoehe von 60 auf ~120px erhoehen
5. addTask() erweitern: alle Metadaten an createTask() uebergeben
6. Felder beim Dismiss zuruecksetzen

### Dependencies
- **Shared (bereits verfuegbar im macOS Target):** ImportanceUI, UrgencyUI, TaskCategory, CategoryPicker, DurationPicker, LocalTaskSource
- **Keine neuen Dependencies noetig**
