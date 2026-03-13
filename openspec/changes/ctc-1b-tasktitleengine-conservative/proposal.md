# CTC-1b: TaskTitleEngine — Konservativ + Metadaten-Extraktion

**Status:** Geplant
**Prioritaet:** Hoch
**Kategorie:** Support Feature (verbessert Ergebnis-Qualitaet der bestehenden KI)
**Aufwand:** Klein

---

## Modus: AENDERUNG

Bestehendes Feature CTC-1 (TaskTitleEngine) wird gezielt verbessert.
Keine neue Datei, keine neue Architektur — nur `TaskTitleEngine.swift` + Tests anpassen.

---

## Problem

Getesteter Input: "Bahnfahrt OH buchen (22. - 25.3.) heute erledigen!"

Aktuelles Ergebnis (SCHLECHT):
- Titel: "Bahnhofs-Tickets buchen (22. - 25.3.) heute erledigen!"
- "Bahnfahrt" → "Bahnhofs-Tickets" (Halluzination, sachlich falsch)
- "OH" entfernt (wichtige Abkuerzung verloren)
- "heute erledigen!" im Titel belassen statt extrahiert
- dueDate: nil (nicht gesetzt)
- urgency: nil (nicht gesetzt)

Erwartetes Ergebnis (SOLL):
- Titel: "Bahnfahrt OH buchen (22.-25.3.)"
- dueDate: heute (wegen "heute erledigen")
- urgency: "urgent" (wegen "heute erledigen!" + Ausrufezeichen)

---

## Aktueller Zustand (IST)

**Datei:** `Sources/Services/TaskTitleEngine.swift` (114 Zeilen)

**Structured Output:**
```swift
@Generable
struct ImprovedTitle {
    @Guide(description: "Short, actionable task title (max 80 chars)...")
    let title: String
}
```
Nur ein Feld: `title`. Keine Metadaten-Extraktion.

**System Prompt:**
```
"Du verbesserst Task-Titel. Regeln:"
"- Kurz und actionable (max 80 Zeichen)"
"- Beginne mit Verb im Infinitiv"
"- Entferne E-Mail-Artefakte (Re:, Fwd:, AW:, WG:)"
"- Behalte die Sprache des Inputs bei"
"- Wenn der Titel bereits gut ist, gib ihn unveraendert zurueck"
```
Kein Verbot von semantischen Umschreibungen. Kein Extraktion-Auftrag.

**Was auf LocalTask gesetzt wird:**
- `task.title = improved.title`
- `task.needsTitleImprovement = false`
Sonst nichts.

---

## Delta (WAS aendert sich)

### 1. `ImprovedTitle` → `ImprovedTask` (neue Felder)

Vorher:
```swift
@Generable
struct ImprovedTitle {
    let title: String
}
```

Nachher:
```swift
@Generable
struct ImprovedTask {
    @Guide(description: "...")
    let title: String

    @Guide(description: "...")
    let dueDateRelative: String?   // "today" | "tomorrow" | nil

    @Guide(description: "...")
    let isUrgent: Bool
}
```

`dueDateRelative` als String statt Date — Foundation Models kann kein `Date` generieren.
Mapping: "today" → `Calendar.current.startOfDay(for: Date())`, "tomorrow" → naechster Tag.

### 2. System Prompt: konservativer

Neue Regel hinzufuegen:
- "Veraendere KEINE Woerter, Abkuerzungen oder Namen aus dem Original"
- "Kuerze nur durch Weglassen, nicht durch Umschreiben"
- "Entferne Dringlichkeits-Hinweise aus dem Titel (heute, dringend, ASAP, Ausfuehrungs-Anweisungen)"

### 3. Metadaten auf LocalTask setzen

Nach dem KI-Call:
```swift
// dueDate nur setzen wenn noch nil (nicht ueberschreiben)
if task.dueDate == nil, let rel = result.dueDateRelative {
    task.dueDate = relativeDateFrom(rel)
}
// urgency nur setzen wenn noch nil
if task.urgency == nil, result.isUrgent {
    task.urgency = "urgent"
}
```

Werte-Typen auf LocalTask (bestaetigt):
- `dueDate: Date?` — passt
- `urgency: String?` — erlaubte Werte: `"urgent"` | `"not_urgent"` | `nil`

### 4. Neue private Hilfsmethode

```swift
private func relativeDateFrom(_ rel: String) -> Date? {
    switch rel {
    case "today":    return Calendar.current.startOfDay(for: Date())
    case "tomorrow": return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
    default:         return nil
    }
}
```

---

## Scope-Pruefung

| Kriterium | Wert | Limit |
|-----------|------|-------|
| Geaenderte Dateien | 2 (Engine + Tests) | Max 4-5 |
| Geschaetzte LoC | ~60 (Engine ~40, Tests ~20) | Max 250 |
| Neue Permissions | keine | — |
| Neue Dependencies | keine | — |
| Plattform-Divergenz | keine (TaskTitleEngine ist Shared-Code) | — |

---

## Nicht im Scope

- Absolutes Datum-Parsing ("am 25.3.", "naechsten Montag") — zu komplex, separates Ticket
- Datum-Extraktion wenn dueDate bereits gesetzt — kein Ueberschreiben
- urgency setzen als "not_urgent" — nur "urgent" wenn explizit erkannt, sonst nil lassen
- Aenderungen an SmartTaskEnrichmentService oder AITaskScoringService

---

## Betroffene Systeme

- `Sources/Services/TaskTitleEngine.swift` — Hauptaenderung
- `FocusBloxTests/TaskTitleEngineTests.swift` — Tests erweitern

Nicht betroffen: SmartTaskEnrichmentService, AITaskScoringService, LocalTask (keine Schema-Aenderung)
