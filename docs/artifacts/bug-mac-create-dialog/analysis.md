# Bug: macOS Neuanlegen-Dialog verwendet eigenen Dialog statt shared TaskFormSheet

## Symptom
Der "+" Button in der macOS Toolbar oeffnet `MacTaskCreateSheet` — einen simplen Dialog mit Dropdown-Pickern. Stattdessen sollte der etablierte `TaskFormSheet` (Rich Edit Dialog mit Pill-Buttons, Glassmorphism, Recurrence, etc.) verwendet werden.

## Agenten-Ergebnisse

### 1. Wiederholungs-Check
Kein frueherer Bug zu diesem Thema. `MacTaskCreateSheet` existiert seit der initialen macOS-Implementation. Bekannte technische Schuld (TD_002 in ACTIVE-todos.md: View-Duplikation iOS/macOS).

### 2. Datenfluss-Trace
- macOS `ContentView.swift:525-528`: `.sheet(isPresented: $showCreateTask) { MacTaskCreateSheet { refreshTasks() } }`
- iOS `BacklogView.swift:229-235`: `.sheet(isPresented: $showCreateTask) { TaskFormSheet { ... } }`
- `MacTaskCreateSheet` = 142 Zeilen, simple Dropdown-Picker
- `TaskFormSheet` = 597 Zeilen, Rich UI mit Pill-Buttons, Recurrence, Blocker, Emotional Nudge

### 3. Alle Create-Task Views
- `TaskFormSheet` (Sources/Views/) — shared, von iOS genutzt, NICHT im macOS Target
- `MacTaskCreateSheet` (FocusBloxMac/) — macOS-only, Duplikat mit weniger Features

### 4. Szenarien
- macOS "+" Button und Cmd+N oeffnen beide `MacTaskCreateSheet`
- Quick Capture (Cmd+Shift+Space) ist separat — nicht betroffen

### 5. Blast Radius
- macOS hat weitere eigene Views (Settings, Review, BacklogRow) — bekannte Divergenz
- Dieser Fix hat keinen negativen Blast Radius auf andere Features

## Hypothesen

### H1: macOS ContentView referenziert falschen Dialog (95% Wahrscheinlichkeit)
- **Beweis dafuer:** `ContentView.swift:525` zeigt explizit `MacTaskCreateSheet`
- **Beweis dagegen:** Keiner
- **Ursache:** macOS wurde mit eigenem simplen Dialog gebaut, bevor der Rich Edit Dialog existierte

### H2: TaskFormSheet ist nicht macOS-kompatibel (20% Wahrscheinlichkeit)
- **Beweis dafuer:** `TaskFormSheet` nutzt iOS-spezifische APIs: `.navigationBarTitleDisplayMode(.inline)`, `Color(.systemGroupedBackground)`, `.sensoryFeedback()`, `IntentDonationManager`
- **Beweis dagegen:** Andere shared Views (BlockerPickerSheet, EditFocusBlockSheet) nutzen bereits `#if os(iOS)` Guards fuer diese APIs und kompilieren auf macOS
- **Risiko:** Beherrschbar — 3-4 `#if os(iOS)` Guards noetig

### H3: TaskFormSheet nicht im macOS Xcode Target (100% bestaetigt)
- `TaskFormSheet.swift` ist NUR im FocusBlox (iOS) Target, NICHT im FocusBloxMac Target
- Muss explizit hinzugefuegt werden

## Wahrscheinlichste Ursache
Kombination H1 + H3: `ContentView.swift` muss `TaskFormSheet` statt `MacTaskCreateSheet` verwenden, und `TaskFormSheet.swift` muss zum macOS Target hinzugefuegt werden. Zusaetzlich braucht `TaskFormSheet` `#if os(iOS)` Guards fuer 3 iOS-spezifische APIs.

## Fix-Plan

### Dateien die geaendert werden:
1. **`Sources/Views/TaskFormSheet.swift`** — `#if os(iOS)` Guards fuer:
   - `.navigationBarTitleDisplayMode(.inline)` (Zeile 370)
   - `Color(.systemGroupedBackground)` (Zeile 368)
   - `.sensoryFeedback()` (Zeile 176)
   - `IntentDonationManager` / `CreateTaskIntent` (Zeilen 551-553)
2. **`FocusBloxMac/ContentView.swift`** — Sheet-Praesentation von `MacTaskCreateSheet` auf `TaskFormSheet` aendern (Zeile 525-528)
3. **`FocusBlox.xcodeproj/project.pbxproj`** — `TaskFormSheet.swift` zum FocusBloxMac Target hinzufuegen (via pbxproj Python)

### Dateien die geloescht werden koennten:
- `FocusBloxMac/MacTaskCreateSheet.swift` — wird nicht mehr gebraucht

### Call-Sites:
- `ContentView.swift:525` (macOS) — wird von `MacTaskCreateSheet` auf `TaskFormSheet` umgestellt
- `BacklogView.swift:229` (iOS) — bleibt unveraendert

## Blast Radius
- iOS: Keine Aenderung (TaskFormSheet bekommt nur `#if os(iOS)` Guards die auf iOS nichts aendern)
- macOS: Neuer Dialog statt alter Dialog — volle Feature-Paritaet
- Cmd+N Shortcut: Nutzt denselben `showCreateTask` State — profitiert automatisch
