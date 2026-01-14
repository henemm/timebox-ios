---
entity_id: calendar-selection
type: feature
created: 2026-01-14
status: draft
workflow: calendar-selection
---

# Calendar Selection (Settings)

## Approval

- [x] Approved for implementation

## Purpose

User kann in den Settings:
1. **Ziel-Kalender wählen** - In welchem Kalender werden Focus Blocks erstellt?
2. **Sichtbare Kalender filtern** - Welche Kalender werden in der Timeline angezeigt?

Aktuell wird immer der System-Default verwendet und alle Kalender werden angezeigt.

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/SettingsView.swift` | CREATE | Neue Settings UI mit Kalender-Picker |
| `Sources/Services/EventKitRepository.swift` | MODIFY | `getWritableCalendars()`, `calendarForEvents()` |
| `Sources/Views/SettingsToolbarModifier.swift` | CREATE | Reusable Toolbar-Modifier für Gear-Button |
| `Sources/Views/BacklogView.swift` | MODIFY | Toolbar-Modifier anwenden |
| `Sources/Views/BlockPlanningView.swift` | MODIFY | Toolbar-Modifier anwenden |
| `Sources/Views/TaskAssignmentView.swift` | MODIFY | Toolbar-Modifier anwenden |
| `Sources/Views/FocusLiveView.swift` | MODIFY | Toolbar-Modifier anwenden |

### Estimated Size
- Files: 7
- LoC: +180/-5
- Risk: LOW

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| EventKit | Framework | EKCalendar, EKEventStore APIs |
| AppStorage | SwiftUI | Persistenz der Kalender-Auswahl |
| UserDefaults | Foundation | Fallback für Repository-Zugriff |

## Implementation Details

### 1. EventKitRepository Erweiterungen

```swift
// Neue Methode: Alle Kalender abrufen
func getAllCalendars() -> [EKCalendar] {
    eventStore.calendars(for: .event)
}

// Neue Methode: Alle beschreibbaren Kalender (für Ziel-Auswahl)
func getWritableCalendars() -> [EKCalendar] {
    eventStore.calendars(for: .event)
        .filter { $0.allowsContentModifications }
}

// Neue Methode: Ausgewählten Ziel-Kalender mit Fallback
func calendarForEvents() -> EKCalendar? {
    if let id = UserDefaults.standard.string(forKey: "selectedCalendarID"),
       let calendar = eventStore.calendar(withIdentifier: id),
       calendar.allowsContentModifications {
        return calendar
    }
    return eventStore.defaultCalendarForNewEvents
}

// Neue Methode: Sichtbare Kalender-IDs
func visibleCalendarIDs() -> [String]? {
    UserDefaults.standard.array(forKey: "visibleCalendarIDs") as? [String]
}

// Neue Methode: Sichtbare Kalender als EKCalendar Array
func visibleCalendars() -> [EKCalendar]? {
    guard let ids = visibleCalendarIDs(), !ids.isEmpty else { return nil }
    return ids.compactMap { eventStore.calendar(withIdentifier: $0) }
}
```

**Änderungen in bestehenden Methoden:**
- `createCalendarEvent()`: `event.calendar = calendarForEvents()` statt `defaultCalendarForNewEvents`
- `createFocusBlock()`: `event.calendar = calendarForEvents()` statt `defaultCalendarForNewEvents`
- `fetchCalendarEvents()`: `calendars: visibleCalendars()` statt `calendars: nil`

### 2. SettingsView

```swift
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCalendarID") private var selectedCalendarID: String = ""
    @State private var visibleCalendarIDs: Set<String> = []
    @State private var eventKitRepo = EventKitRepository()
    @State private var allCalendars: [EKCalendar] = []
    @State private var writableCalendars: [EKCalendar] = []

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Ziel-Kalender
                Section {
                    Picker("Focus Blocks speichern in", selection: $selectedCalendarID) {
                        Text("Standard").tag("")
                        ForEach(writableCalendars, id: \.calendarIdentifier) { cal in
                            CalendarRow(calendar: cal)
                                .tag(cal.calendarIdentifier)
                        }
                    }
                } header: {
                    Text("Ziel-Kalender")
                } footer: {
                    Text("Neue Focus Blocks werden in diesem Kalender erstellt.")
                }

                // Section 2: Sichtbare Kalender
                Section {
                    ForEach(allCalendars, id: \.calendarIdentifier) { cal in
                        Toggle(isOn: binding(for: cal.calendarIdentifier)) {
                            CalendarRow(calendar: cal)
                        }
                    }
                } header: {
                    Text("Sichtbare Kalender")
                } footer: {
                    Text("Nur ausgewählte Kalender werden in der Timeline angezeigt.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        saveVisibleCalendars()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCalendars()
            }
        }
    }

    private func binding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: { visibleCalendarIDs.contains(calendarID) },
            set: { isVisible in
                if isVisible {
                    visibleCalendarIDs.insert(calendarID)
                } else {
                    visibleCalendarIDs.remove(calendarID)
                }
            }
        )
    }

    private func loadCalendars() {
        allCalendars = eventKitRepo.getAllCalendars()
        writableCalendars = eventKitRepo.getWritableCalendars()

        // Load saved visible calendars or default to all
        if let saved = eventKitRepo.visibleCalendarIDs() {
            visibleCalendarIDs = Set(saved)
        } else {
            visibleCalendarIDs = Set(allCalendars.map(\.calendarIdentifier))
        }
    }

    private func saveVisibleCalendars() {
        UserDefaults.standard.set(Array(visibleCalendarIDs), forKey: "visibleCalendarIDs")
    }
}

// Helper View
struct CalendarRow: View {
    let calendar: EKCalendar

    var body: some View {
        HStack {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 12, height: 12)
            Text(calendar.title)
        }
    }
}
```

### 3. SettingsToolbarModifier (Reusable)

```swift
struct SettingsToolbarModifier: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}

extension View {
    func withSettingsToolbar() -> some View {
        modifier(SettingsToolbarModifier())
    }
}
```

### 4. Integration in allen Views

```swift
// In BacklogView, BlockPlanningView, TaskAssignmentView, FocusLiveView:
NavigationStack {
    // ... content ...
}
.withSettingsToolbar()  // Eine Zeile pro View
```

## Expected Behavior

- **Input:** User wählt Kalender aus Picker
- **Output:** Kalender-ID wird in UserDefaults gespeichert
- **Side Effects:**
  - Neue Focus Blocks werden im gewählten Kalender erstellt
  - Bestehende Focus Blocks bleiben im alten Kalender (keine Migration)

### Fallback-Verhalten
- Wenn ausgewählter Kalender gelöscht wurde → Default-Kalender verwenden
- Wenn kein Kalender ausgewählt ("Standard") → Default-Kalender verwenden

## Test Plan

### Automated Tests (Unit)
- [ ] `testGetAllCalendarsReturnsAllCalendars` - Alle Kalender zurückgeben
- [ ] `testGetWritableCalendarsReturnsOnlyWritable` - Nur beschreibbare Kalender
- [ ] `testCalendarForEventsReturnsDefaultWhenNoSelection` - Default bei leerer Selection
- [ ] `testCalendarForEventsReturnsSelectedCalendar` - Ausgewählten Kalender zurückgeben
- [ ] `testVisibleCalendarsReturnsNilWhenNotSet` - Nil wenn keine Auswahl
- [ ] `testVisibleCalendarsReturnsSelectedCalendars` - Nur ausgewählte Kalender

### Manual Tests
- [ ] Gear-Button in allen 4 Tabs sichtbar (oben rechts)
- [ ] Tap auf Gear öffnet Settings als Sheet
- [ ] **Ziel-Kalender:** Picker zeigt nur beschreibbare Kalender
- [ ] **Sichtbare Kalender:** Toggles für alle Kalender vorhanden
- [ ] Ziel-Kalender wird nach App-Neustart beibehalten
- [ ] Sichtbare Kalender werden nach App-Neustart beibehalten
- [ ] Focus Block wird im Ziel-Kalender erstellt
- [ ] Timeline zeigt nur Events aus sichtbaren Kalendern
- [ ] Default: Alle Kalender sind sichtbar (wenn noch nichts eingestellt)

## Acceptance Criteria

### Settings-Zugang
- [ ] Gear-Button (⚙️) in Toolbar aller 4 Tabs verfügbar
- [ ] Settings öffnet als Modal Sheet mit "Fertig" Button

### Ziel-Kalender
- [ ] Picker zeigt nur beschreibbare Kalender (keine read-only)
- [ ] Kalender-Farbe als visueller Indikator
- [ ] Focus Blocks werden im gewählten Kalender erstellt
- [ ] Fallback auf Default-Kalender bei ungültiger Auswahl

### Sichtbare Kalender
- [ ] Toggle für jeden verfügbaren Kalender
- [ ] Default: Alle Kalender sichtbar
- [ ] Timeline zeigt nur Events aus aktivierten Kalendern
- [ ] Einstellung persistiert über App-Neustart

## Known Limitations

- Bestehende Focus Blocks werden nicht migriert (bleiben im alten Kalender)
- Nur ein globaler Kalender auswählbar (nicht pro Focus Block)

## Changelog

- 2026-01-14: Initial spec created
