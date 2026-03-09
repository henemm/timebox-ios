# Bug 85-A: Uhrzeit bei Fälligkeitsdatum anzeigen

## Problem

Die Uhrzeit wird im DatePicker gespeichert (`[.date, .hourAndMinute]`), aber nirgendwo angezeigt. Der Shared Formatter `Date+DueDate.swift` setzt `timeStyle = .none` und die Early-Returns für "Heute"/"Morgen"/Wochentag geben reine Strings ohne Uhrzeit zurück.

Zusätzlich: macOS `TaskInspector.swift` hat einen DatePicker mit nur `.date` — dort kann keine Uhrzeit eingegeben werden.

## Betroffene Dateien

### Ausgabe (1 Datei)
- `Sources/Extensions/Date+DueDate.swift` — Shared Formatter, 4 Code-Pfade

### Eingabe (1 Datei)
- `FocusBloxMac/TaskInspector.swift:105` — DatePicker `.date` → `[.date, .hourAndMinute]`

## Gewünschtes Verhalten

Wenn eine Uhrzeit gesetzt ist (≠ 00:00), wird sie hinter dem Datum angezeigt:
- "Heute, 14:30" statt "Heute"
- "Morgen, 09:00" statt "Morgen"
- "Mo, 14:30" statt "Mo"
- "12.03.26, 14:30" statt "12.03.26"

Wenn Uhrzeit = 00:00 → keine Uhrzeitanzeige (= "nicht gesetzt").

## Implementation

### Date+DueDate.swift

Alle 4 Code-Pfade in `dueDateText(style:)` anpassen:

```swift
func dueDateText(style: DueDateStyle = .compact) -> String {
    let calendar = Calendar.current
    let timeSuffix = self.timeString // ", 14:30" oder ""

    if calendar.isDateInToday(self) {
        return "Heute" + timeSuffix
    } else if calendar.isDateInTomorrow(self) {
        return "Morgen" + timeSuffix
    } else if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
        let formatter = DateFormatter()
        formatter.dateFormat = style == .compact ? "EEE" : "EEEE"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self) + timeSuffix
    } else {
        let formatter = DateFormatter()
        formatter.dateStyle = style == .compact ? .short : .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self) + timeSuffix
    }
}

/// Returns ", HH:mm" if time is not midnight, otherwise empty string.
private var timeString: String {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: self)
    let minute = calendar.component(.minute, from: self)
    guard hour != 0 || minute != 0 else { return "" }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return ", " + formatter.string(from: self)
}
```

### TaskInspector.swift:105

```swift
// Vorher:
displayedComponents: .date)
// Nachher:
displayedComponents: [.date, .hourAndMinute])
```

## Acceptance Criteria

- [ ] "Heute, 14:30" wird angezeigt wenn dueDate = heute 14:30
- [ ] "Heute" wird angezeigt wenn dueDate = heute 00:00 (keine Uhrzeit)
- [ ] "Morgen, 09:00" wird angezeigt wenn dueDate = morgen 09:00
- [ ] Wochentag + Uhrzeit bei Daten in aktueller Woche
- [ ] Datum + Uhrzeit bei entfernten Daten
- [ ] macOS TaskInspector erlaubt Uhrzeit-Eingabe
- [ ] Alle 4 Anzeige-Stellen profitieren automatisch (Shared Formatter)
