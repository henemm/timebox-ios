# Feature: MenuBar FocusBlock Status

## Zusammenfassung

Die bestehende MenuBarView um einen FocusBlock-Status erweitern, sodass der Nutzer jederzeit sieht, welcher Task gerade laeuft und wie viel Zeit noch bleibt - ohne das Hauptfenster oeffnen zu muessen.

**Auf iOS uebernimmt die Live Activity diese Rolle. Auf macOS gibt es kein Aequivalent - die MenuBar ist der natuerliche Ort dafuer.**

---

## Ist-Zustand

### MenuBarExtra (FocusBloxMacApp.swift:124-130)
- Label: Statisches Icon `cube.fill` - aendert sich nie
- Style: `.menuBarExtraStyle(.window)` - Popover-Fenster
- Kein Zugang zu EventKit (kein `.environment(\.eventKitRepository)`)

### MenuBarView.swift (231 LoC)
- Header: "FocusBlox" + Task-Zaehler
- Quick Add: Inline Task-Erstellung
- Next Up: Top 3 Tasks
- Backlog Preview: Top 2 Tasks
- Footer: "Open FocusBlox" + "Quit"
- **Kein FocusBlock-Status, kein Timer, kein aktiver Task**

### MacFocusView.swift (568 LoC)
- Hat den kompletten FocusBlock-Status (Timer, Progress, Current Task, Actions)
- Nutzt `Timer.publish(every: 1)` fuer Live-Updates
- Nutzt `EventKitRepository` fuer Block-Daten
- Nutzt `TimerCalculator` (Shared Service) fuer Berechnungen

---

## Soll-Zustand

### 1. Menu Bar Label (dynamisch)

| Zustand | Label |
|---------|-------|
| Kein aktiver Block | `cube.fill` (wie bisher) |
| Block aktiv, Task laeuft | `cube.fill` + "12:34" (Restzeit aktueller Task, mm:ss) |
| Block aktiv, alle Tasks erledigt | `cube.fill` + Checkmark |

**Warum mm:ss?** Der Nutzer will auf einen Blick wissen, wie viel Zeit der aktuelle Task noch hat. Minuten allein (z.B. "12 min") sind zu ungenau fuer kurze Tasks (5-15 min).

### 2. Popover: Focus Section (NEU, ganz oben)

Wenn ein Block aktiv ist, erscheint VOR dem Header eine kompakte Focus-Section:

```
┌─────────────────────────────────┐
│ ● Deep Work            14:23   │  ← Block-Name + Block-Restzeit
│ ██████████░░░░░░  3/5 Tasks    │  ← Fortschrittsbalken + Zaehler
│                                │
│ ▶ E-Mails beantworten   07:12  │  ← Aktueller Task + Task-Restzeit
│   15 min geschaetzt            │  ← Geplante Dauer
│                                │
│  [Erledigt ✓]    [Weiter →]    │  ← Complete + Skip Buttons
├─────────────────────────────────┤
│ Quick Add Task                  │  ← Rest wie bisher
│ ...                             │
```

Wenn KEIN Block aktiv ist:
```
┌─────────────────────────────────┐
│ ☽ Kein aktiver Focus Block      │
├─────────────────────────────────┤
│ Quick Add Task                  │
│ ...                             │
```

### 3. Actions im Popover

| Button | Aktion | Shared Service |
|--------|--------|----------------|
| Erledigt | Task als erledigt markieren | `FocusBlockActionService.completeTask()` |
| Weiter | Task ueberspringen | `FocusBlockActionService.skipTask()` |

Beide nutzen den bestehenden Shared Service - keine neue Logik noetig.

---

## Technischer Plan

### Dateien (2 Dateien, ~120 LoC netto)

| Datei | Aenderung | LoC |
|-------|-----------|-----|
| `FocusBloxMac/MenuBarView.swift` | Focus Section hinzufuegen, Timer-State, EventKit-Zugriff | ~100 LoC netto |
| `FocusBloxMac/FocusBloxMacApp.swift` | EventKit Environment an MenuBarView durchreichen | ~3 LoC |

### Neue State-Properties in MenuBarView

```swift
// FocusBlock State
@State private var activeBlock: FocusBlock?
@State private var currentTime = Date()
@State private var taskStartTime: Date?
@State private var lastTaskID: String?
@Environment(\.eventKitRepository) private var eventKitRepo

// 1-Sekunden Timer (wie MacFocusView)
private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
```

### Berechnung (bestehende Shared Services)

- `TimerCalculator.remainingSeconds(until:now:)` - Task-Restzeit
- `TimerCalculator.plannedTaskEndDate(...)` - Geplantes Task-Ende
- `FocusBlockActionService.completeTask(...)` - Task erledigen
- `FocusBlockActionService.skipTask(...)` - Task ueberspringen

### Timer-Effizienz

Der 1-Sekunden-Timer laeuft NUR wenn ein aktiver Block existiert. Ohne Block: Polling alle 60 Sekunden, ob ein neuer Block gestartet hat.

---

## Abgrenzung (Out of Scope)

- Kein Sprint Review im Popover (zu komplex, bleibt im Hauptfenster)
- Keine Vorwarnung/Sound aus dem Popover (MacFocusView macht das bereits)
- Keine Task-Queue (nur aktueller Task sichtbar)
- Kein Drag & Drop im Popover

---

## Risiken

| Risiko | Mitigation |
|--------|------------|
| Timer-Ressourcen bei geschlossenem Popover | Timer nur bei aktivem Block, sonst 60s Polling |
| EventKit-Zugriff im MenuBarExtra | Environment muss explizit durchgereicht werden (wie bei Settings) |
| Doppelte Timer (Popover + Hauptfenster) | Akzeptabel - beide sind leichtgewichtig, nur UI-Updates |
| Task Complete/Skip State-Sync | Nach Action `loadData()` in beiden Views aufrufen |

---

## Acceptance Criteria

1. Menu Bar Label zeigt Restzeit (mm:ss) wenn ein Block aktiv ist
2. Popover zeigt aktuellen Task-Namen, Restzeit und Fortschrittsbalken
3. "Erledigt" Button markiert Task als erledigt (via FocusBlockActionService)
4. "Weiter" Button ueberspringt Task (via FocusBlockActionService)
5. Ohne aktiven Block: Bestehendes Verhalten (Next Up, Backlog, Quick Add)
6. Timer aktualisiert sich jede Sekunde bei aktivem Block
