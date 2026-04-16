---
entity_id: ai_live_enrichment
type: feature
created: 2026-04-16
updated: 2026-04-16
status: draft
version: "1.0"
tags: [ai, enrichment, task-creation]
issue: "#184"
---

# AI Live-Enrichment beim Task-Erstellen (#184)

## Approval

- [ ] Approved

## Purpose

Erweitert die bestehende AI-Tag-Suggestion (#235) um Live-Vorschläge für **Dauer** und **Priorität** beim Task-Erstellen. Erledigte Tasks fließen als Lernbasis ein, damit die Vorschläge mit der Nutzung besser werden.

## Scope

### In-Scope
1. Live Dauer-Vorschlag im TaskFormSheet (analog zu Tag-Chips)
2. Live Priorität-Vorschlag im TaskFormSheet
3. Erledigte Tasks in den AI-Context einbeziehen (Dauer + Tags)
4. Background-Enrichment für Tasks via Watch/Kurzbefehle (existiert bereits via `createTask()`)

### Out-of-Scope
- Neue AI-Modelle oder externe APIs
- Änderungen am Task-Datenmodell (Felder existieren bereits)
- Coach-Integration (separates Issue)

## Source

- **Service:** `Sources/Services/SmartTaskEnrichmentService.swift`
- **View:** `Sources/Views/TaskFormSheet.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SmartTaskEnrichmentService | Service | AI-Enrichment Engine |
| TaskFormSheet | View | Task-Erstellungs-Formular |
| LocalTask | Model | suggestedDuration, suggestedImportance Felder |
| TagInputView | View | Bestehende AI-Tag-Chips |

## Änderungen

### 1. SmartTaskEnrichmentService — Neuer kombinierter Live-Call

**Neue Methode:** `suggestLiveEnrichment(title:existingTags:) -> LiveEnrichmentResult`

```swift
struct LiveEnrichmentResult {
    let tags: [String]
    let durationMinutes: Int?      // 5, 15, 30, 60
    let importance: Int?           // 1, 2, 3
}
```

- **Ein** AI-Call statt drei separate (spart Token-Budget)
- Nutzt bestehendes `TaskEnrichment` @Generable struct
- System-Prompt: Kombiniert Tag-Suggestion + Duration + Importance Prompts

### 2. fetchRecentTaskContext() — Erledigte Tasks einbeziehen

**Aktuell:** Nur Kategorie, Importance, Urgency im Context-String.
**Neu:** Auch `estimatedDuration`, `tags` und erledigte Tasks einbeziehen.

```
- Steuererklärung | Kat: maintenance | Imp: 3 | Dauer: 60min | Tags: admin, wichtig
- Einkaufen gehen | Kat: maintenance | Imp: 2 | Dauer: 30min | Tags: unterwegs
```

Context-Fetch: Letzte 50 Tasks (egal ob erledigt oder offen), davon 30 mit Attributen.

### 3. TaskFormSheet — AI-Hints für Dauer und Priorität

**Bestehender Flow:** `title.onChange` → 1.5s Debounce → `suggestTagsForTitle()` → lila Chips

**Neuer Flow:** `title.onChange` → 1.5s Debounce → `suggestLiveEnrichment()` → Tags + Dauer-Hint + Priorität-Hint

**UI-Darstellung:**
- **Dauer:** Sparkle-Icon neben dem vorgeschlagenen Button (z.B. kleines lila Sparkle-Badge auf dem "30 min" Button)
- **Priorität:** Analog — Sparkle-Badge auf dem vorgeschlagenen Level
- **Tags:** Wie bisher (lila Sparkle-Chips)
- Vorschlag wird nur angezeigt wenn User noch nichts manuell gewählt hat
- Tap auf vorgeschlagenen Button = akzeptieren (normales Verhalten)

### 4. Background-Enrichment (bereits vorhanden)

`LocalTaskSource.createTask()` ruft bereits `enrichTask()` + `confirmSuggestions()` auf.
Tasks von Watch/Kurzbefehlen durchlaufen diesen Pfad automatisch — **keine Änderung nötig**.

## Expected Behavior

- **Input:** User tippt Task-Titel (min. 3 Zeichen)
- **Output:** Nach 1.5s Debounce erscheinen: Tag-Vorschläge (Chips), Dauer-Hint (Sparkle-Badge), Priorität-Hint (Sparkle-Badge)
- **User überschreibt:** Manuelle Auswahl hat immer Vorrang, Hint verschwindet
- **Kein Titel:** Keine Vorschläge
- **AI nicht verfügbar:** Keine Vorschläge, kein Fehler
- **Watch/Kurzbefehle:** Task kommt rein → `createTask()` enriched automatisch

## Affected Files (3 Dateien)

1. `Sources/Services/SmartTaskEnrichmentService.swift` — Neuer `suggestLiveEnrichment()` + Context erweitern
2. `Sources/Views/TaskFormSheet.swift` — Debounce erweitern + Dauer/Priorität-Hints anzeigen
3. `Sources/Views/TaskFormSheet.swift` — UI-Hints (Sparkle-Badges)

## Known Limitations

- AI-Vorschläge brauchen Apple Intelligence (iOS 26+)
- Erste Tasks ohne Lernbasis → Vorschläge basieren auf Seed-Tags + Few-Shot-Beispielen
- 1.5s Debounce = Vorschlag erscheint nicht sofort (bewusste Entscheidung gegen Flicker)

## Changelog

- 2026-04-16: Initial spec created
