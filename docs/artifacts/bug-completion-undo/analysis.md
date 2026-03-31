# Bug-Analyse: Task-Completion kann während 3-Sekunden-Fenster nicht rückgängig gemacht werden

## Bug-Beschreibung

Nach dem Markieren eines Tasks als "Erledigt" (Checkbox-Tap) ist der Task für 3 Sekunden visuell als erledigt markiert (grüner Haken, Durchstreichung, reduzierte Opacity). Während dieser 3 Sekunden kann der User den Tap **nicht** durch erneutes Tippen rückgängig machen.

**Plattformen:** iOS UND macOS (identischer Guard-Code)

## Verwandte bisherige Fixes

| Commit | Titel | Was gefixt wurde | Warum nicht das User-Problem |
|--------|-------|-------------------|------------------------------|
| 3a182cb | Deferred Task Completion | Feature: 3s Delay vor Verschwinden | Feature eingeführt, Undo vorgesehen aber nie verdrahtet |
| f93f2df | BUG_122 — Blocked Tasks Inline-Badge-Editing | `blockedRow()` fehlten Badge-Callbacks | Betraf NUR dependency-blockierte Tasks, NICHT deferred completion |

**BUG_122 war ein ANDERER Bug:** Es ging um Tasks die durch Task-Abhängigkeiten (blockerTaskID) blockiert waren. Diese konnten keine Badge-Werte ändern. Das wurde korrekt gefixt. Das User-Problem hier ist aber die **Deferred Completion** — der 3-Sekunden-Verzögerung nach Completion-Tap.

## Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check)
- BUG_122 wurde als "ERLEDIGT" markiert, adressierte aber ein anderes Problem (dependency-blocked tasks)
- Kein früherer Fix für "Completion Undo während Pending Phase" gefunden
- `cancelCompletion()` existiert seit dem ursprünglichen Feature (3a182cb), wurde aber NIE verdrahtet

### Agent 2 (Datenfluss-Trace)
- **BacklogRow.swift:35**: `if !isCompletionPending && !isBlocked { onComplete?() }` — dieser Guard BLOCKIERT den zweiten Tap
- **DeferredCompletionController.swift:60-67**: `cancelCompletion(id:)` — perfekt implementiert, wird aber von KEINER Stelle aufgerufen
- Datenfluss: Tap → `completeTask()` → `scheduleCompletion()` → `pendingIDs.insert()` → Guard blockiert weitere Taps

### Agent 3 (Alle Schreiber)
- BacklogRow hat KEINEN `onCancelCompletion`-Callback
- Guard auf Zeile 35 ist die einzige Stelle die den zweiten Tap verhindert
- macOS MacBacklogRow hat DENSELBEN Guard (Zeile 37)

### Agent 4 (Szenarien)
- Badge-Taps (Importance, Urgency, Category) sind während Completion-Pending NICHT blockiert
- NUR die Completion-Checkbox ist blockiert
- Kein Undo-Pfad existiert in der UI

### Agent 5 (Blast Radius)
- iOS BacklogView + macOS ContentView: beide betroffen
- DayView, FocusLiveView etc.: nicht betroffen (nutzen kein deferred completion)
- CoachBacklogView: blockedRow() nutzt kein deferred completion

## Hypothesen

### Hypothese 1: Guard blockiert Undo-Tap (HOCH — Root Cause)
**BacklogRow.swift:35** — `if !isCompletionPending && !isBlocked`

- **Beweis DAFÜR:** Code zeigt eindeutig: Wenn `isCompletionPending=true`, wird `onComplete?()` nie aufgerufen. Der zweite Tap hat keine Wirkung.
- **Beweis DAGEGEN:** Keiner. Der Code ist eindeutig.
- **Wahrscheinlichkeit:** HOCH

### Hypothese 2: `cancelCompletion()` ist Dead Code (HOCH — Teil des Problems)
**DeferredCompletionController.swift:60-67** — Methode existiert, wird nie aufgerufen.

- **Beweis DAFÜR:** Grep nach `cancelCompletion` findet nur die Definition, keine Aufrufe
- **Beweis DAGEGEN:** Keiner
- **Wahrscheinlichkeit:** HOCH (bestätigt durch Code-Analyse)

### Hypothese 3: BacklogRow fehlt ein Undo-Callback (HOCH — Teil des Problems)
BacklogRow hat `onComplete` aber kein `onCancelCompletion`. Selbst wenn der Guard entfernt würde, gäbe es keinen Callback um `cancelCompletion()` aufzurufen.

- **Beweis DAFÜR:** Parameter-Liste in BacklogRow.swift:3-22 — kein Cancel-Callback
- **Beweis DAGEGEN:** Keiner
- **Wahrscheinlichkeit:** HOCH

### Hypothese 4: Timer-Reset statt Cancel (NIEDRIG — Alternative)
DeferredCompletionController.scheduleCompletion() Zeile 32-33 cancelt bestehenden Timer und startet neu. Theoretisch könnte ein erneuter Aufruf von `scheduleCompletion()` den Timer resetten.

- **Beweis DAFÜR:** Code-Kommentar sagt "double-tap resets"
- **Beweis DAGEGEN:** Das würde den Task weiterhin als pending zeigen und nach 3s erneut committen — kein echtes Undo
- **Wahrscheinlichkeit:** NIEDRIG (löst das Problem nicht wirklich)

## Wahrscheinlichste Ursache

**Kombination aus Hypothese 1 + 2 + 3:** Der Guard verhindert den zweiten Tap, der Cancel-Mechanismus existiert aber ist nie verdrahtet, und BacklogRow hat keinen Callback dafür.

Die anderen Hypothesen sind weniger wahrscheinlich weil:
- H4 (Timer-Reset) würde kein echtes Undo bieten

## Debugging-Plan (falls gewünscht)

Nicht nötig — der Code ist eindeutig. Kein Logging erforderlich.

- **Zeile 35 in BacklogRow.swift:** Guard `!isCompletionPending` verhindert den zweiten Tap
- **Zeile 60-67 in DeferredCompletionController.swift:** `cancelCompletion()` existiert aber wird nie aufgerufen
- Beide Stellen sind eindeutig verifiziert durch Code-Lesen

## Blast Radius

| View | Plattform | Betroffen? |
|------|-----------|------------|
| BacklogView (Backlog-Tab) | iOS | JA |
| ContentView (Backlog) | macOS | JA |
| DayView | iOS | Nein (kein Completion-Toggle) |
| CoachBacklogView | iOS | Nein (nutzt kein deferred completion) |
| FocusLiveView | iOS | Nein (direktes Complete) |

## Fix-Vorschlag

**Änderung 1: BacklogRow.swift** — Guard ändern, sodass bei `isCompletionPending=true` ein Cancel-Callback aufgerufen wird statt zu blockieren.

**Änderung 2: BacklogRow.swift** — Neuen optionalen Callback `onCancelCompletion: (() -> Void)?` hinzufügen.

**Änderung 3: BacklogView.swift** — Callback verdrahten: `deferredCompletion.cancelCompletion(id: item.id)`.

**Änderung 4: MacBacklogRow.swift** — Gleicher Guard-Fix + Callback.

**Änderung 5: ContentView.swift (macOS)** — Callback verdrahten.

**Geschätzt: 5 Dateien, ~30 LoC Änderung.**
