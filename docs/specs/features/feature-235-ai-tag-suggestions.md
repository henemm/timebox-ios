---
entity_id: feature-235-ai-tag-suggestions
type: feature
created: 2026-04-15
updated: 2026-04-15
status: draft
version: "1.0"
tags: [ai, tags, enrichment, task-creation]
---

# Feature #235: AI schlägt Tags vor beim Task-Erstellen

## Approval

- [ ] Approved

## Purpose

Beim Erstellen eines Tasks schlägt die KI basierend auf dem Titel passende Tags vor. Der User tippt z.B. "Rasen mähen" und bekommt "#garten" als antippbaren Chip vorgeschlagen. Tags werden bevorzugt aus bestehenden User-Tags gewählt, max 1 neuer Tag erlaubt.

## Source

- **Files:**
  - `Sources/Services/SmartTaskEnrichmentService.swift` — neue Methode `suggestTagsForTitle()`
  - `Sources/Views/TagInputView.swift` — AI-Suggestions-Bereich
  - `Sources/Views/TaskFormSheet.swift` — debounced Aufruf
- **Issue:** GitHub #235

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SmartTaskEnrichmentService | Service | AI-Enrichment Infrastruktur |
| TagInputView | View | Bestehende Tag-Chip-UI |
| TaskFormSheet | View | Task-Erstellen-Formular |
| LocalTaskSource.fetchAllUsedTags() | Query | Bestehende User-Tags laden |
| FoundationModels (@Generable) | Framework | Apple Intelligence API |

## Implementation Details

### Zwei Wege — ein Mechanismus

Tag-Vorschläge entstehen auf **zwei Wegen**, nutzen aber denselben AI-Mechanismus:

| Weg | Wann | Wo sichtbar |
|-----|------|-------------|
| **Live im Formular** | User tippt Titel beim Erstellen | Sofort als Chips in TagInputView |
| **Hintergrund-Enrichment** | SmartTaskEnrichmentService verarbeitet Task | `suggestedTags` auf LocalTask gespeichert, in TagInputView beim Editieren sichtbar |

### 1. LocalTask erweitern (LocalTask.swift)

Neues Feld neben den bestehenden AI-Suggestion-Feldern:

```swift
/// AI-suggested tags (max 3), stored until user accepts/dismisses
var suggestedTags: [String]?
```

### 2. TaskEnrichment erweitern (SmartTaskEnrichmentService.swift:54-73)

```swift
@Generable
struct TaskEnrichment {
    // ... bestehende Felder ...
    
    @Guide(description: "Up to 3 suggested tags for this task. Prefer tags the user already uses. At most 1 completely new tag. Empty array if no good match.")
    let suggestedTags: [String]
}
```

### 3. performEnrichment() erweitern (SmartTaskEnrichmentService.swift:304-373)

Nach den bestehenden Feld-Zuweisungen:

```swift
// Tags: nur vorschlagen wenn User keine manuellen Tags gesetzt hat
if (task.tags ?? []).isEmpty, !result.suggestedTags.isEmpty {
    task.suggestedTags = Array(result.suggestedTags.prefix(3))
}
```

### 4. Prompt erweitern (SmartTaskEnrichmentService.swift:311-337)

Bestehende User-Tags als Kontext in den System-Prompt aufnehmen:

```
"Tag-Vorschläge:"
"  Bevorzuge Tags die der Nutzer bereits verwendet: [userTags]"
"  Maximal 1 komplett neuer Tag erlaubt"
"  Falls keine Tags passen: leeres Array"
```

Seed-Tags für neue User (wenn fetchAllUsedTags() leer):
```swift
static let seedTags = ["computer", "telefon", "unterwegs", "zuhause", "einkauf"]
```

### 5. Neue Methode: suggestTagsForTitle() (SmartTaskEnrichmentService.swift)

Leichtgewichtige Live-Methode für das Formular (ohne volles Enrichment):

```swift
func suggestTagsForTitle(_ title: String, existingTags: [String]) async -> [String]
```

- Eigene LanguageModelSession nur für Tags
- Seed-Tags als Fallback wenn existingTags leer
- Fehler → leeres Array

### 6. TagInputView erweitern (TagInputView.swift)

```swift
struct TagInputView: View {
    @Binding var tags: [String]
    var aiSuggestions: [String] = []  // NEU — von Live ODER aus task.suggestedTags
```

- AI-Suggestions als separate Chip-Reihe mit Sparkle-Icon
- Tap → Tag zu `tags` hinzufügen, Suggestion verschwindet
- Bereits zugewiesene Tags nicht als Suggestion zeigen

### 7. TaskFormSheet-Integration (TaskFormSheet.swift)

**CREATE-Modus:** Debounced Live-Aufruf von `suggestTagsForTitle()` bei Titeländerung (1.5s Pause)

**EDIT-Modus:** `task.suggestedTags` an TagInputView weitergeben (aus Hintergrund-Enrichment)

## Expected Behavior

### Weg 1: Live im Formular (CREATE)
- **Input:** User tippt Task-Titel
- **Output:** 0-3 Tag-Chips erscheinen nach ~1.5s Pause
- **Interaktion:** Tap setzt Tag, nochmal Tap entfernt ihn

### Weg 2: Hintergrund-Enrichment (automatisch)
- **Input:** Task wird von SmartTaskEnrichmentService verarbeitet
- **Output:** `suggestedTags` auf LocalTask gespeichert
- **Sichtbar:** Beim späteren Editieren des Tasks in TagInputView
- **Side effects:** `suggestedTags` wird persistiert (wie andere AI-Suggestions)

### Akzeptanzkriterien

1. Bei Titel "Rasen mähen" erscheinen kontextrelevante Tags (z.B. #zuhause oder #garten)
2. Bestehende User-Tags werden bevorzugt vorgeschlagen
3. Maximal 3 Vorschläge, maximal 1 neuer Tag
4. Neue User (keine Tags) bekommen Vorschläge aus Seed-Set
5. Vorschläge erscheinen nach Tipp-Pause, kein Flackern (Live-Modus)
6. Hintergrund-Enrichment schreibt suggestedTags auf Tasks ohne manuelle Tags
7. Vorschläge sind ignorierbar — kein Zwang
8. Tap auf Vorschlag fügt Tag hinzu
9. Funktioniert auf iOS + macOS (shared View)
10. Edit-Modus zeigt suggestedTags aus Hintergrund-Enrichment

## Known Limitations

- Abhängig von Apple Intelligence (iOS 26.0+ / macOS 26.0+)
- Live-Vorschläge nur im Create-Modus; Edit-Modus zeigt gespeicherte Hintergrund-Vorschläge
- AI-Qualität hängt von Titel-Länge/Klarheit ab
- Kein Offline-Fallback (leeres Array bei Fehler)

## Affected Files

| Datei | Änderung |
|-------|----------|
| `Sources/Models/LocalTask.swift` | `suggestedTags: [String]?` Feld |
| `Sources/Services/SmartTaskEnrichmentService.swift` | TaskEnrichment + Prompt + suggestTagsForTitle() + performEnrichment() |
| `Sources/Views/TagInputView.swift` | aiSuggestions Parameter + UI |
| `Sources/Views/TaskFormSheet.swift` | Live-Aufruf (Create) + suggestedTags-Weitergabe (Edit) |
| `Tests/...` (Unit + UI) | Tests für alle Dateien |

## Changelog

- 2026-04-15: Initial spec created
