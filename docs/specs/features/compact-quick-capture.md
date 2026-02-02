# Spec: Compact QuickCaptureView

> Status: Draft
> Created: 2026-01-25
> Workflow: compact-quick-capture

## Ziel

QuickCaptureView kompakter machen für schnellere Task-Erfassung.

## Anforderungen

| Anforderung | Details |
|-------------|---------|
| Minimales UI | Nur Textfeld + Speichern-Button |
| Tastatur sofort | Bereits implementiert (behalten) |
| Auto-Close | Bereits implementiert (behalten) |
| Abbrechen | Swipe-Down (kein Button) |
| Darstellung | Half-Sheet statt Fullscreen |

## Delta (Änderungen)

### Entfernen

- NavigationStack
- Toolbar mit Abbrechen/Speichern-Buttons
- Navigation-Titel "Quick Capture"

### Hinzufügen/Ändern

- VStack mit TextField + Button direkt
- `.presentationDetents([.medium])` für Half-Sheet
- `.presentationDragIndicator(.visible)` für Swipe-Hinweis

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/QuickCaptureView.swift` | UI vereinfachen |
| `Sources/FocusBloxApp.swift` | `.fullScreenCover` → `.sheet` |

## Implementation

### QuickCaptureView.swift (Vorher → Nachher)

**Vorher:**
```swift
NavigationStack {
    VStack { ... }
    .navigationTitle("Quick Capture")
    .toolbar {
        ToolbarItem(placement: .cancellationAction) { ... }
        ToolbarItem(placement: .confirmationAction) { ... }
    }
}
```

**Nachher:**
```swift
VStack(spacing: 16) {
    TextField("Was gibt es zu tun?", text: $taskTitle)
        .font(.title2)
        .focused($isFocused)

    Button("Speichern") {
        saveTask()
    }
    .buttonStyle(.borderedProminent)
    .disabled(taskTitle.isEmpty)
}
.padding()
.presentationDetents([.medium])
.presentationDragIndicator(.visible)
```

### FocusBloxApp.swift

**Vorher:**
```swift
.fullScreenCover(isPresented: $showQuickCapture) {
    QuickCaptureView()
}
```

**Nachher:**
```swift
.sheet(isPresented: $showQuickCapture) {
    QuickCaptureView()
}
```

## Scope

- **Dateien:** 2
- **LoC:** ~-20 (Vereinfachung)
- **Risiko:** Niedrig

## Test-Plan

### UI Test

```swift
func testQuickCaptureHalfSheetAppears() {
    // Trigger QuickCapture
    // Verify sheet appears (not fullscreen)
    // Verify TextField has focus
    // Enter text, tap save
    // Verify sheet dismisses
}
```

## Acceptance Criteria

- [ ] QuickCapture öffnet als Half-Sheet
- [ ] Nur Textfeld + Speichern-Button sichtbar
- [ ] Tastatur hat sofort Fokus
- [ ] Swipe-Down schließt ohne Speichern
- [ ] Nach Speichern schließt automatisch
