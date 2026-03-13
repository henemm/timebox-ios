# Analyse: Suchfunktion im Dependency-Auswahldialog

## Symptom
Der Dependency-Picker ("Abhängig von") zeigt alle verfügbaren Tasks in einer langen Dropdown-Liste ohne Suchfunktion. Bei vielen Tasks ist die gewünschte Abhängigkeit schwer zu finden.

## Betroffene Plattformen
- **iOS:** `Sources/Views/TaskFormSheet.swift` (Zeile 293-311) — `.pickerStyle(.menu)` Dropdown
- **macOS:** `FocusBloxMac/TaskInspector.swift` (Zeile 169-192) — Standard-Picker

## Status: Feature nie implementiert (kein Bug)
Die Suche war nie geplant oder implementiert. Der Picker zeigt alle `blockerCandidates` (nicht-abgeschlossene, nicht-Template Tasks, ohne Zyklen) direkt als Liste.

## Ist-Zustand

### Datenfluss
1. `@Query` lädt alle Tasks mit `!isCompleted && !isTemplate`
2. `blockerCandidates` filtert davon Zyklen heraus (`wouldCreateCycle()`)
3. `Picker` zeigt alle Candidates als `Text(task.title)` — keine Suche, keine Gruppierung

### Bestehendes Such-Pattern
`BacklogView.swift` hat bereits eine funktionierende Suche:
- `@State private var searchText = ""`
- `.searchable(text: $searchText, prompt: "Tasks durchsuchen")`
- `matchesSearch(_:)` filtert nach Titel, Tags, Kategorie

## Hypothesen für Lösungsansatz

### H1: NavigationLink-Picker mit .searchable() (Wahrscheinlichkeit: NIEDRIG)
- `.pickerStyle(.navigationLink)` + `.searchable()` auf dem NavigationStack
- **Problem:** `.searchable()` auf Picker-Ebene ist in iOS 26 nicht zuverlässig unterstützt
- **Problem:** Ändert die UX fundamental (Navigation-Push statt Dropdown)

### H2: Custom Searchable Sheet (Wahrscheinlichkeit: HOCH)
- Picker ersetzen durch Button der ein Sheet öffnet
- Sheet enthält: Suchfeld + gefilterte Task-Liste + "Keine"-Option
- Standard iOS-Pattern (wie Kontakt-Auswahl, etc.)
- **Vorteil:** Volle Kontrolle, bekanntes UX-Pattern, `.searchable()` funktioniert zuverlässig
- **Vorteil:** Kann mehr Info zeigen (Kategorie-Badge, Tags)

### H3: Inline-TextField über dem Picker (Wahrscheinlichkeit: NIEDRIG)
- TextField + Picker kombinieren
- **Problem:** Hacky, nicht-nativ, Picker-Menu öffnet sich trotzdem ungefiltert

## Empfehlung: H2 — Custom Searchable Sheet

### Konzept
```
[Abhängig von: Task-Name]  ← Button (nicht Picker)
       │
       ▼ tap
┌──────────────────────────┐
│  ⌕ Task durchsuchen...   │  ← .searchable()
├──────────────────────────┤
│  ○ Keine                 │
│  ● Einkaufen gehen       │  ← aktuell ausgewählt
│    Haushaltsarbeit        │
│    Bericht schreiben      │
│    Meeting vorbereiten    │
└──────────────────────────┘
```

### Betroffene Dateien
| Datei | Änderung | LoC |
|-------|----------|-----|
| `Sources/Views/TaskFormSheet.swift` | Picker → Button + Sheet, State für Suche | ~30 |
| `Sources/Views/BlockerPickerSheet.swift` | **NEU:** Searchable Sheet-View | ~80 |
| `FocusBloxMac/TaskInspector.swift` | Gleiche Änderung wie iOS | ~20 |

**Gesamt: ~130 LoC, 3 Dateien** (innerhalb Scoping-Limit)

### Shared vs. Plattform-spezifisch
- `BlockerPickerSheet.swift` in `Sources/Views/` → **Shared** (beide Plattformen)
- Nutzt gleiche `blockerCandidates`-Logik
- iOS: als `.sheet()` präsentiert
- macOS: als `.sheet()` oder Popover

## Blast Radius
- **Minimal:** Nur der Dependency-Picker ist betroffen
- **Kein anderer Picker** braucht Suche (alle anderen sind Enum-Picker mit max 5-6 Optionen)
- **Keine Business-Logik-Änderung** — nur UI-Layer

## Challenge-Punkte
- Muss auf BEIDEN Plattformen funktionieren
- Sheet-Dismissal + Selection-Binding muss korrekt sein
- Accessibility: `blockerPicker` ID muss erhalten bleiben für bestehende Tests
