# Context: CTC-2 Share Extension E-Mail-Support + Deep-Link

## Request Summary
Share Extension erweitern, sodass E-Mails (Subject als Task-Titel) erfasst werden koennen. Wunsch: Deep-Link zurueck zur E-Mail. Ausserdem: sourceURL fuer alle Share-Quellen persistieren.

## Critical Finding: iOS Mail Deep-Link Limitation

**iOS Mail.app stellt ueber Share Extensions KEINE `message://` URLs bereit.**
- NSItemProvider liefert nur: Plain Text (Subject/Body-Auszug) und ggf. URL (bei Links)
- Kein Message-ID, kein RFC 822 Header, kein Deep-Link
- Das ist eine **Apple-Plattform-Limitierung**, kein Code-Problem
- macOS koennte theoretisch per AppleScript `message://` URLs extrahieren — aber nicht ueber Share Extensions

**Konsequenz:** Deep-Link zurueck zur E-Mail ist auf iOS **nicht moeglich**. Der Task erhaelt den Subject-Text als Titel, aber keinen Link.

## Current Share Extension Implementation

| Aspekt | Status |
|--------|--------|
| UTType.url | Supported (Safari, Links) |
| UTType.plainText | Supported (Mail Subject, Notes) |
| SwiftUI UI | ShareSheetView mit TextField + Speichern/Abbrechen |
| Persistenz | SwiftData via App Group + CloudKit |
| needsTitleImprovement | Bereits gesetzt (CTC-1) |
| Info.plist | NSExtensionActivationSupportsText=true, WebURL maxCount=1 |

## Related Files

| File | Relevance |
|------|-----------|
| `FocusBloxShareExtension/ShareViewController.swift` | Share Extension — muss URL-Speicherung erhalten |
| `Sources/Models/LocalTask.swift` | Neues `sourceURL` Property noetig |
| `FocusBloxShareExtension/Info.plist` | Activation Rules ggf. erweitern |
| `Sources/Services/TaskTitleEngine.swift` | Nutzt bereits needsTitleImprovement (CTC-1) |
| `Sources/Views/EditTaskSheet.swift` | Koennte sourceURL anzeigen (optional, Scope?) |

## Existing Patterns

- CTC-1 TaskTitleEngine: needsTitleImprovement-Flag Pattern auf LocalTask
- SmartTaskEnrichmentService: Batch-Processing bei App-Start
- Share Extension nutzt eigenen ModelContainer (kein Zugriff auf Main App)

## Model-Analyse: LocalTask Fields

Bestehende relevante Fields:
- `taskDescription: String?` — bereits fuer Original-Titel genutzt (CTC-1)
- `externalID: String?` — fuer Sync mit externen Systemen (Notion)
- `sourceSystem: String = "local"` — Quell-System Identifier

**Fehlt:** Kein Field fuer Source-URL (Webseite, E-Mail-Link). Empfehlung: `sourceURL: String?`

## Dependencies

- **Upstream:** UTType, NSItemProvider, NSExtensionItem, SwiftData, CloudKit
- **Downstream:** TaskTitleEngine (verbessert Titel), BacklogView/EditTaskSheet (zeigt Task an)

## Existing Specs

- `docs/specs/services/task-title-engine.md` — CTC-1, status: implemented

## Risks & Considerations

1. **Deep-Link auf iOS nicht moeglich** — Henning muss entscheiden ob das akzeptabel ist
2. **Scope-Frage:** Soll `sourceURL` in der UI (EditTaskSheet) angezeigt werden? Oder nur persistiert?
3. **E-Mail-Erkennung:** Wie unterscheiden wir "kommt aus Mail" von "kommt aus Notes/Safari"?
4. **macOS Share Extension:** Ist CTC-3, aber gleiche Architektur — Aenderungen an LocalTask betreffen beide
5. **Schema-Migration:** Neues `sourceURL` Property ist lightweight (String? mit Default nil)

## Analysis

### Type
Feature

### Ist-Zustand
E-Mail-Subjects werden BEREITS als Task-Titel erfasst (UTType.plainText).
TaskTitleEngine (CTC-1) bereinigt bereits Re:, Fwd:, AW: Artefakte.
Was FEHLT: sourceURL fuer Safari-Links persistieren.

### Affected Files (with changes)

| File | Change Type | Description | LoC |
|------|-------------|-------------|-----|
| `Sources/Models/LocalTask.swift` | MODIFY | Add `sourceURL: String?` Property | +3 |
| `FocusBloxShareExtension/ShareViewController.swift` | MODIFY | URL extrahieren + als sourceURL speichern | +10 |
| `FocusBloxTests/SourceURLTests.swift` | CREATE | Unit Tests fuer sourceURL | ~30 |

### Scope Assessment
- Files: 3 (2 MODIFY, 1 CREATE)
- Estimated LoC: +43
- Risk Level: LOW

### Technical Approach
1. `sourceURL: String?` auf LocalTask (nil Default, CloudKit-kompatibel, lightweight migration)
2. ShareViewController: Bei UTType.url den URL-String in `sourceURL` speichern
3. Kein UI-Display (nur Persistenz) — UI kann spaeter kommen
4. `String?` statt `URL?` — konsistent mit bestehendem Pattern (externalID, sourceSystem)

### Dependencies (keine Aenderungen noetig)
- TaskTitleEngine: Beruehrt sourceURL NICHT (nur title + taskDescription)
- SmartTaskEnrichmentService: Beruehrt sourceURL NICHT
- SyncEngine: Beruehrt sourceURL NICHT
- RecurrenceService: Child-Instanzen erben sourceURL NICHT (korrekt)
- LocalTaskSource.createTask(): Wird von Share Extension NICHT genutzt (direkter Insert)

### Open Questions (an Henning)
- [x] Deep-Link zu E-Mails auf iOS nicht moeglich — akzeptabel?
- [ ] sourceURL spaeter in UI anzeigen? (nicht im Scope CTC-2)
