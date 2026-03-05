# BACKLOG-010: Deferred Sort Logik dupliziert (iOS vs macOS)

## Bug-Beschreibung
Deferred-Sort-Freeze ist auf iOS (BacklogView.swift) und macOS (ContentView.swift) separat implementiert. ~95% identische Logik, unterschiedlicher Code. Hat direkt zum macOS-Bug gefuehrt (scoreFor() wurde uebersehen).

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- **4 Commits** zur Deferred-Sort-Logik: Feature (2d63eed), 3-Bug-Fix (240b82c), Task-Jumping-Fix (4994128), macOS-Regression-Fix (bb9e696)
- **2 Regressionen** direkt durch Plattform-Divergenz verursacht
- macOS-Regression (bb9e696) passierte **8 Minuten** nach dem Haupt-Fix — `scoreFor()` wurde nicht vollstaendig aktualisiert
- **Muster:** Jeder Fix auf einer Plattform erzeugt potentiell eine Regression auf der anderen

### Agent 2: Datenfluss-Trace
- Lifecycle auf beiden Plattformen identisch: Freeze -> Update -> Schedule -> Wait 3s -> Fade Borders -> Wait 200ms -> Unfreeze
- **Typ-Divergenz:** iOS nutzt `Set<String>` fuer pendingResortIDs, macOS `Set<UUID>`
- **Snapshot-Erstellung unterschiedlich:** iOS nutzt `item.priorityScore` (cached), macOS ruft `calculateScore()` direkt auf
- **Post-Unfreeze:** iOS ruft `refreshLocalTasks()`, macOS verlaesst sich auf `@Query` Auto-Update

### Agent 3: Alle Schreiber
- **10 Write-Locations** total (5 pro Plattform), perfekt symmetrisch
- Freeze: 2x (BacklogView:588, ContentView:1036)
- Unfreeze: 2x (BacklogView:605, ContentView:1058)
- PendingIDs Insert: 2x (BacklogView:592, ContentView:1047)
- PendingIDs Clear: 2x (BacklogView:599, ContentView:1053)
- Timer Create: 2x (BacklogView:594, ContentView:1049)

### Agent 4: Szenarien
- **4 Trigger** pro Plattform: Importance, Urgency, Duration, Category
- **iOS Bug gefunden:** `updateCategory()` (Zeile 561) ruft `scheduleDeferredResort()` OHNE vorheriges `freezeSortOrder()` auf — macOS hat den Freeze korrekt
- Timer-Reset bei Rapid-Tapping korrekt implementiert
- CloudKit-Sync-Guard auf iOS blockiert Refresh waehrend Freeze (korrekt)

### Agent 5: Blast Radius
- **5-6 Core Files** betroffen: BacklogView, ContentView, BacklogRow, MacBacklogRow, beide App-Einstiegspunkte
- Behebt gleichzeitig **BACKLOG-011** (3 parallele Scoring-Pfade macOS) und **BACKLOG-012** (toter Wrapper)
- Bestehende Tests (DeferredSortBugTests, DeferredSortUITests, MacDeferredSortUITests, TaskJumpingBugProofTest) bleiben funktional
- `TaskPriorityScoringService` und `PlanItem.priorityScore` unberuehrt

---

## Hypothesen

### Hypothese 1: Extraktion in Shared DeferredSortController (REFACTORING)
**Beschreibung:** Kernlogik (freeze/unfreeze/timer/score-lookup) in `Sources/Services/DeferredSortController.swift` extrahieren. Beide Plattformen nutzen denselben Controller.

**Beweis DAFUER:**
- 95% identischer Code auf beiden Plattformen (verifiziert durch Agent 2+3)
- 2 Regressionen direkt durch Divergenz verursacht (Agent 1)
- Symmetrische Write-Locations bestaetigen identische Logik (Agent 3)

**Beweis DAGEGEN:**
- Unterschiedliche ID-Typen (String vs UUID) erfordern Generics oder Vereinheitlichung
- Post-Unfreeze-Verhalten unterscheidet sich (refreshLocalTasks vs @Query)
- Snapshot-Erstellung nutzt unterschiedliche Score-Quellen

**Wahrscheinlichkeit:** HOCH — das ist der richtige Ansatz

### Hypothese 2: Nur macOS an iOS angleichen (kein Shared Controller)
**Beschreibung:** macOS-Code 1:1 an iOS-Muster anpassen, aber weiterhin duplizierten Code behalten.

**Beweis DAFUER:**
- Einfacher umzusetzen, weniger Dateien betroffen
- Kein neuer Abstraction-Layer noetig

**Beweis DAGEGEN:**
- Loest das Grundproblem nicht — naechste Aenderung muss wieder auf beiden Plattformen gemacht werden
- Hat bereits 2x zu Regressionen gefuehrt (Agent 1)
- Widerspricht der Cross-Platform Code-Sharing Guideline in CLAUDE.md

**Wahrscheinlichkeit:** NIEDRIG — adressiert Symptom, nicht Ursache

### Hypothese 3: Score-Berechnung komplett in den Controller verschieben
**Beschreibung:** Nicht nur Freeze-State, sondern auch die Score-Berechnung (`calculateScore()` Aufrufe) in den Controller verlagern.

**Beweis DAFUER:**
- Wuerde BACKLOG-011 (3 parallele Scoring-Pfade) komplett loesen
- Single Source of Truth fuer Scores

**Beweis DAGEGEN:**
- Score-Berechnung ist view-abhaengig (iOS nutzt PlanItem.priorityScore, macOS nutzt calculateScore())
- Overengineering — der Controller soll State managen, nicht Business-Logik
- Blast Radius waere groesser (mehr Dateien, mehr Tests)

**Wahrscheinlichkeit:** MITTEL — teilweise sinnvoll, aber zu breit fuer dieses Ticket

---

## Gewaeholte Loesung: Hypothese 1 (Shared DeferredSortController)

**Warum nicht H2:** Behebt nicht die Duplikation, nur die Konsistenz. Naechste Aenderung erzeugt wieder Divergenz.

**Warum nicht H3:** Score-Berechnung ist plattform-spezifisch (PlanItem vs LocalTask). Der Controller soll Freeze-State kapseln, nicht die gesamte Score-Logik. BACKLOG-011 wird trotzdem teilweise geloest, weil `scoreFor()`/`effectiveScore()` den Controller nutzen.

---

## Fix-Ansatz

### Neuer Shared Controller: `Sources/Services/DeferredSortController.swift`

```swift
@MainActor @Observable
class DeferredSortController {
    private(set) var frozenScores: [String: Int]?
    private(set) var pendingIDs: Set<String> = []
    private var resortTimer: Task<Void, Never>?

    /// View baut Snapshot VOR der Daten-Aenderung und uebergibt ihn.
    /// Guard: Wenn bereits eingefroren, wird der bestehende Snapshot behalten.
    func freeze(scores: [String: Int]) {
        guard frozenScores == nil else { return }
        frozenScores = scores
    }

    /// Gibt frozen Score zurueck falls vorhanden, sonst den live Score.
    /// Views rufen diese Methode in Sort-Closures und Tier-Zuweisungen auf.
    func effectiveScore(id: String, liveScore: Int) -> Int {
        frozenScores?[id] ?? liveScore
    }

    /// Startet den 3s-Timer. Cancelt vorherigen Timer bei erneutem Aufruf.
    /// onUnfreeze: Plattform-spezifischer Callback (z.B. refreshLocalTasks auf iOS).
    func scheduleDeferredResort(id: String, onUnfreeze: (() async -> Void)? = nil) {
        pendingIDs.insert(id)
        resortTimer?.cancel()
        resortTimer = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                pendingIDs.removeAll()
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.4)) {
                frozenScores = nil
            }
            await onUnfreeze?()
        }
    }

    func isPending(_ id: String) -> Bool {
        pendingIDs.contains(id)
    }
}
```

**Wichtige Design-Entscheidungen:**

1. **`@MainActor`** — PFLICHT weil `withAnimation` auf dem MainActor laufen muss und
   der Task-Body in `scheduleDeferredResort` async ist. Ohne `@MainActor` gibt es
   Runtime-Warnings oder Compiler-Errors unter Swift 6 Concurrency.

2. **`@Observable` + `@Environment`** — Injection via `.environment(deferredSortController)` in
   der App-Root, Zugriff via `@Environment(DeferredSortController.self) var deferredSort` in Views.
   SwiftUI tracked Property-Reads automatisch — Views werden bei `frozenScores`/`pendingIDs`-Aenderungen
   neu gezeichnet weil sie diese Properties in Sort-Closures und `isPending()`-Checks LESEN.

3. **Snapshot-Erstellung bleibt in der View** — Die View baut den `[String: Int]`-Dict
   VOR dem Badge-Update und uebergibt ihn an `freeze(scores:)`. Reihenfolge:
   ```swift
   // In View (iOS oder macOS):
   deferredSort.freeze(scores: buildSnapshot())  // 1. Freeze VOR Update
   task.importance = newValue                      // 2. Daten aendern
   deferredSort.scheduleDeferredResort(id: task.id, onUnfreeze: { ... })  // 3. Timer starten
   ```

4. **Lebensdauer:** Controller lebt in der App-Root (FocusBloxApp/FocusBloxMacApp),
   ueberlebt View-Rebuilds und Navigation. Ein Controller pro Plattform.

**ID-Vereinheitlichung:** Alles auf `String` (task.id). Konkrete macOS-Migrationsstellen:
- ContentView:1006 — `scheduleDeferredResort(taskID: task.uuid)` → `deferredSort.scheduleDeferredResort(id: task.id)`
- ContentView:1012 — analog
- ContentView:1018 — analog
- ContentView:1024 — analog
- ContentView:1026 — `pendingResortIDs.contains(task.uuid)` → `deferredSort.isPending(task.id)`
- ContentView:1046 — Signatur `scheduleDeferredResort(taskID: UUID)` wird entfernt (im Controller: String)

**Plattform-spezifisch bleibt:**
- iOS: Snapshot aus `backlogTasks.map { ($0.id, $0.priorityScore) }`
- macOS: Snapshot aus `visibleTasks.filter { !$0.isNextUp }.map { ($0.id, calculateScore(...)) }`
- iOS: `onUnfreeze: { await refreshLocalTasks() }`
- macOS: `onUnfreeze: nil` (Query Auto-Update)

### Betroffene Dateien (5):
1. **NEU:** `Sources/Services/DeferredSortController.swift` (~50 LoC)
2. **BacklogView.swift:** ~50 LoC entfernt, ~20 LoC hinzugefuegt (Controller-Nutzung)
3. **ContentView.swift:** ~60 LoC entfernt, ~20 LoC hinzugefuegt + displayedRegularTasks entfernt + 6 UUID→String Migrationen
4. **FocusBloxApp.swift:** +3 LoC (Controller Instanz + Environment Injection)
5. **FocusBloxMacApp.swift:** +3 LoC (Controller Instanz + Environment Injection)

### Nebenbei gefixt:
- **iOS Category Bug:** `updateCategory()` (Zeile 561) bekommt `freeze(scores:)` Call VOR scheduleDeferredResort — bisher fehlte der Freeze, Bug ist latent (Category-Score-Aenderung ist gering, aber bei extremen Faellen sichtbar)
- **BACKLOG-012:** `displayedRegularTasks` Wrapper entfernt
- **BACKLOG-011 teilweise:** Alle Score-Lookups auf `deferredSort.effectiveScore()` vereinheitlicht

---

## Blast Radius
- `TaskPriorityScoringService` unberuehrt
- `PlanItem.priorityScore` unberuehrt
- Widget-Scoring unberuehrt
- Bestehende UI Tests funktional (testen UI-Verhalten, nicht Implementation)
- Unit Tests (DeferredSortBugTests) testen PlanItem-Score, nicht Freeze — unberuehrt

---

## Debugging-Plan (falls noetig)
Da dies ein Refactoring ist (kein Bug-Fix), ist der Beweis:
1. **Alle bestehenden Tests muessen nach Refactoring GRUEN sein**
2. **Build auf BEIDEN Plattformen muss erfolgreich sein**
3. **Grep nach alten Funktionsnamen** darf keine Treffer mehr zeigen (kein Dead Code)
