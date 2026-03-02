---
entity_id: ctc_2_source_url
type: feature
created: 2026-03-02
updated: 2026-03-02
status: draft
version: "1.0"
tags: [share-extension, task-creation, cross-platform]
---

# CTC-2: sourceURL fuer Share Extension

## Approval

- [ ] Approved

## Purpose

Neues Property `sourceURL: String?` auf LocalTask, damit die Share Extension die Quell-URL (z.B. Safari-Link) beim Task-Erstellen mitspeichert. Ermoeglicht spaetere UI-Features (klickbarer Link zum Kontext).

## User Story

`docs/project/stories/contextual-task-capture.md`

## Source

- **File:** `Sources/Models/LocalTask.swift` (Model-Erweiterung)
- **File:** `FocusBloxShareExtension/ShareViewController.swift` (URL-Extraktion)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask` | Model | Neues `sourceURL` Property |
| `SwiftData` | Framework | Persistenz + CloudKit Sync |
| `UTType` | Framework | Content-Type Erkennung |
| `NSItemProvider` | Framework | URL-Extraktion aus Share-Kontext |

## Implementation Details

### 1. Neues Property auf LocalTask

```swift
/// Source URL from Share Extension (e.g. Safari link)
/// nil for tasks created in-app or from plain text shares
var sourceURL: String?
```

- `String?` (nicht `URL?`) — konsistent mit `externalID`, `sourceSystem`, CloudKit-kompatibel
- Default `nil` — lightweight SwiftData Migration, keine bestehenden Tasks betroffen
- Platzierung: nach `sourceSystem` (Zeile ~119)

### 2. ShareViewController URL-Speicherung

In `extractSharedContent()` wird die URL bereits extrahiert (UTType.url).
Aenderung: URL als State-Variable merken und beim Speichern in `task.sourceURL` schreiben.

```swift
// Neue State-Variable
@State private var sourceURL: String?

// In extractSharedContent(), bei URL-Erkennung:
self.sourceURL = url.absoluteString

// In saveTask():
let task = LocalTask(title: trimmedTitle)
task.needsTitleImprovement = true
task.sourceURL = sourceURL  // NEU
context.insert(task)
try context.save()
```

### 3. Kein UI-Display (Scope CTC-2)

`sourceURL` wird nur persistiert. Anzeige in EditTaskSheet/TaskDetailSheet ist ein separates Feature.

## Expected Behavior

### Input -> Output

| Share-Quelle | taskTitle | sourceURL |
|-------------|-----------|-----------|
| Safari (Webseite) | Seitentitel oder URL | `"https://example.com/page"` |
| Safari (Link teilen) | Link-Text oder URL | `"https://example.com/link"` |
| Mail (E-Mail teilen) | Subject-Text | `nil` (Mail liefert keine URL) |
| Notes (Text teilen) | Geteilter Text | `nil` |

### Verhalten bei bestehenden Tasks

- `sourceURL` ist `nil` fuer alle bestehenden Tasks
- Keine Migration noetig (SwiftData lightweight)
- CloudKit synct das neue Feld automatisch

## Side Effects

- `task.sourceURL` wird gesetzt (nur bei URL-Shares)
- Keine Aenderung am bestehenden Verhalten (Title-Extraktion, needsTitleImprovement)
- Kein Impact auf andere Services (TaskTitleEngine, SmartTaskEnrichmentService, RecurrenceService, SyncEngine)

## Known Limitations

1. **iOS Mail.app:** Stellt KEINE `message://` URLs bereit — Deep-Link zu E-Mails nicht moeglich (Apple-Limitierung)
2. **Kein UI-Display:** sourceURL wird gespeichert aber nicht angezeigt (spaeteres Feature)
3. **Keine Quell-Erkennung:** Keine Unterscheidung ob Share von Mail, Notes oder anderem Text kommt

## Test Plan

### Unit Tests (SourceURLTests.swift)

| Test | Beschreibung |
|------|-------------|
| `test_sourceURL_defaultIsNil` | Neues Property hat Default nil |
| `test_sourceURL_persistsInSwiftData` | sourceURL wird korrekt gespeichert und geladen |
| `test_sourceURL_preservedAfterTitleImprovement` | TaskTitleEngine ueberschreibt sourceURL NICHT |

### UI Tests

UI Tests entfallen — kein neues UI-Element (sourceURL wird nicht angezeigt). Die Share Extension selbst ist in XCUITests nicht testbar (OS-Level Sheet). Verhalten wird durch Unit Tests abgedeckt.

## Affected Files

| File | Change Type | LoC |
|------|-------------|-----|
| `Sources/Models/LocalTask.swift` | MODIFY | +3 |
| `FocusBloxShareExtension/ShareViewController.swift` | MODIFY | +10 |
| `FocusBloxTests/SourceURLTests.swift` | CREATE | ~40 |

**Total:** 3 Dateien, ~53 LoC

## Changelog

- 2026-03-02: Initial spec created
