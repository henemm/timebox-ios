# Learnings & Gotchas

Gesammelte Erkenntnisse aus der Entwicklung.

## SwiftUI UI Testing

- `Picker` Labels sind NICHT als `StaticText` zugänglich in XCTest
- Teste Picker-Existenz (`app.buttons["pickerName"]`), nicht einzelne Optionen
- Für Picker-Optionen: Teste indirekt über Ergebnis (z.B. Task erstellen, prüfen ob gespeichert)

## Workflow State

- `.claude/workflow_state.json` wird von ALLEN Claude-Sessions geteilt
- **NIEMALS** fremde Workflows ändern - nur den eigenen aktiven Workflow
- Bei Unsicherheit: Workflow State in Ruhe lassen, nur Roadmap aktualisieren

---

Erstellt: 2026-01-23
