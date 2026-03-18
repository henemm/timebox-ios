# Context: FEATURE_015 — UX: Tag-Auswahl redesignen

## Request Summary
Tag-Sektion in TaskFormSheet unuebersichtlich: "Neuer Tag"-Input dominiert, bestehende Tags kommen danach. Redesign: Tags als antippbare Chips (prominent), "Neuer Tag" darunter. Vorbild: Apple Erinnerungen.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Views/TagInputView.swift` (159 LoC) | **PRIMARY TARGET** — Gesamte Tag-UI, FlowLayout, Chip-Styling |
| `Sources/Views/TaskFormSheet.swift` (568 LoC) | Integration: `glassCardSection` wrapper, Zeile 215-218 |
| `Sources/Models/LocalTask.swift` (230 LoC) | Data Model: `tags: [String]` — keine Aenderung noetig |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | `fetchAllUsedTags()` — sortiert nach Haeufigkeit |
| `Sources/Views/Components/TaskBadges.swift` | Read-only TagsBadge — Referenz fuer Chip-Style |

## Current Tag UI (Problem)

**TagInputView Layout-Reihenfolge (aktuell):**
1. Bestehende Tags als Chips (falls vorhanden)
2. "Neuer Tag" TextField + Plus-Button — **dominiert visuell**
3. Suggestions (horizontal scroll, max 5)

**Problem:** Input-Feld erscheint prominent, bestehende Tags sind sekundaer. Nutzer muss scrollen/suchen um haeufig verwendete Tags schnell zuzuweisen.

## Existing Patterns

- **FlowLayout** (TagInputView Z.116-157): Custom Layout fuer Chip-Wrapping — wiederverwendbar
- **tagChip()** (Z.78-98): `#tagname` + xmark-Button zum Entfernen
- **Chip-Styling in TaskFormSheet:** OptionalPriorityButton, TaskType-Chips mit `.ultraThinMaterial`, Capsule-Hintergrund, Selektions-Border
- **glassCardSection():** Standard-Wrapper fuer alle Sektionen
- **Accessibility:** Jedes Element hat `.accessibilityIdentifier()`

## Tag Data Architecture

- Tags = `[String]` auf `LocalTask` (SwiftData `@Model`)
- Kein separates Tag-Entity — Tags sind reine Strings
- `fetchAllUsedTags()` liefert alle jemals benutzten Tags, sortiert nach Haeufigkeit
- Suggestions gefiltert: bereits zugewiesene Tags werden ausgeblendet
- Textsuche filtert via `localizedCaseInsensitiveContains`

## Dependencies

**Upstream (was TagInputView nutzt):**
- `LocalTaskSource.fetchAllUsedTags()` — Suggestions
- `FlowLayout` — integriert in TagInputView
- `@Binding tags: [String]` — von TaskFormSheet

**Downstream (was Tags nutzt):**
- `BacklogRow` → `TagsBadge` (read-only Anzeige, max 2 + "+N")
- `TaskFormSheet` → einziger Consumer von TagInputView
- Keine Business-Logik basiert auf Tags (rein organisatorisch)

## Existing Specs

- `docs/specs/bugfixes/bug-21-tag-autocomplete.md` — Etablierte TagInputView-Pattern

## Analysis

### Type
Feature (pure UI layout reorganization)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/TagInputView.swift` | MODIFY | Reorder body sections, align chip style |
| `FocusBloxUITests/TagInputRedesignUITests.swift` | CREATE | TDD RED UI tests |

**No changes needed:**
- `TaskFormSheet.swift` — Binding interface `TagInputView(tags: $tags)` unchanged
- `TaskInspector.swift` (macOS) — Same binding, unchanged
- `LocalTask.swift` — Data model unchanged
- `LocalTaskSource.swift` — `fetchAllUsedTags()` unchanged

### Scope Assessment
- Files: 2 (1 modify, 1 create)
- Estimated LoC: ~+80 (tests) / ~15 lines touched (TagInputView reorder + style)
- Risk Level: **LOW** — pure layout reorder, no interface/logic changes

### Technical Approach

**Pure layout reorder inside TagInputView.body:**

```
VStack(alignment: .leading, spacing: 8) {
    // 1. ASSIGNED TAGS als Chips — immer oben, prominent
    //    FlowLayout wrapping, xmark zum Entfernen (wie bisher)

    // 2. SUGGESTIONS — ueber dem Input, antippbar zum Hinzufuegen
    //    (gleiche ScrollView(.horizontal), gleiche Logik)

    // 3. "NEUER TAG" Input — unten, visuell sekundaer
    //    TextField + Plus-Button (gleiche Accessibility-IDs)
}
```

**Chip-Styling vereinheitlichen:**
- `tagChip()` Background von `Color(.secondarySystemFill)` (iOS) / `Color(nsColor:)` (macOS)
  → `Color.secondary.opacity(0.15)` (cross-platform, konsistent mit TagsBadge)
- Eliminiert `#if os()` im Chip-Style

**Nicht aendern:**
- Binding interface (`tags: [String]`)
- FlowLayout struct
- Logik-Methoden (addCurrentTag, loadUsedTags)
- Accessibility Identifiers (tagInput, addTagButton, removeTag_*, tagSuggestion_*)

### Dependencies
- Keine upstream/downstream Aenderungen noetig
- FlowLayout bleibt unangetastet (auch von BacklogRow genutzt)
- Keine existierenden UI Tests referenzieren Tag-IDs → kein Regressionsrisiko

### Related Specs
- `docs/specs/bugfixes/bug-21-tag-autocomplete.md` — Baseline (TagInputView-Entstehung)
- `docs/specs/features/edit-redesign.md` — Chip-Styling Patterns
- `docs/specs/features/backlog-row-redesign.md` — Chip-Konstanten (28pt, 8pt radius)

### Risks & Considerations
- **LOW RISK:** Keine Interface-Aenderung, keine Logic-Aenderung
- **FlowLayout:** In gleicher Datei definiert — nicht anfassen
- **Cross-Platform:** Chip-Style-Vereinheitlichung eliminiert #if os() → sicherer
- **Kein Scope Creep:** "Tap to deselect" statt xmark waere Feature-Erweiterung → nicht im Scope
