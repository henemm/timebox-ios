---
entity_id: backlog-013-mac-text-truncation
type: bugfix
created: 2026-03-09
updated: 2026-03-09
status: draft
version: "1.0"
tags: [macOS, layout, text-truncation, blast-radius]
---

# BACKLOG-013: macOS Text-Truncation in weiteren Views

## Approval

- [ ] Approved

## Purpose

Bug 86 Fix (`.frame(maxWidth: .infinity, alignment: .leading)`) auf 9 weitere macOS Stellen uebertragen, die dasselbe Truncation-Pattern haben. Task-Titel werden unnoetig mit "..." abgeschnitten, obwohl Platz vorhanden ist.

## Source

- **Referenz-Fix:** `FocusBloxMac/MacBacklogRow.swift` (Bug 86, bereits gefixt)
- **Pattern:** VStack/Text in HStack mit Spacer() ohne explizite Breitenangabe

## Affected Files

| File | Stelle | Fix |
|------|--------|-----|
| FocusBloxMac/MacPlanningView.swift | NextUpTaskRow VStack | `.frame(maxWidth: .infinity, alignment: .leading)` auf VStack |
| FocusBloxMac/MacAssignView.swift | MacTaskInBlockRow Text | `.frame(maxWidth: .infinity, alignment: .leading)` auf Text |
| FocusBloxMac/MacAssignView.swift | MacDraggableTaskRow VStack | `.frame(maxWidth: .infinity, alignment: .leading)` auf VStack |
| FocusBloxMac/MacFocusView.swift | TaskQueueRow Text | `.frame(maxWidth: .infinity, alignment: .leading)` auf Text |
| FocusBloxMac/MacFocusView.swift | MacReviewTaskRow VStack | `.frame(maxWidth: .infinity, alignment: .leading)` auf VStack |
| FocusBloxMac/MenuBarView.swift | activeFocusSection Block-Titel | `.frame(maxWidth: .infinity, alignment: .leading)` auf Text |
| FocusBloxMac/MenuBarView.swift | currentTaskRow Task-Titel | `.frame(maxWidth: .infinity, alignment: .leading)` auf Text |
| FocusBloxMac/MenuBarView.swift | MenuBarTaskRow Text | `.frame(maxWidth: .infinity, alignment: .leading)` auf Text |
| FocusBloxMac/MacTimelineView.swift | FocusBlockView Header | `.frame(maxWidth: .infinity, alignment: .leading)` auf Text |

## Implementation Details

Zwei Varianten je nach vorhandenem Layout:

**Variante A — VStack vorhanden (3 Stellen):**
```swift
VStack(alignment: .leading, spacing: 2) {
    Text(task.title)
        .lineLimit(1)
    // metadata...
}
.frame(maxWidth: .infinity, alignment: .leading)  // <-- hinzufuegen
```

**Variante B — Text direkt in HStack (6 Stellen):**
```swift
Text(task.title)
    .lineLimit(1)
    .frame(maxWidth: .infinity, alignment: .leading)  // <-- hinzufuegen
```

## Expected Behavior

- **Vorher:** Task-Titel werden mit "..." abgeschnitten obwohl Platz vorhanden
- **Nachher:** Titel nutzen verfuegbare Breite, truncation nur bei echtem Platzmangel
- **Side effects:** Keine — reine Layout-Korrektur

## Scope

- **Dateien:** 5
- **LoC:** ~9 (je 1 Modifier-Zeile pro Stelle)
- **Risk:** LOW

## Test Plan

- macOS UI Tests: Pruefen dass Titel-Text sichtbar und nicht unnoetig truncated
- Bestehende macOS UI Tests muessen weiterhin gruen sein

## Known Limitations

- MenuBarView hat systembedingt begrenzte Breite — Truncation bei sehr langen Titeln ist dort normal und korrekt

## Changelog

- 2026-03-09: Initial spec created
