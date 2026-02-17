---
entity_id: mac_quick_capture_enhanced
type: feature
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [macos, quick-capture, productivity, ux]
---

# MAC-026: Enhanced Quick Capture (macOS)

## Approval

- [ ] Approved

## Purpose

Das bestehende Quick Capture Panel auf macOS aufwerten, sodass es Feature-Paritat mit der iOS QuickCaptureView erreicht und den UX-Standard etablierter Produktivitaets-Apps (Things 3, Fantastical, Todoist) erfuellt. Aktuell kann auf macOS nur ein Titel erfasst werden - Importance, Urgency, Kategorie und Dauer fehlen komplett.

## Ist-Zustand

### Was existiert bereits

| Mechanismus | Status | Datei |
|-------------|--------|-------|
| Floating Panel (NSPanel) | Vorhanden, nur Titel-Eingabe | `FocusBloxMac/QuickCapturePanel.swift` |
| Globaler Hotkey (Cmd+Shift+Space) | Vorhanden, braucht Accessibility-Permission | `QuickCapturePanel.swift:33-54` |
| Menu Bar Extra | Vorhanden, Quick Add mit Titel | `FocusBloxMac/MenuBarView.swift` |
| CoreSpotlight Aktion | Vorhanden, oeffnet Panel | `FocusBloxMacApp.swift:43-56` |
| URL Scheme (focusblox://add) | Vorhanden, oeffnet Panel | `FocusBloxMacApp.swift:139-143` |
| App Intents / Shortcuts | Vorhanden | `Sources/Intents/` |

### Feature-Gap: macOS vs iOS Quick Capture

| Feld | iOS QuickCaptureView | macOS QuickCapturePanel |
|------|---------------------|------------------------|
| Titel | Ja | Ja |
| Importance (1-3) | Ja (Cycle Button) | Nein |
| Urgency (urgent/not_urgent) | Ja (Cycle Button) | Nein |
| Kategorie (5 Typen) | Ja (Picker) | Nein |
| Geschaetzte Dauer | Ja (Picker) | Nein |

## Scope: Was diese Spec abdeckt

### A) Metadata-Eingabe im Floating Panel

**Ziel:** Alle 4 Metadata-Felder aus der iOS QuickCaptureView auch im macOS Panel anbieten.

**Felder:**
1. **Importance** - Cycle Button (nil -> 1 -> 2 -> 3 -> nil), gleiche Logik wie iOS
2. **Urgency** - Cycle Button (nil -> not_urgent -> urgent -> nil), gleiche Logik wie iOS
3. **Kategorie** - Compact Picker (income / maintenance / recharge / learning / giving_back)
4. **Geschaetzte Dauer** - Compact Picker (15 / 25 / 45 / 60 min)

**UI-Layout:**

```
+------------------------------------------------------------------+
|  [cube.fill]  [ Add task...                              ] [ret] |
|  [!] Importance  [>>] Urgency  [tag] Kategorie  [clock] Dauer   |
+------------------------------------------------------------------+
```

- Zweite Zeile nur sichtbar wenn Titel nicht leer ist (progressive disclosure)
- Compact Buttons mit Icons, keine grossen Picker-Sheets
- Keyboard-navigierbar (Tab zwischen Feldern)
- Panel-Hoehe dynamisch: 60px (nur Titel) -> ~100px (mit Metadata)

**Shared Code nutzen:**
- Importance/Urgency Cycle-Logik aus `Sources/` wiederverwenden
- Kategorie-Enum aus `Sources/Models/` nutzen
- Keine Duplikation der Business-Logik

### B) Verbesserter Globaler Hotkey

**Ist:** `NSEvent.addGlobalMonitorForEvents` - braucht Accessibility Permission.

**Soll:** Wechsel auf `KeyboardShortcuts` Library (github.com/sindresorhus/KeyboardShortcuts).

**Vorteile:**
- Keine Accessibility Permission mehr noetig (nutzt Carbon RegisterEventHotKey)
- User kann Shortcut selbst aendern in Settings
- SwiftUI Recorder-Component fuer Settings eingebaut
- Mac App Store kompatibel

**Default-Shortcut:** Cmd+Shift+Space (wie bisher)

**Settings-Integration:** Shortcut-Recorder in MacSettingsView einbauen.

### C) Liquid Glass Styling (macOS 26)

**Ist:** `.ultraThickMaterial` mit manuellem Shadow.

**Soll:** Natives Liquid Glass Appearance nutzen (macOS 26 APIs):
- `.glassEffect()` oder `.ultraThinMaterial` mit Liquid Glass Modifier
- Native macOS 26 Blur/Vibrancy
- Smooth Spring Animation beim Ein-/Ausblenden
- Konsistent mit dem Rest der macOS 26 UI

### D) URL Scheme erweitern

**Ist:** `focusblox://add` oeffnet nur das Panel.

**Soll:** Parameter unterstuetzen:
- `focusblox://add?title=Einkaufen`
- `focusblox://add?title=Einkaufen&duration=25`
- `focusblox://add?title=Einkaufen&duration=25&category=maintenance`
- `focusblox://add?title=Einkaufen&importance=2&urgency=urgent`

Wenn Parameter vorhanden: Panel oeffnet sich mit vorausgefuellten Feldern.

## Ausdruecklich NICHT im Scope

| Feature | Warum nicht |
|---------|-------------|
| Services Menu ("Create Task from Selection") | Separates Feature, eigene Spec |
| Desktop Widget | Separates Feature, eigene Spec |
| AppleScript Dictionary | Power-User Feature, spaeter |
| Raycast/Alfred Extension | Externer Tooling, spaeter |
| Natural Language Parsing | Komplexitaet, eigene Spec |
| Menu Bar Quick Add Verbesserung | Separates Feature |
| Interactive Notifications | Separates Feature |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Sources/Views/QuickCaptureView.swift` | Reference | iOS-Implementierung als Vorbild fuer Metadata-Felder |
| `Sources/Models/LocalTask.swift` | Model | Task-Modell mit allen Feldern |
| `Sources/Helpers/ImportanceUrgencyHelper.swift` | Shared Logic | Cycle-Logik fuer Importance/Urgency |
| `FocusBloxMac/QuickCapturePanel.swift` | Target | Zu aendernde Datei |
| `FocusBloxMac/FocusBloxMacApp.swift` | Target | URL Scheme Handler |
| KeyboardShortcuts (extern) | Library | github.com/sindresorhus/KeyboardShortcuts |

## Betroffene Dateien (geschaetzt)

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/QuickCapturePanel.swift` | Metadata-Felder, Styling, Hotkey-Migration |
| `FocusBloxMac/FocusBloxMacApp.swift` | URL Scheme Parameter-Parsing |
| `FocusBloxMac/MacSettingsView.swift` | Shortcut-Recorder einbauen |
| `FocusBlox.xcodeproj` | KeyboardShortcuts Package hinzufuegen |

**Geschaetzte Aenderung:** ~4 Dateien, ~200 LoC - innerhalb Scoping-Limits.

## Expected Behavior

### Quick Capture Panel

- **Trigger:** Cmd+Shift+Space (oder user-definierter Shortcut)
- **Erscheinen:** Panel gleitet von oben ein (Spring Animation), Textfeld hat sofort Fokus
- **Eingabe:** Titel tippen, optional Tab zu Metadata-Buttons
- **Absenden:** Return erstellt Task mit allen gesetzten Metadata
- **Abbrechen:** Escape schliesst Panel, Felder werden zurueckgesetzt
- **Seiteneffekt:** Task wird in SwiftData gespeichert, CloudKit synct automatisch

### URL Scheme

- **Input:** `focusblox://add?title=Test&duration=25&category=maintenance`
- **Output:** Panel oeffnet sich mit vorausgefuellten Werten
- **Ungueltige Parameter:** Werden ignoriert, kein Fehler

### Globaler Hotkey

- **Konfiguration:** In Settings aenderbar via SwiftUI Recorder
- **Default:** Cmd+Shift+Space
- **Konflikt:** Library zeigt Warnung wenn Shortcut belegt

## Akzeptanzkriterien

1. Floating Panel zeigt alle 4 Metadata-Felder (Importance, Urgency, Kategorie, Dauer)
2. Metadata-Felder nutzen Shared Code aus `Sources/` (keine Duplikation)
3. Globaler Hotkey funktioniert OHNE Accessibility Permission
4. User kann Hotkey in Settings aendern
5. URL Scheme akzeptiert title/duration/category/importance/urgency Parameter
6. Panel hat Liquid Glass Styling (macOS 26)
7. Keyboard-Navigation: Tab durch alle Felder, Return zum Absenden, Escape zum Schliessen
8. Task wird korrekt mit allen Metadata in SwiftData gespeichert

## Risiken

| Risiko | Mitigation |
|--------|-----------|
| KeyboardShortcuts Library Kompatibilitaet mit macOS 26 | Vor Integration testen, Fallback auf bestehende NSEvent-Loesung |
| Liquid Glass APIs noch nicht final | `.ultraThinMaterial` als Fallback |
| Panel-Groesse auf kleinen Screens | Min/Max Constraints setzen |

## Priorisierung der Teilbereiche

| Prio | Bereich | Aufwand |
|------|---------|---------|
| 1 | A) Metadata-Eingabe | Mittel |
| 2 | C) Liquid Glass Styling | Gering |
| 3 | B) Verbesserter Hotkey | Mittel (externe Dependency) |
| 4 | D) URL Scheme erweitern | Gering |

Empfehlung: A+C zusammen als erstes (kein externer Dependency), dann B+D.

## Changelog

- 2026-02-13: Initial spec created (research + gap analysis)
