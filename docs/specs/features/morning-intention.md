---
entity_id: morning-intention
type: feature
created: 2026-04-02
updated: 2026-04-02
status: draft
version: "1.0"
tags: [coach, intention, ai, morning]
---

# Morning Intention (Phase A von #195)

## Approval

- [ ] Approved

## Purpose

Die Morning-Section im Coach-Tab wird von einer Task-Vorschlags-Liste zu einem echten Intention-Setting umgebaut. Der User wählt morgens in 10 Sekunden seine Tages-Intention aus 3 AI-generierten Vorschlägen.

## Aktueller Zustand

- "Was soll heute zählen?" ist ein Textlabel (nicht interaktiv)
- Darunter: MorningCoachingSection mit Task-Vorschlägen (Accept/Reject Buttons)
- Kein Intention-Konzept, keine Persistierung, kein Gestern-Echo

## Neuer Zustand

### Morning-Section (Intention gesetzt = false)
1. Dezent oben: "Gestern: [gestrige Intention]" (ausgegraut, wenn vorhanden)
2. "Was soll heute zählen?" als große Überschrift
3. 3 tappbare Chips mit AI-Intentionen (keine Buttons, keine Checkmarks)
4. Tap auf Chip → Chip hervorgehoben, andere verblassen → Intention gespeichert

### Morning-Section (Intention gesetzt = true)
1. "Heute: [gewählte Intention]" prominent angezeigt
2. Darunter: bestehende Task-Vorschläge + freie Lücken + "Heute geplant" (wie bisher)

## Source

| Datei | Änderung |
|-------|----------|
| **NEU:** `Sources/Models/DayIntention.swift` | SwiftData Model |
| **NEU:** `Sources/Services/IntentionSuggestionService.swift` | AI-Vorschläge generieren |
| `Sources/Views/CoachView.swift` | Morning-Section Redesign |
| `Sources/FocusBloxApp.swift` | DayIntention in Schema |
| `FocusBloxUITests/CoachIntentionUITests.swift` | UI Tests |

## Datenmodell

```swift
@Model
final class DayIntention {
    var uuid: UUID = UUID()
    var date: Date = Date()        // Tag (startOfDay)
    var text: String = ""          // "Die große Sache anpacken"
    var createdAt: Date = Date()
}
```

## IntentionSuggestionService

- Nutzt Apple Foundation Models (@Generable) wenn verfügbar
- Input: Top-5-Tasks nach Priorität, Kalender-Dichte, gestrige Intention
- Output: 3 kurze Intentions-Texte (3-8 Worte)
- Fallback ohne AI: 3 statische Optionen

## Expected Behavior

- **Morgens, keine Intention gesetzt:** Frage + 3 Chips + optional Gestern-Echo
- **Tap auf Chip:** Chip hervorgehoben, Intention gespeichert in SwiftData, andere Chips verblassen
- **Morgens, Intention bereits gesetzt:** "Heute: [Intention]" + normale Task-Vorschläge
- **Gestern-Echo:** Zeigt gestrige Intention wenn vorhanden (ausgegraut)
- **Persistierung:** DayIntention in SwiftData, überlebt App-Restart

## Known Limitations

- Phase A nur: Intention wird morgens gesetzt, aber tagsüber/abends noch nicht genutzt (Phase B+C)
- AI-Vorschläge brauchen iOS 26.0+ mit Apple Intelligence
- Fallback: 3 statische Vorschläge wenn AI nicht verfügbar
