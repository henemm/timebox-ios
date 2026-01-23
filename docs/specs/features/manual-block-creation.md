# Spec: Manuelle Block-Erstellung im Blöcke-Tab

## Problem

Smart Gaps zeigt nur automatisch erkannte Slots (30-60 min). User kann KEINE eigenen Blöcke mit custom Zeiten anlegen.

**Beispiel-Use-Case:**
- User will einen 90-min Deep Work Block von 13:00-14:30
- Smart Gaps schlägt das nicht vor (zu lang)
- User hat keine Möglichkeit, diesen Block manuell anzulegen

## Analyse-Ergebnis

Das `CreateFocusBlockSheet` existiert bereits im Code, ist aber **DEAKTIVIERT**:

| Element | Status | Location |
|---------|--------|----------|
| `showCreateSheet` State | Definiert, nie `true` | Line 10 |
| `CreateFocusBlockSheet` | Vollständig implementiert | Line 531-593 |
| DatePicker für Start/End | Vorhanden | In Sheet |
| Trigger-Button | **FEHLT** | Nirgendwo |

## Lösung

**"Eigenen Block erstellen" Button unter Smart Gaps**

```
┌─────────────────────────────────┐
│ 🎯 Freie Slots                  │
│ ┌─────────────────────────────┐ │
│ │ 09:00-10:00 (60m)    [+]    │ │
│ │ 14:00-15:00 (60m)    [+]    │ │
│ └─────────────────────────────┘ │
│                                 │
│ [➕ Eigenen Block erstellen]    │ ← NEU
└─────────────────────────────────┘
```

## Technische Umsetzung

### Änderungen (1 Datei, ~20 LoC)

**BlockPlanningView.swift:**

1. Helper-Funktion für gerundete Zeit:
```swift
private func roundedCurrentTime() -> Date {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
    var nextHour = calendar.date(from: components) ?? now
    if now > nextHour {
        nextHour = nextHour.addingTimeInterval(3600)
    }
    return nextHour
}
```

2. Button in smartGapsContent nach SmartGapsSection:
```swift
Button {
    let startDate = roundedCurrentTime()
    selectedSlot = TimeSlot(
        startDate: startDate,
        endDate: startDate.addingTimeInterval(3600)
    )
    showCreateSheet = true
} label: {
    Label("Eigenen Block erstellen", systemImage: "plus.rectangle")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.tint(.blue)
.accessibilityIdentifier("createCustomBlockButton")
```

3. Sheet ist bereits verdrahtet (Line 48-57) - keine Änderung nötig.

## Test Plan

### Unit Tests
- Keine neuen nötig (Sheet-Logik existiert bereits)

### UI Tests (TDD RED)
1. `testManualBlockCreationButtonExists` - Button ist sichtbar
2. `testManualBlockCreationOpensSheet` - Tap öffnet Sheet
3. `testManualBlockCreationWithCustomTime` - Block mit custom Zeit erstellen

### Manual Tests
- [ ] Button "Eigenen Block erstellen" ist sichtbar
- [ ] Tap öffnet DatePicker-Sheet
- [ ] Freie Zeitwahl möglich (keine Slot-Beschränkung)
- [ ] Block wird korrekt erstellt
- [ ] Block erscheint in der Liste

## Acceptance Criteria

- [ ] User kann Blöcke mit beliebiger Start/End-Zeit erstellen
- [ ] Existierendes Sheet wird wiederverwendet (kein neuer Code)
- [ ] UI ist konsistent mit Smart Gaps Design
- [ ] Button hat accessibilityIdentifier für UI Tests

## Dateien

| Datei | Änderung |
|-------|----------|
| `TimeBox/Sources/Views/BlockPlanningView.swift` | Button + Helper hinzufügen (~20 LoC) |

## Verification

1. Build: `xcodebuild build -scheme TimeBox`
2. UI Tests: `xcodebuild test -only-testing:TimeBoxUITests/ManualBlockCreationUITests`
3. Manual: App öffnen → Blöcke Tab → "Eigenen Block erstellen" → Sheet → Zeit wählen → Erstellen
