# Context: Watch Voice Capture

## Request Summary
watchOS App mit Voice Capture: Button-Tap → Spracheingabe → Task landet im Backlog als TBD.
Alle UI-Bausteine existieren bereits, muessen nur verdrahtet und der ModelContainer konfiguriert werden.

## Vorhandener Code (Watch App)

| File | Status | Relevance |
|------|--------|-----------|
| `FocusBloxWatch Watch App/ContentView.swift` | **Placeholder** ("Hello world") | Muss komplett ersetzt werden |
| `FocusBloxWatch Watch App/FocusBloxWatchApp.swift` | **Minimal** (kein ModelContainer) | ModelContainer + CloudKit Setup fehlt |
| `FocusBloxWatch Watch App/VoiceInputSheet.swift` | **Fertig** | TextField mit Auto-Focus fuer Dictation, OK/Abbrechen |
| `FocusBloxWatch Watch App/ConfirmationView.swift` | **Fertig** | Checkmark + Haptic + Auto-Dismiss nach 2s |
| `FocusBloxWatch Watch App/WatchLocalTask.swift` | **Veraltet** | Fehlen: aiScore, aiEnergyLevel, assignedFocusBlockID, completedAt, rescheduleCount |
| `FocusBloxWatch Watch App.entitlements` | **Leer** | App Group Array ist LEER — muss `group.com.henning.focusblox` enthalten |

## Bestehende Spec
- `docs/specs/features/watch-voice-capture.md` — vollstaendige Spec (Draft, 2026-01-31)
- Enthalt Architektur, UI-Design, Code-Beispiele, Akzeptanzkriterien

## Kritische Probleme

### 1. WatchLocalTask ist out-of-sync mit iOS LocalTask
Watch-Version fehlen 5 Felder die iOS hat:
- `assignedFocusBlockID: String?`
- `rescheduleCount: Int` (default 0)
- `completedAt: Date?`
- `aiScore: Int?`
- `aiEnergyLevel: String?`

Ausserdem: `recurrenceWeekdays` ist `[Int]` auf Watch vs `[Int]?` auf iOS — Typ-Mismatch!

**Risiko:** Wenn Watch und iOS unterschiedliche SwiftData-Schemas verwenden, koennte CloudKit-Sync fehlschlagen oder Daten verlieren.

### 2. Entitlements leer
App Group Array in Entitlements ist leer — ohne `group.com.henning.focusblox` kann die Watch nicht auf den geteilten Container zugreifen.

### 3. Kein ModelContainer
FocusBloxWatchApp hat keinen ModelContainer — ohne ihn keine SwiftData-Persistenz.

## Bestehende Patterns

### iOS ModelContainer Setup (FocusBloxApp.swift)
```
Schema: [LocalTask.self, TaskMetadata.self]
App Group: group.com.henning.focusblox
CloudKit: .private("iCloud.com.henning.focusblox")
```

### macOS ModelContainer Setup (FocusBloxMacApp.swift)
Identisch mit iOS — gleiches Schema, gleiche App Group, gleicher CloudKit-Container.

### FocusBloxCore Framework
Existiert, enthaelt aber nur LiveActivity-Attributes. NICHT der richtige Ort fuer SharedModelContainer (watchOS braucht kein LiveActivity).

## Dependencies
- **Upstream:** SwiftData, CloudKit, App Group Entitlement
- **Downstream:** iOS Backlog (sieht Watch-Tasks via CloudKit Sync)

## Zu aendernde Dateien (geschaetzt)
1. `WatchLocalTask.swift` — Felder synchronisieren mit iOS LocalTask
2. `FocusBloxWatchApp.swift` — ModelContainer + CloudKit Setup
3. `ContentView.swift` — Placeholder ersetzen mit Task-Capture UI
4. `FocusBloxWatch Watch App.entitlements` — App Group hinzufuegen

## Risiken
- watchOS Simulator unterstuetzt keine Dictation — nur manuelles Tippen testbar
- CloudKit-Sync zwischen Watch und iPhone benoetigt echtes Device-Paar zum Verifizieren
- Schema-Migration wenn WatchLocalTask Felder hinzukommen

---
*Context aktualisiert: 2026-02-17*
