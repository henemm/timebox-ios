---
entity_id: error_alert_modifier
type: module
created: 2026-04-19
updated: 2026-04-19
status: draft
version: "1.0"
tags: [ui, error-handling, viewmodifier]
---

# ErrorAlertModifier — Bug #276: Fehlermeldungen verschwinden lautlos

## Approval

- [ ] Approved

## Purpose

Ein ViewModifier, der Mutations-Fehler in iOS-Views als Alert anzeigt. Er existiert, weil alle betroffenen Views eine exklusive `if isLoading / else if errorMessage / else content`-Kette nutzen, durch die der `errorMessage`-Zweig bei vorhandenem Content nie greift — und weil `loadData()` `errorMessage` sofort auf `nil` setzt (Race Condition).

## Source

- **File:** `Sources/Views/Modifiers/ErrorAlertModifier.swift` (neu)
- **Identifier:** `struct ErrorAlertModifier: ViewModifier`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CoachView` | view | Referenz-Pattern für `.alert(isPresented:)` mit Binding-Wrapper (Zeile 188) |
| `FocusLiveView` | view | Empfänger des Modifiers (5 Mutations-Fehler) |
| `PlanningView` | view | Empfänger des Modifiers (8 Mutations-Fehler) |
| `BlockPlanningView` | view | Empfänger des Modifiers (12 Mutations-Fehler) |
| `BacklogView` | view | Empfänger des Modifiers — hat bereits 3 spezifische Alerts, braucht zusätzlich den generellen errorMessage-Alert |

## Implementation Details

```swift
// Sources/Views/Modifiers/ErrorAlertModifier.swift
struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .alert("Fehler", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
    }
}

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(errorMessage: message))
    }
}
```

**Anwendung in jeder betroffenen View (Beispiel):**
```swift
// Vorher: loadData() beginnt mit errorMessage = nil → Race Condition
// Nachher: loadData() setzt errorMessage = nil NICHT mehr

SomeContentView()
    .errorAlert(message: $errorMessage)
```

**loadData()-Fix (in allen 4 Views):**
- `errorMessage = nil` am Anfang von `loadData()` ENTFERNEN
- `errorMessage` wird ausschliesslich durch Alert-Dismiss (OK-Button) auf `nil` gesetzt

## Expected Behavior

- **Input:** `errorMessage: String?` — gesetzt durch eine fehlgeschlagene Mutation
- **Output:** Alert mit Titel "Fehler", Fehlermeldung als Body-Text, "OK"-Button
- **Side effects:**
  - Alert-Dismiss setzt `errorMessage = nil`
  - SwiftUI-Content bleibt hinter dem Alert sichtbar (kein Vollbild-Ersatz)
  - Bestehende `.alert()`-Modifier in BacklogView und CoachView bleiben unberührt (SwiftUI erlaubt mehrere `.alert()` mit verschiedenen Bindings)

## Acceptance Criteria

1. Wenn eine Mutation fehlschlägt, erscheint ein Alert mit der Fehlermeldung
2. Der Alert hat einen "OK"-Button, der ihn schliesst
3. Der Content bleibt hinter dem Alert sichtbar (kein Vollbild-Ersatz)
4. `loadData()` setzt `errorMessage` NICHT mehr auf `nil` — nur der Alert-Dismiss tut das
5. Bestehende Initial-Load-Fehler (ContentUnavailableView) bleiben unverändert

## Known Limitations

- macOS Views (`MacPlanningView`, `MacFocusView`) sind aus Scope-Gruenden ausgeschlossen — als separates Follow-Up-Ticket
- `TaskAssignmentView` ist aus Scope-Gruenden ausgeschlossen (5-Dateien-Limit: 1 neuer Modifier + 4 Views)
- BacklogViews 3 vorhandene spezifische Alerts koexistieren mit dem neuen generellen Alert — kein Konflikt erwartet, muss aber im Test verifiziert werden

## Changelog

- 2026-04-19: Initial spec created (Bug #276)
