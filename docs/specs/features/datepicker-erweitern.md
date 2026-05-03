---
entity_id: datepicker-erweitern
type: feature
created: 2026-05-03
updated: 2026-05-03
status: draft
version: "1.0"
tags: [backlog, postpone, datepicker, ios, macos]
---

# Feature #293 — "Eigenes Datum" im Verschieben-Dialog

## Approval

- [ ] Approved

## Purpose

Erweitert den Verschieben-Dialog um einen dritten Eintrag "Eigenes Datum...", der einen nativen DatePicker (Datum + Uhrzeit) öffnet. Damit kann ein Nutzer eine Task auf einen beliebigen zukünftigen oder vergangenen Zeitpunkt legen, ohne die App zu wechseln.

## Source

- **File:** `Sources/Views/BacklogView.swift` (iOS), `FocusBloxMac/ContentView.swift` (macOS), `Sources/Models/LocalTask.swift` (Service)
- **Identifier:** `postponeMenu()`, `postpone(_:to:context:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask.dueDate` | model field | Aufnahme des gewählten Datums |
| `LocalTask.rescheduleCount` | model field | Inkrementierung bei jeder Verschiebung |
| `LocalTask.postpone(byDays:context:)` | function | Bestehendes Pattern, neue Methode folgt demselben Muster |
| `NotificationCenter / .taskDataChanged` | notification | macOS-übergreifende View-Aktualisierung nach Save |
| `BacklogView.postponeMenu()` | function | iOS-Einstiegspunkt, wird um dritten Menüpunkt erweitert |
| `FocusBloxMac/ContentView.swift` context menu (Z. 1018–1021) | ui | macOS-Einstiegspunkt, wird analog erweitert |

## Implementation Details

### Neue Methode in `Sources/Models/LocalTask.swift`

```swift
static func postpone(_ task: PlanItem, to date: Date, context: ModelContext) {
    task.dueDate = date
    task.rescheduleCount += 1
    try? context.save()
    NotificationCenter.default.post(name: .taskDataChanged, object: nil)
}
```

Hinweise:
- Methode ist plattform-agnostisch und sendet die Notification immer — auf iOS ist das ein no-op, auf macOS triggert es `ContentView.refreshTasks()`.
- Der bestehende `postponeTask(byDays:)` in `ContentView.swift` wird NICHT verändert (Out-of-scope).

### Default-Datum

```swift
Calendar.current.date(bySettingHour: 9, minute: 0, second: 0,
    of: Date.now.addingTimeInterval(86400)) ?? Date.now
```

Immer morgen 09:00, unabhängig von der aktuellen Uhrzeit.

### DatePicker-Konfiguration

```swift
DatePicker("", selection: $customDate, displayedComponents: [.date, .hourAndMinute])
```

Keine `minimumDate`/`maximumDate`-Einschränkung — vergangene Daten sind erlaubt.

### iOS — Änderung in `Sources/Views/BacklogView.swift`

Neue State-Variablen:

```swift
@State private var showCustomDateSheet: Bool = false
@State private var customDateTaskID: UUID? = nil
@State private var customDate: Date = /* default, s.o. */
```

`postponeMenu()` bekommt dritten Eintrag:

```swift
Button("Eigenes Datum...") {
    customDate = /* morgen 09:00 */
    customDateTaskID = task.id
    showCustomDateSheet = true
}
.accessibilityIdentifier("customDateMenuButton")
```

Sheet (an der View-Root anhängen):

```swift
.sheet(isPresented: $showCustomDateSheet) {
    // Identifier auf dem Container-View: customDateSheet
    VStack {
        DatePicker(...)
        HStack {
            Button("Abbrechen") { showCustomDateSheet = false }
                .accessibilityIdentifier("customDateCancelButton")
            Button("Bestätigen") {
                if let id = customDateTaskID,
                   let task = tasks.first(where: { $0.id == id }) {
                    LocalTask.postpone(task, to: customDate, context: modelContext)
                }
                showCustomDateSheet = false
            }
            .accessibilityIdentifier("customDateConfirmButton")
        }
    }
    .accessibilityIdentifier("customDateSheet")
}
```

### macOS — Änderung in `FocusBloxMac/ContentView.swift`

Analog zu iOS, aber `.popover(isPresented:)` statt `.sheet(isPresented:)`. Gleiche State-Vars, gleiche Identifier, gleicher Aufruf von `LocalTask.postpone(_:to:context:)`.

## Expected Behavior

- **Input:** Nutzer wählt "Eigenes Datum..." im Verschieben-Untermenü, wählt Datum + Uhrzeit im Picker, tippt "Bestätigen"
- **Output:** `task.dueDate` ist exakt der gewählte `Date`-Wert; `task.rescheduleCount` ist um 1 erhöht; Sheet/Popover ist geschlossen
- **Side effects:** `context.save()` persistiert; `taskDataChanged`-Notification wird gesendet (macOS aktualisiert ContentView)

### Abbrechen-Pfad

- `task.dueDate` bleibt unverändert
- `task.rescheduleCount` bleibt unverändert
- Sheet/Popover schließt ohne Save

## Acceptance Criteria

| Nr | Kriterium |
|----|-----------|
| AC-1 | Long-Press auf eine Backlog-Task zeigt im Verschieben-Untermenü drei Einträge: "Morgen", "Nächste Woche", "Eigenes Datum..." |
| AC-2 | Tap auf "Eigenes Datum..." öffnet einen Picker mit Datum UND Uhrzeit |
| AC-3 | Beim ersten Öffnen zeigt der Picker morgen 09:00 vorausgewählt |
| AC-4 | Bestätigen mit Default-Datum: `task.dueDate` ist morgen 09:00 |
| AC-5 | Bestätigen mit manuell gewähltem Datum (z.B. 14. Mai 14:30): `task.dueDate` ist exakt dieser Wert |
| AC-6 | Bestätigen erhöht `rescheduleCount` um 1 |
| AC-7 | Abbrechen lässt `task.dueDate` unverändert |
| AC-8 | Abbrechen lässt `rescheduleCount` unverändert |
| AC-9 | Auf macOS öffnet der Picker als Popover (nicht als Sheet) |
| AC-10 | Auf iOS öffnet der Picker als Sheet |
| AC-11 | Ein Datum in der Vergangenheit kann gewählt werden — keine Sperre, kein Warning |

## Accessibility Identifiers

| Identifier | Element | Plattform |
|------------|---------|-----------|
| `customDateMenuButton` | Menüeintrag "Eigenes Datum..." | iOS + macOS |
| `customDateSheet` | Sheet-Container (iOS) | iOS |
| `customDateConfirmButton` | "Bestätigen"-Button | iOS + macOS |
| `customDateCancelButton` | "Abbrechen"-Button | iOS + macOS |

## Test-Hinweise (für Phase 4 / QA-Writer)

### Unit-Tests (`FocusBloxTests/TaskPostponeTests.swift`)

- `postpone(_:to:context:)` setzt `dueDate` exakt auf den übergebenen Wert
- `postpone(_:to:context:)` inkrementiert `rescheduleCount` um genau 1
- Vergangenes Datum wird ohne Fehler gesetzt (`dueDate` < `Date.now` ist valide)

### UI-Tests iOS (`FocusBloxUITests/CustomDatePostponeUITests.swift` oder Erweiterung bestehender Backlog-UI-Tests)

- Menü zeigt Eintrag mit Identifier `customDateMenuButton`
- Tap auf `customDateMenuButton` öffnet View mit Identifier `customDateSheet`
- `customDateConfirmButton` ist vorhanden und tappbar
- `customDateCancelButton` schließt Sheet ohne Datenänderung
- Nach Bestätigen: `task.dueDate` entspricht gewähltem Wert (via Data-State-Prüfung, nicht nur UI-Label)

## Out-of-Scope

- Bestehender macOS-Bug: `postponeTask(byDays:)` postet keine `taskDataChanged`-Notification — wird NICHT als Drive-by gefixt
- "Letzte Uhrzeiten als Schnellauswahl" — separates Feature
- Recurring-Task-Sonderbehandlung — gleiches Verhalten wie bisheriger `postpone(byDays:)`
- "Heute"-Option im Menü

## Affected Files

1. `Sources/Models/LocalTask.swift`
2. `Sources/Views/BacklogView.swift`
3. `FocusBloxMac/ContentView.swift`
4. `FocusBloxTests/TaskPostponeTests.swift`
5. `FocusBloxUITests/CustomDatePostponeUITests.swift`

## Known Limitations

- Der Default-Wert "morgen 09:00" basiert auf `Date.now` zum Zeitpunkt des Öffnens des Menüs, nicht zum Zeitpunkt des Bestätigens. Das ist das erwartete Verhalten.

## Changelog

- 2026-05-03: Initial spec created
