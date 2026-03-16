---
entity_id: bug-watch-quick-capture-simplify
type: bugfix
created: 2026-03-16
updated: 2026-03-16
status: draft
version: "1.0"
tags: [watchos, quick-capture, ux-simplification]
---

# Bug: Watch Quick Capture — Unnoetige UI-Elemente entfernen

## Approval

- [ ] Approved

## Purpose

VoiceInputSheet auf der Watch zeigt unnoetige UI-Elemente ("Was moechtest du tun?", "Abbrechen"-Button, "Neuer Task"-Titel), die den Quick-Capture-Flow verlangsamen. Laut User Story soll der Flow "1 Tap + Sprechen + fertig" sein — max 3 Sekunden aktive Interaktion.

## User Story Reference

`docs/project/stories/watch-quick-capture.md` (Approved):
> "When ich unterwegs bin, I want to einen Gedanken blitzschnell auf der Watch festhalten, So that der Gedanke nicht verloren geht."
> Erfolgskriterium: "Gesamtflow Complication: 1 Tap + Sprechen + fertig (max 3 Sekunden aktive Interaktion)"

## Root Cause

VoiceInputSheet wurde mit NavigationStack + Toolbar + Prompt-Text implementiert, obwohl die User Story einen minimalen Flow ohne Zwischenscreen vorsieht. Der 1.5s Auto-Save-Delay addiert weitere unnoetige Wartezeit.

## Ist-Zustand

```
Complication-Tap → App oeffnet → Sheet oeffnet mit:
  - "Neuer Task" (NavigationTitle)
  - "Was moechtest du tun?" (Prompt-Text)
  - TextField (fokussiert → Diktat startet)
  - "Abbrechen" (Toolbar-Button)
→ User spricht → Text erscheint → 1.5s warten → Auto-Save + Haptik
```

## Soll-Zustand

```
Complication-Tap → App oeffnet → Sheet oeffnet mit:
  - TextField (fokussiert → Diktat startet sofort)
→ User spricht → Text erscheint → 0.5s → Auto-Save + Haptik + Dismiss
→ Abbruch: Swipe-Down (watchOS-Standard)
```

## Source

### Zu aendernde Dateien

| Datei | Aenderung | Beschreibung |
|-------|-----------|-------------|
| `FocusBloxWatch Watch App/VoiceInputSheet.swift` | MODIFY | NavigationStack, Toolbar, Prompt-Text entfernen. Auto-Save Delay 1.5s → 0.5s |
| `FocusBloxWatch Watch AppUITests/FocusBloxWatch_Watch_AppUITests.swift` | MODIFY | Tests fuer entfernte UI-Elemente anpassen |

### Nicht zu aendern

| Datei | Grund |
|-------|-------|
| `FocusBloxWatch Watch App/ContentView.swift` | Auto-Open + Deep-Link funktionieren bereits korrekt |
| `FocusBloxWatch Watch App/WatchLocalTask.swift` | Schema unveraendert |
| `FocusBloxWatchWidgets/QuickCaptureComplication.swift` | Complication + Deep-Link unveraendert |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ModelContext` | SwiftData | Task-Persistenz |
| `WKInterfaceDevice` | WatchKit | Haptik-Feedback (.success) |
| `LocalTask` | Model | Task-Objekt mit needsTitleImprovement Flag |
| `CloudKit Sync` | System | Automatischer Sync zum iPhone (unveraendert) |

## Implementation Details

### 1. VoiceInputSheet.swift — UI vereinfachen

**Entfernen:**
- `NavigationStack` Wrapper
- `.navigationTitle("Neuer Task")`
- `.navigationBarTitleDisplayMode(.inline)`
- `.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") ... } }`
- `Text("Was moechtest du tun?")`

**Beibehalten:**
- `VStack` mit `TextField`
- `@FocusState` + `onAppear { isFocused = true }` (Diktat-Trigger)
- `scheduleAutoSave()` Logik (mit reduziertem Delay)
- `saveTask()` + Haptik + Dismiss

**Aendern:**
- Auto-Save Delay: `1.5` → `0.5` Sekunden

**Ergebnis-View:**
```swift
struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskTitle = ""
    @State private var autoSaveTask: DispatchWorkItem?
    @FocusState private var isFocused: Bool
    let modelContext: ModelContext

    var body: some View {
        VStack {
            TextField("Task eingeben...", text: $taskTitle)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .accessibilityIdentifier("taskTitleField")
                .onChange(of: taskTitle) { _, newValue in
                    scheduleAutoSave(for: newValue)
                }
        }
        .padding()
        .onAppear { isFocused = true }
    }
    // scheduleAutoSave + saveTask bleiben, nur Delay 1.5 → 0.5
}
```

### 2. UI Tests — Anpassungen

**Tests die ENTFERNT werden:**
- `test_voiceInputSheet_cancelButtonExists()` — cancelButton existiert nicht mehr
- `test_complicationFlow_voiceInputSheetComplete()` — prueft "Was moechtest du tun?" und cancelButton

**Tests die ANGEPASST werden:**
- `test_complicationFlow_reopenAfterCancel()` — Sheet-Dismiss statt cancelButton-Tap (Swipe-Down oder alternative Dismiss-Methode)

**Tests die BLEIBEN (unveraendert):**
- `test_appLaunch_autoDiktatOpens()` — prueft taskTitleField erscheint
- `test_voiceInputSheet_noOKButton()` — prueft kein saveButton
- `test_noConfirmationScreenExists()` — prueft kein Bestaetigungs-Screen

## Expected Behavior

### Happy Path (Complication-Tap)
1. User tippt Complication auf Watchface
2. App oeffnet, Sheet erscheint sofort
3. TextField fokussiert → watchOS Diktat-UI startet
4. User spricht "Milch kaufen"
5. Text erscheint im TextField
6. 0.5s Pause → Auto-Save + Haptik (.success) + Sheet schliesst
7. ContentView zeigt "Milch kaufen" in "Letzte Tasks"

### Happy Path (App oeffnen)
1. User oeffnet Watch-App direkt
2. Identischer Flow wie Complication-Tap (Auto-Open)

### Abbruch-Path
1. User oeffnet App, Diktat startet
2. Erkennung ist Quatsch
3. User wischt Sheet nach unten (watchOS Swipe-Down)
4. Sheet schliesst, kein Task gespeichert
5. User kann "Task hinzufuegen"-Button fuer erneuten Versuch nutzen

### Weiterer Task nach erstem Capture
1. Nach Auto-Save sieht User ContentView mit Task-Liste
2. "Task hinzufuegen"-Button oeffnet neues Sheet
3. Gleicher minimaler Flow

## Scope

- **Dateien:** 2 MODIFY
- **LoC netto:** ~+5/-30 (Netto-Reduktion ~25 LoC)
- **Komplexitaet:** S (1 Session)
- **Risiko:** LOW — isolierte Watch-App, kein Shared-Code

## Tests

### UI Tests (TDD RED — vor Implementation)

| Test | Prueft | Status |
|------|--------|--------|
| `test_appLaunch_autoDiktatOpens` | TextField erscheint automatisch | BEHALTEN |
| `test_voiceInputSheet_noOKButton` | Kein Save-Button | BEHALTEN |
| `test_noConfirmationScreenExists` | Kein Bestaetigungs-Screen | BEHALTEN |
| `test_voiceInputSheet_noCancelButton` | NEU: Kein Abbrechen-Button mehr | NEU (RED) |
| `test_voiceInputSheet_noPromptText` | NEU: Kein "Was moechtest du tun?" Text | NEU (RED) |
| `test_voiceInputSheet_noNavigationTitle` | NEU: Kein "Neuer Task" Titel | NEU (RED) |
| `test_swipeDown_dismissesSheet` | NEU: Swipe-Down schliesst Sheet | NEU (RED) |

### Unit Tests
- Keine neuen Unit Tests noetig (saveTask-Logik und Schema bleiben unveraendert)
- Bestehende `FocusBloxWatch_Watch_AppTests` bleiben gruen

## Known Limitations

- watchOS Simulator unterstuetzt keine Dictation — nur manuelles Tippen testbar
- 0.5s Delay ist Minimum-Sicherheitsnetz gegen Partial-Diktat. Auf echtem Device testen ob ausreichend.
- Swipe-Down-Dismiss ist watchOS-Systemverhalten und nicht per UI Test zuverlaessig testbar

## Risiken

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| 0.5s Delay zu kurz fuer langsames Diktat | Niedrig | Mittel | Bei Bedarf auf 0.8s erhoehen |
| Swipe-Down nicht intuitiv als Abbruch | Niedrig | Niedrig | watchOS-Standard, User kennen es |
| TextField ohne NavigationStack hat Layout-Probleme | Niedrig | Niedrig | Padding + VStack reichen fuer minimale UI |

## Changelog

- 2026-03-16: Initial spec created (v1.0)
