---
entity_id: bug-319-intake-analyser
type: bugfix
created: 2026-05-29
updated: 2026-05-29
status: draft
version: "1.0"
tags: [enrichment, tags, lowercase, migration]
---

# Bug #319 — Intake Analyser: Tags & Dauer werden nicht übernommen

## Approval

- [ ] Approved

## Purpose

Die KI-Analyse (Intake Analyser) befüllt interne Staging-Felder (`suggestedTags`, `suggestedDuration`) korrekt, aber diese Werte landen nie in den eigentlichen Task-Feldern (`tags`, `estimatedDuration`). Zusätzlich werden manuell eingetippte Tags nicht auf Kleinschreibung normalisiert, was zu Duplikaten führt (z.B. "Arbeit" und "arbeit" als separate Tags). Dieser Fix schließt alle vier Lücken zwischen KI-Vorschlag und Task-Zustand.

## Source

Betroffen sind vier bestehende Dateien und eine Migration beim App-Start:

- **File:** `Sources/Models/LocalTask.swift`
- **Identifier:** `func confirmSuggestions()`

- **File:** `Sources/Services/SmartTaskEnrichmentService.swift`
- **Identifier:** `func performEnrichment()`

- **File:** `Sources/Views/TagInputView.swift`
- **Identifier:** `func addCurrentTag()`

- **File:** `Sources/Services/TaskSources/LocalTaskSource.swift`
- **Identifier:** `func createTask()`, `func updateTask()`

- **File:** `Sources/FocusBloxApp.swift`
- **Identifier:** Migration beim App-Start (analog zu `migrateLegacyTasksWithoutGroupID`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LocalTask.confirmSuggestions()` | model method | Überträgt Staging-Felder auf Hauptfelder; wird um Tags-Promotion erweitert |
| `SmartTaskEnrichmentService.performEnrichment()` | service method | Batch-Pfad; muss `confirmSuggestions()` nach Enrichment aufrufen |
| `TagInputView.addCurrentTag()` | view method | Normalisiert manuell eingetippte Tags auf Kleinschreibung |
| `LocalTaskSource.createTask()` / `updateTask()` | data layer | Normalisiert Tags vor dem Speichern als letzte Sicherheitsschicht |
| `FocusBloxApp` (App-Start) | app entry point | Einmalige Migration: bestehende Tags auf Kleinschreibung normalisieren |
| `UserDefaults` | storage | Flag `"tagLowercaseMigrationDone"` verhindert mehrfaches Ausführen der Migration |

## Implementation Details

### Fix 1 — Tags-Promotion in `confirmSuggestions()`

`confirmSuggestions()` transferiert bereits `suggestedDuration`, `suggestedCategory` und weitere Felder auf ihre Hauptfelder. Der Transfer `suggestedTags → tags` fehlt.

Bedingung: Tags werden nur übernommen wenn `tags` aktuell leer ist und `suggestedTags` vorhanden und nicht leer ist. Tags werden dabei auf Kleinschreibung normalisiert.

### Fix 2 — Batch-Enrichment ruft `confirmSuggestions()` auf

Im Batch-Pfad (`enrichAllTbdTasks → performEnrichment`) wird nach dem Setzen von `suggestedDuration` und `suggestedTags` kein `confirmSuggestions()` aufgerufen. Die Staging-Felder bleiben permanent im Staging-Zustand.

`confirmSuggestions()` setzt `lifecycleStatus = .active` — bei Tasks die bereits aktiv sind ist das idempotent und ohne Seiteneffekte.

### Fix 3 — Lowercase-Normalisierung an Schreibpfaden

Manuell eingetippte Tags durchlaufen keine Normalisierung. Die AI-Vorschlagslogik normalisiert bereits, aber die manuellen Schreibpfade nicht.

Drei Stellen werden angepasst:
- `TagInputView.addCurrentTag()` — beim Hinzufügen aus der View
- `LocalTaskSource.createTask()` — beim initialen Speichern
- `LocalTaskSource.updateTask()` — beim Aktualisieren

Das Tags-Array wird jeweils durch `.map { $0.lowercased() }` normalisiert.

### Fix 4 — Einmalige Migration bestehender Tags

Beim App-Start werden alle gespeicherten `LocalTask`-Objekte mit nicht-leerem Tags-Array einmalig auf Kleinschreibung normalisiert. Pattern ist analog zu `migrateLegacyTasksWithoutGroupID`.

Das Flag `"tagLowercaseMigrationDone"` in `UserDefaults` stellt sicher, dass die Migration nur einmal läuft.

## Expected Behavior

### Acceptance Criteria

1. **Neuer Task mit KI-Analyse:** Task mit aussagekräftigem Titel anlegen → nach KI-Analyse sind `tags` UND `estimatedDuration` gesetzt (nicht nur die Staging-Felder `suggestedTags`/`suggestedDuration`).

2. **Manuelle Tag-Eingabe:** Tag mit Großbuchstaben eintippen (z.B. "Arbeit") → wird als "arbeit" gespeichert.

3. **Batch-Analyse:** "Alle Tasks analysieren" ausführen → danach haben Tasks `tags` und `estimatedDuration` gesetzt, nicht nur Staging-Felder.

4. **Bestehende Tags nach App-Start:** Alle vorhandenen Tags sind nach dem ersten Start lowercase; Duplikate die nur durch Groß-/Kleinschreibung entstanden sind, treten nicht mehr auf.

### Nicht geändert

- `suggestedTags` und `suggestedDuration` bleiben weiterhin als Staging-Felder erhalten (für zukünftige Nutzung, z.B. Review-UI)
- Das Verhalten von `confirmSuggestions()` für alle anderen Felder bleibt unverändert
- Tags aus der KI-Analyse (`filterTagSuggestions()`) sind bereits normalisiert — kein Fix nötig

## Out of Scope

- Quick Capture Enrichment (kein `SmartTaskEnrichmentService`-Aufruf in `QuickCaptureView`) — eigenes Ticket
- `fetchRecentTaskContext` Limit-Optimierung — kein Bugfix, ausbaubar aber nicht dringend

## Known Limitations

- Die Tag-Migration beim App-Start normalisiert keine Duplikate die durch Groß-/Kleinschreibung entstanden sind (z.B. "Arbeit" und "arbeit" existieren beide) — die Normalisierung entfernt keine Duplikate, schreibt aber alle Tags lowercase. Duplikate durch zukünftige Eingaben werden durch Fix 3 verhindert.

## Changelog

- 2026-05-29: Initial spec created
