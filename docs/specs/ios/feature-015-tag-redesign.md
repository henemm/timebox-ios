---
entity_id: feature-015-tag-redesign
type: feature
created: 2026-03-18
updated: 2026-03-18
status: draft
version: "1.0"
tags: [ux, tags, chips, ios]
---

# FEATURE_015: Tag-Auswahl redesignen

## Approval

- [ ] Approved

## Purpose

Tag-Sektion in TaskFormSheet ist unuebersichtlich: "Neuer Tag"-Input dominiert visuell, bestehende/verfuegbare Tags kommen erst danach. Redesign priorisiert Wiederverwendung bestehender Tags als antippbare Chips. Vorbild: Apple Erinnerungen.

## Source

- **File:** `Sources/Views/TagInputView.swift`
- **Identifier:** `struct TagInputView: View`
- **Consumers:** `TaskFormSheet.swift` (iOS), `TaskInspector.swift` (macOS)

## Problem (IST-Zustand)

**Aktuelle Layout-Reihenfolge in TagInputView.body:**

```
VStack {
    1. Assigned Tags als Chips (nur wenn !tags.isEmpty)
    2. "Neuer Tag" TextField + Plus-Button  ← DOMINIERT
    3. Suggestions (horizontal scroll, max 5)
}
```

**Probleme:**
- Wenn keine Tags zugewiesen: User sieht NUR das leere Input-Feld
- Haeufig verwendete Tags sind versteckt in Suggestion-Zeile ganz unten
- "Neuer Tag" suggeriert, dass man immer einen neuen Tag tippen muss
- Bestehende Tags als Wiederverwendungs-Option kommen visuell zu kurz

## Solution (SOLL-Zustand)

**Neue Layout-Reihenfolge:**

```
VStack(alignment: .leading, spacing: 8) {
    1. Suggestions als FlowLayout-Chips (antippbar zum Hinzufuegen)
       → Prominent, IMMER sichtbar wenn Suggestions vorhanden
       → FlowLayout statt horizontal ScrollView (bessere Uebersicht)
       → Tap auf Chip → Tag wird zugewiesen + Chip verschwindet

    2. Assigned Tags als Chips (mit xmark zum Entfernen)
       → Zeigt was bereits zugewiesen ist
       → Wie bisher: FlowLayout wrapping, xmark-Button

    3. "Neuer Tag" Input (TextField + Plus-Button)
       → Visuell sekundaer, am Ende
       → Fuer Tags die noch nie benutzt wurden
}
```

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Views/TagInputView.swift` | MODIFY | Layout reorder + Suggestion-Chips auf FlowLayout umstellen + Chip-Style vereinheitlichen |
| `FocusBloxUITests/TagRedesignUITests.swift` | CREATE | TDD RED UI Tests |

**Keine Aenderungen an:**
- `TaskFormSheet.swift` — Binding-Interface `TagInputView(tags: $tags)` bleibt identisch
- `TaskInspector.swift` — Gleiche Nutzung, keine Aenderung
- `LocalTask.swift` — Datenmodell unveraendert
- `LocalTaskSource.swift` — `fetchAllUsedTags()` unveraendert

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FlowLayout` | Layout | Chip-Wrapping (definiert in gleicher Datei, NICHT aendern) |
| `LocalTaskSource.fetchAllUsedTags()` | Service | Liefert Suggestions sortiert nach Haeufigkeit |
| `@Binding tags: [String]` | Interface | Von TaskFormSheet/TaskInspector — bleibt identisch |

## Implementation Details

### 1. Body Reorder

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        // 1. Suggestions als FlowLayout (NEU: statt horizontal ScrollView)
        if !suggestions.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        if !tags.contains(suggestion) {
                            tags.append(suggestion)
                            newTag = ""
                        }
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tagSuggestion_\(suggestion)")
                }
            }
        }

        // 2. Assigned Tags (wie bisher, gleiche Position relativ zu Input)
        if !tags.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    tagChip(tag)
                }
            }
        }

        // 3. Input am Ende (visuell sekundaer)
        HStack { /* ... TextField + Button, unveraendert ... */ }
    }
    .onAppear { loadUsedTags() }
}
```

### 2. Chip-Style vereinheitlichen

**Vorher (tagChip):**
```swift
#if os(iOS)
.background(Capsule().fill(Color(.secondarySystemFill)))
#else
.background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
#endif
```

**Nachher:**
```swift
.background(Capsule().fill(Color.secondary.opacity(0.15)))
```

Konsistent mit `TagsBadge` in `TaskBadges.swift` (Z.142-145). Eliminiert `#if os()` Block.

### 3. Suggestion-Chips: ScrollView → FlowLayout

**Vorher:** `ScrollView(.horizontal)` mit `HStack` — nur eine Zeile, horizontal scrollbar
**Nachher:** `FlowLayout(spacing: 6)` — Chips umbrechen auf naechste Zeile wenn noetig

Vorteil: Alle verfuegbaren Tags sind sofort sichtbar, kein Scrollen noetig.

### 4. Keine sonstigen Aenderungen

- `suggestions` computed property: unveraendert
- `tagChip()` Funktion: nur Background-Color geaendert
- `addCurrentTag()`: unveraendert
- `loadUsedTags()`: unveraendert
- `FlowLayout` struct: unveraendert
- Alle Accessibility Identifiers: unveraendert

## Expected Behavior

- **Leerer Zustand (keine Tags, keine Suggestions):** Nur Input-Feld sichtbar
- **Mit Suggestions (keine Tags zugewiesen):** Suggestion-Chips oben, Input unten
- **Mit zugewiesenen Tags:** Suggestions oben (ohne zugewiesene), Assigned-Chips darunter, Input unten
- **Tap auf Suggestion:** Tag wird zugewiesen, verschwindet aus Suggestions, erscheint in Assigned
- **Tap auf xmark:** Tag wird entfernt, erscheint wieder in Suggestions
- **Neuer Tag eingeben:** Funktioniert wie bisher via TextField + Enter/Plus

## Acceptance Criteria

1. Suggestion-Chips erscheinen VOR dem Input-Feld
2. Suggestions nutzen FlowLayout (wrapping, nicht horizontal scroll)
3. Assigned Tags erscheinen zwischen Suggestions und Input
4. Chip-Style ist konsistent (gleicher Capsule-Background auf iOS und macOS)
5. Alle bestehenden Accessibility Identifiers bleiben erhalten
6. Builds auf iOS UND macOS erfolgreich

## Test Plan

| Test | Beschreibung | Phase |
|------|-------------|-------|
| `testSuggestionsAppearAboveInput` | Suggestions sind oberhalb des Input-Felds positioniert | TDD RED |
| `testTapSuggestionAddsTag` | Tap auf Suggestion fuegt Tag hinzu | TDD RED |
| `testAssignedTagAppearsAfterAdding` | Zugewiesener Tag erscheint als Chip | TDD RED |
| `testRemoveTagViaXmark` | xmark entfernt Tag, Tag erscheint wieder in Suggestions | TDD RED |
| `testNewTagViaTextField` | Manueller Tag-Input funktioniert weiterhin | TDD RED |

## Known Limitations

- Suggestion-Limit bleibt bei 5 (wenn kein Suchtext eingegeben)
- Keine "Tap to deselect" Interaktion (xmark bleibt fuer Entfernung) — bewusst out-of-scope
- Tags bleiben `[String]` (kein separates Tag-Entity)

## Scope

- Files: 2 (1 modify, 1 create)
- Estimated LoC: ~+80 (tests) / ~20 lines touched (TagInputView)
- Risk: LOW

## Changelog

- 2026-03-18: Initial spec created
