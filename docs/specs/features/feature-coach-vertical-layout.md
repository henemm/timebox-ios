---
entity_id: feature-coach-vertical-layout
type: feature
created: 2026-03-16
updated: 2026-03-16
status: approved
version: "1.0"
tags: [coach, ui, morning-intention, ai-pitch]
---

# Coach-Auswahl: Vertikales Layout + ausführliche AI-Pitches

## Approval

- [x] Approved (2026-03-16)

## Purpose

Die Coach-Auswahl in MorningIntentionView zeigt 4 Coach-Karten als vertikale Liste mit horizontalen Karten (Monster links, Text rechts) statt des bisherigen 2x2-Grids. AI-Pitches werden von 120 auf 300 Zeichen verlängert mit 5 statt 3 Task-Referenzen für überzeugendere Texte.

## Source

- **File:** `Sources/Views/MorningIntentionView.swift`
- **Identifier:** `MorningIntentionView.coachCard(for:)`, `selectionView`
- **File:** `Sources/Services/CoachPitchService.swift`
- **Identifier:** `CoachPitchService.buildPrompt()`, `PitchText`, `performGeneration()`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| CoachType | Model | displayName, subtitle, shortPitch, monsterImage, color |
| CoachMissionService | Service | generatePreview(), recommendedCoach() — unverändert |
| CoachMissionCard | View | Referenz-Layout (HStack, 56×56 Monster) |
| CoachMeinTagView | View | Embeddet MorningIntentionView (iOS) |
| MacCoachReviewView | View | Embeddet MorningIntentionView (macOS) |

## Implementation Details

### 1. MorningIntentionView — Layout-Umbau

**Entfernen:**
- `columns` Property (GridItem-Array)
- `LazyVGrid(columns:spacing:)` Container
- Große Monster-Vorschau (120px Image oben)
- Vertikales Karten-Layout (VStack mit ZStack-Badge)

**Neues Layout pro Coach-Karte:**
```
┌──────────────────────────────────────────────────┐
│ [Monster]  Troll — Der Aufräumer    [Empfohlen]  │
│  56×56     Aufgeschobenes endlich anpacken        │
│                                                   │
│            "Du hast 3 Tasks seit Wochen vor       │
│            dir hergeschoben..."                    │
└──────────────────────────────────────────────────┘
```

- `VStack(spacing: 12)` statt `LazyVGrid` — 4 Karten untereinander
- Pro Karte: `HStack(alignment: .top, spacing: 12)` — Monster links, Text rechts
- Monster: 56×56 Circle (wie CoachMissionCard)
- Rechte Spalte `VStack(alignment: .leading, spacing: 4)`:
  - Zeile 1: `HStack` mit `"\(displayName) — \(subtitle)"` (`.subheadline.weight(.semibold)`) + Empfohlen-Capsule
  - Zeile 2: `shortPitch` (`.caption`, `.secondary`) — immer sichtbar
  - Zeile 3: AI-Pitch oder Preview-Teaser (`.callout`) — **kein lineLimit**, voller Text
- Selected-State: `coach.color.opacity(0.15)` Background + farbiger Stroke (wie bisher)
- Empfohlen-Badge: `"Empfohlen"` als Capsule mit `coach.color.opacity(0.2)` Background

**AccessibilityIDs bleiben identisch:**
- `coachSelectionCard_\(coach.rawValue)`
- `recommendedBadge_\(coach.rawValue)`
- `setIntentionButton`, `noCoachButton`, `morningIntentionCard`

### 2. CoachPitchService — Ausführlichere Pitches

| Parameter | Aktuell | Neu |
|-----------|---------|-----|
| @Guide description | "1-2 kurze Sätze, Max 120 Zeichen" | "3-4 Sätze, Max 300 Zeichen" |
| System-Prompt | "1-2 kurze Sätze als Pitch" | "3-4 Sätze, ausführlich" |
| prefix() Output-Guardrail | 150 | 400 |
| Tasks im Prompt | `prefix(3)` | `prefix(5)` |
| Prompt-Auftrag | "Überzeuge in 1-2 Sätzen" | "Erkläre ausführlich warum...nenne konkrete Tasks" |

### 3. CoachPitchServiceTests — max3 → max5

- Testname: `test_buildPrompt_containsTaskTitles_max5`
- 6 Tasks erstellen, prüfen dass 5 im Prompt sind, 6. nicht

## Expected Behavior

- **Input:** 4 CoachTypes + allTasks (PlanItems)
- **Output:** Vertikale Liste mit 4 horizontalen Coach-Karten, scrollbar
- **AI-Flow:** shortPitch sofort sichtbar → AI-Pitch ersetzt teaser mit Animation
- **Side effects:** Keine — rein visuelle Änderung + AI-Prompt-Parameter

## Test Plan

### Unit Tests (angepasst)
1. `test_buildPrompt_containsTaskTitles_max5` — 6 Tasks rein, 5 im Prompt, 6. nicht (RED→GREEN)

### Bestehende Tests (müssen weiterhin grün sein)
2. `test_buildPrompt_containsCoachNameAndPersonality` — unverändert
3. `test_buildPrompt_noRelevantTasks_mentionsKeine` — unverändert
4. `test_generatePitch_nilWhenAIDisabled` — unverändert
5. `test_buildPrompt_feuer_containsChallengeTasks` — unverändert
6. CoachPreviewTests (8 Tests) — unverändert
7. CoachMissionServiceTests (10 Tests) — unverändert

### Build-Verifizierung
8. iOS Build SUCCEEDED
9. macOS Build SUCCEEDED

## Known Limitations

- AI-Pitches sind nicht deterministisch — Länge variiert je nach FoundationModels-Response
- Output-Guardrail (`prefix(400)`) fängt Ausreißer ab
- Wenn AI nicht verfügbar: deterministischer `teaser` aus CoachPreview bleibt stehen

## Changelog

- 2026-03-16: Initial spec created
