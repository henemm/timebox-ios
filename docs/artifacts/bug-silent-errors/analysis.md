# Bug-Analyse: Fehlermeldungen verschwinden lautlos (#276)

## Root Cause

Alle betroffenen Views nutzen eine exklusive `if isLoading / else if errorMessage / else content`-Kette.
Bei Mutations-Fehlern (Task löschen, verschieben etc.) ist IMMER Content vorhanden → der `errorMessage`-Zweig greift NIE.

Zusätzlich: `loadData()` setzt als erste Aktion `errorMessage = nil` — selbst wenn der Fehler kurz sichtbar wäre, wird er durch den nächsten Reload sofort gelöscht (Race Condition).

## Betroffene Views (6 Stück)

| View | Mutations-Fehler | Hat bereits .alert()? |
|------|------------------|-----------------------|
| FocusLiveView | 5x | Nein |
| PlanningView | 8x | Nein |
| BlockPlanningView | 12x | Nein |
| TaskAssignmentView | 7x | Nein |
| MacPlanningView | 9x | Nein |
| MacFocusView | 4x | Nein |

BacklogView hat bereits 3 spezifische Alerts — fehlt aber der generelle errorMessage-Alert.

## Referenz-Pattern (CoachView.swift:188)

```swift
.alert("Fehler", isPresented: Binding(
    get: { errorMessage != nil },
    set: { if !$0 { errorMessage = nil } }
)) {
    Button("OK") { errorMessage = nil }
} message: {
    if let msg = errorMessage { Text(msg) }
}
```

## Lösung

ViewModifier (`ErrorAlertModifier`) + Anwendung in den Views.
Scope-Limit (5 Dateien) → iOS first, Mac als Follow-Up.

## Blast Radius

- Keine bestehenden Tests brechen
- Keine Konflikte mit vorhandenen .alert()-Modifiern
- SwiftUI unterstützt multiple .alert() mit verschiedenen Bindings
