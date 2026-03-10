# Bug-Analyse: macOS MenuBar Timer zeigt Block-Dauer statt Task-Dauer

## Symptom
Der Timer in der macOS Menüleiste zeigt während eines aktiven FocusBlox die **Gesamtdauer des Blocks** (z.B. 45:00 verbleibend bis Block-Ende) anstatt der **verbleibenden Zeit des aktuellen Tasks** (z.B. 12:00 bis Task-Ende).

## Plattform
macOS — nur der StatusItem-Timer in der Menüleiste. Das Popover zeigt den Task-Timer korrekt.

---

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- **Bug 41** war exakt dasselbe Problem für iOS LiveActivity — wurde dort gefixt durch Einführung von `taskEndDate` in `ContentState`
- **Bug 55A** war Timer-Overflow (Tasks > Block-Dauer) — gefixt durch Clamping
- **Bug 66** hat den MenuBar-Timer überhaupt erst zum Laufen gebracht (war vorher statisches Icon)
- Das Muster "Block-Zeit statt Task-Zeit" ist ein bekanntes, wiederkehrendes Problem

### Agent 2: Datenfluss-Trace
Zwei unabhängige Timer-Pfade:
1. **StatusItem (Menüleisten-Label):** `MenuBarIconState.from()` → `block.endDate - now` = **Block-Restzeit**
2. **Popover (innerhalb):** `TimerCalculator.plannedTaskEndDate()` → **Task-Restzeit** (korrekt)

### Agent 3: Alle Schreiber
- Einziger Schreibpunkt: `FocusBloxMacApp.swift:98` → `button.title = timerText`
- `timerText` kommt von `MenuBarIconState.from()` → berechnet Block-Restzeit
- `MenuBarIconState` hat keinen Zugriff auf Task-Informationen

### Agent 4: Szenarien
- Bei Multi-Task-Blocks: Fehler von 20-45 Minuten möglich
- Bei Single-Task: Zufällig korrekt (wenn Task-Dauer = Block-Dauer)
- Bei "All Done": Zeigt weiter Block-Countdown statt Checkmark (wenn nur MenuBar, nicht Popover)

### Agent 5: Blast Radius + Spec
- **iOS LiveActivity Spec** (`docs/specs/features/live-activity.md`) definiert: Timer zeigt **Task-Countdown**, nicht Block-Countdown
- iOS implementiert das korrekt via `taskEndDate` in `ContentState`
- **Alle anderen Views** (iOS FocusView, macOS MacFocusView, Popover) zeigen Task-Zeit korrekt
- **Nur `MenuBarIconState`** zeigt Block-Zeit

---

## Hypothesen

### Hypothese 1: MenuBarIconState berechnet Block-Restzeit statt Task-Restzeit (HOCH)
**Code:** `Sources/Services/MenuBarIconState.swift:27`
```swift
let remaining = block.endDate.timeIntervalSince(now)  // Block-Ende, nicht Task-Ende
```
**Beweis dafür:** Code liest eindeutig `block.endDate`, nicht eine Task-bezogene Zeit.
**Beweis dagegen:** Keiner — der Code ist eindeutig.
**Wahrscheinlichkeit:** HOCH (99%)

### Hypothese 2: MenuBarController hat keinen Zugriff auf Task-Daten (HOCH)
**Code:** `FocusBloxMacApp.swift:42-77` — `setup()` speichert `ModelContainer` nicht.
**Beweis dafür:** `MenuBarController` hat nur `eventKitRepo` und `cachedBlock`, kein SwiftData-Zugriff.
**Beweis dagegen:** Keiner.
**Wahrscheinlichkeit:** HOCH — ist die URSACHE dafür, dass Hypothese 1 so implementiert wurde.

### Hypothese 3: Bewusste Design-Entscheidung (NIEDRIG)
**Beweis dafür:** Bug 66 hat den Timer erst kürzlich implementiert — möglicherweise war Block-Zeit ein bewusster erster Schritt.
**Beweis dagegen:** Die iOS Spec definiert explizit Task-Zeit. Das Popover zeigt bereits Task-Zeit. Es wäre inkonsistent.
**Wahrscheinlichkeit:** NIEDRIG — eher ein Versäumnis bei Bug 66 als Absicht.

---

## Root Cause

**`MenuBarIconState.from()` berechnet `block.endDate - now` (Block-Restzeit) statt die geplante Task-Endzeit via `TimerCalculator.plannedTaskEndDate()` zu verwenden.**

Der Grund: `MenuBarController` hat keinen Zugriff auf SwiftData (`ModelContainer`), daher kann er keine Task-Informationen abrufen. Bei Bug 66 wurde deshalb der einfachere Weg gewählt — nur Block-Level-Daten aus EventKit.

---

## Fix-Ansatz

1. `MenuBarController` erhält Zugriff auf `ModelContainer` (wird in `setup()` bereits übergeben, aber nicht gespeichert)
2. In `updateIcon()`: Wenn aktiver Block vorhanden, aktuelle Task-ID ermitteln und `TimerCalculator.plannedTaskEndDate()` berechnen
3. `MenuBarIconState.from()` erweitern: Neuer Parameter `taskEndDate: Date?` — wenn vorhanden, diesen statt `block.endDate` verwenden

**Betroffene Dateien (3):**
- `Sources/Services/MenuBarIconState.swift` — Parameter erweitern
- `FocusBloxMac/FocusBloxMacApp.swift` — Container speichern, Task-Endzeit berechnen
- `FocusBloxTests/MenuBarIconStateTests.swift` — Tests anpassen

**Call-Site:** `FocusBloxMacApp.swift:89` — `MenuBarIconState.from(block:now:)` wird dort aufgerufen.

---

## Blast Radius
- **Kein Risiko für iOS** — iOS verwendet eigene LiveActivity-Logik
- **Kein Risiko für Popover** — Popover berechnet Task-Zeit unabhängig
- **Bestehende Unit Tests** (MenuBarIconStateTests) müssen um `taskEndDate`-Parameter erweitert werden
