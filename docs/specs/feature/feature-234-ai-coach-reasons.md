---
entity_id: feature_234_ai_coach_reasons
type: feature
created: 2026-04-15
updated: 2026-04-15
status: draft
version: "1.0"
tags: [coach, ai, suggestions, apple-intelligence]
---

# Feature #234: AI-Begründungen für Coach-Vorschläge

## Approval

- [ ] Approved

## Purpose

Jeder Vorschlag im Coach-Tab bekommt einen natürlichen deutschen Satz der erklärt warum dieser Task jetzt passt. Generiert von Apple Intelligence on-device, mit deterministischem Fallback.

## Implementierung

### Neuer Service: `AICoachReasonService.swift`

Pattern wie `SuccessStoryService`: Plain-Text AI-Antwort, kein @Generable nötig.

**System-Prompt:**
> Du bist ein knapper Produktivitäts-Coach. Erkläre in einem natürlichen deutschen Satz (max 15 Worte) warum dieser Task JETZT für den User passt. Sei persönlich, nicht belehrend. Keine Floskeln.

**User-Prompt (Kontext pro Task):**
- Task-Titel, Kategorie, Tags
- Anzahl Verschiebungen (rescheduleCount)
- Geschätzte Dauer + freies Zeitfenster
- Tageszeit (morgens/nachmittags)
- Zeitpräferenz des Users für diese Kategorie (aus BehavioralProfile)
- Andere offene Tasks mit gleichem Tag (Tag-Cluster)
- Meeting-Last heute

**Caching:** In-Memory pro Task-ID + Tag. Nicht in AppSettings (zu viele Einträge).

**Fallback:** Bestehende `reasonText(for:)` aus `NextUpSuggestionService` — bleibt unverändert.

### Änderung: `NextUpSuggestion` Model

Neues optionales Feld: `var aiReasonText: String?`
- Wird asynchron befüllt nachdem die Suggestions berechnet sind
- View zeigt `aiReasonText ?? reasonText(for:)` an

### Änderung: `CoachView.swift`

- Bisherige Gruppen-Begründung (`groupReasonText`) bleibt als Gruppen-Header
- **Neu:** Unter jedem einzelnen Task erscheint sein individueller AI-Satz
- Async laden nach View-Aufbau (kein Blocking der UI)
- Visuell: Kleinere, sekundäre Schrift unter dem Task-Titel

### Änderung: `MorningCoachingSection.swift`

- `aiReasonText` nutzen wenn vorhanden, sonst `reasonText(for:)`

## Affected Files

| Datei | Änderung |
|-------|----------|
| `Sources/Services/AICoachReasonService.swift` (NEU) | AI-Service mit Prompt + Fallback |
| `Sources/Services/NextUpSuggestionService.swift` | `aiReasonText` Feld in NextUpSuggestion |
| `Sources/Views/CoachView.swift` | Individuellen Reason-Text unter jedem Task anzeigen |
| `FocusBloxTests/AICoachReasonServiceTests.swift` (NEU) | Unit Tests für Fallback + Prompt |

## Expected Behavior

1. Coach-Vorschlag zeigt persönlichen Satz: "Du erledigst Code-Tasks am liebsten morgens — 30 Min passen perfekt."
2. Ohne Apple Intelligence: Fallback-Satz wie bisher ("Sehr wichtig (30 Min)")
3. Sätze laden asynchron — kein Flackern, kein Blocking
4. Max 15 Worte pro Satz
5. Jeder Task hat seinen eigenen Satz (nicht pro Gruppe)
6. Cache pro Tag — gleicher Task bekommt heute den gleichen Satz

## Out of Scope

- Änderung der Gruppen-Begründung (`groupReasonText`)
- Feedback-Loop (lernt aus Annahme/Ablehnung)
- A/B-Testing-Infrastruktur

## Changelog

- 2026-04-15: Initial spec created
