# Bug-Analyse: Task-Completion Delay (Abhaken-Animation)

## Bug-Beschreibung
Wenn Tasks abgehakt werden (beliebige Liste, beliebiges OS), soll zuerst der gefüllte (abgehakte) Punkt dargestellt werden und erst danach (~3 Sek.) verschwindet der Task. User kann sofort weiterarbeiten.

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- **Kein vorheriger Bug** zu Completion-Delay. Feature ist NEU.
- **Existierendes Pattern:** `DeferredSortController` nutzt exakt 3-Sek-Freeze + Animation für Badge-Änderungen
- **Verwandt:** Bug Priority-Jump (frozenSortSnapshot) — gleicher Ansatz: visuell einfrieren, dann animieren
- **Undo-Feature** existiert (Shake iOS, Cmd+Z macOS) via `TaskCompletionUndoService`

### Agent 2: Datenfluss-Trace
- **iOS (BacklogView):** `completeTask()` → `SyncEngine.completeTask()` → `isCompleted = true` + `modelContext.save()` → `loadTasks()` → Task verschwindet sofort
- **macOS (ContentView):** `SyncEngine.completeTask()` → `@Query` auto-filtert → Task verschwindet sofort
- **Kein Delay, keine Animation** beim aktuellen Completion — nur Haptic-Feedback
- iOS nutzt manuelles `planItems`-Array, macOS nutzt `@Query`

### Agent 3: Alle Schreiber
- **8 direkte Schreibzugriffe** auf `isCompleted` in Produktion
- Hauptpfad: `SyncEngine.completeTask()` (iOS Backlog, macOS ContentView, MenuBar)
- Sekundärpfade: FocusBlockActionService, NotificationActionDelegate, CompleteTaskIntent, TaskInspector

### Agent 4: Alle Szenarien
- **iOS:** Tap auf Checkbox (BacklogRow), FocusBlock-Completion
- **macOS:** Tap auf Checkbox (MacBacklogRow), Context-Menu, MenuBar, TaskInspector
- **Weitere:** Notification-Action, Siri Intent
- **DeferredSortController existiert** mit exakt dem gewünschten Timing-Pattern

### Agent 5: Blast Radius
- **KRITISCH wenn `isCompleted` sofort gesetzt wird:** @Query (macOS) entfernt Task sofort, Sync-Race-Conditions, Recurring-Duplikate sichtbar
- **UNKRITISCH wenn Completion verzögert wird:** Kein Sync-Problem, keine Query-Inkonsistenz
- **Betroffene Subsysteme:** 12+ Dateien lesen `isCompleted`

## Hypothesen

### Hypothese 1: Verzögerter Datenschreib-Ansatz (EMPFOHLEN)
**Idee:** `isCompleted` wird NICHT sofort gesetzt. Stattdessen visueller "pending completion"-Zustand für 3 Sek., dann erst `SyncEngine.completeTask()`.

**Beweis DAFÜR:**
- Genau wie DeferredSortController: Visuell sofort ändern, Daten erst nach Delay
- Keine Sync-Inkonsistenzen (CloudKit sieht Task erst nach 3 Sek. als completed)
- Keine Recurring-Duplikate (neue Instanz erst nach 3 Sek. erstellt)
- Undo wird EINFACHER (Timer canceln statt Daten rückgängig machen)
- macOS `@Query` nicht betroffen (Task bleibt `isCompleted = false` bis Delay vorbei)

**Beweis DAGEGEN:**
- Wenn User App in 3 Sek. killt → Task nicht als erledigt gespeichert
- Gleiches Risiko wie DeferredSortController (akzeptiertes Pattern)

**Wahrscheinlichkeit:** HOCH (95%)

### Hypothese 2: Sofortiger Datenschrieb + UI-Overlay
**Idee:** `isCompleted = true` sofort setzen, aber Task in lokaler Overlay-Liste für 3 Sek. behalten.

**Beweis DAFÜR:**
- Sync sofort korrekt
- Recurring-Instanz sofort erstellt

**Beweis DAGEGEN:**
- macOS `@Query` entfernt Task sofort → Overlay nötig → komplex
- Inkonsistente Zähler während 3 Sek. (Badges springen)
- Undo interagiert mit Delay-Timer (Race Condition)

**Wahrscheinlichkeit:** MITTEL (30%)

### Hypothese 3: Reine Animation ohne Delay
**Idee:** Task sofort entfernen, aber mit eleganter Fade-Out-Animation.

**Beweis DAFÜR:**
- Keine State-Inkonsistenz
- Einfachste Implementierung

**Beweis DAGEGEN:**
- Erfüllt NICHT die Anforderung (User soll gefüllten Punkt SEHEN)
- Kein 3-Sek-Delay wie gewünscht

**Wahrscheinlichkeit:** NIEDRIG (nicht die Anforderung)

## Gewählter Ansatz: Hypothese 1

### Warum Hypothese 1?
1. **Gleicher Pattern wie DeferredSortController** — bewiesen, getestet, im Codebase
2. **Null Blast Radius** auf Sync, Queries, Recurring, Counters
3. **Undo wird einfacher** (Timer canceln = sofortige "Rücknahme")
4. **Plattformübergreifend identisch** (iOS und macOS gleicher Code-Pfad)

### Warum NICHT Hypothese 2?
- macOS @Query macht es komplex (Task verschwindet sofort trotz UI-Overlay)
- Race Conditions mit Undo + Timer
- Inkonsistente Badge-Counts während Delay

## Implementierungs-Skizze

### Neue State-Properties (BacklogView + ContentView):
```
pendingCompletionIDs: Set<String>  // Tasks die gerade "abgehakt" aussehen
completionTimer: Task<Void, Never>?  // 3-Sek Timer
```

### Flow:
```
1. User tappt Checkbox
2. → ID zu pendingCompletionIDs hinzufügen (mit Animation)
3. → Haptic Feedback
4. → Timer starten (3 Sek.)
5. → User kann sofort weiterarbeiten

6. Nach 3 Sek:
7. → syncEngine.completeTask() aufrufen (Daten, Sync, Recurring)
8. → ID aus pendingCompletionIDs entfernen
9. → Liste neu laden mit Animation → Task verschwindet smooth
```

### UI-Änderungen:
- **BacklogRow:** `isCompletionPending: Bool` → zeigt "checkmark.circle.fill" grün
- **MacBacklogRow:** `isCompletionPending: Bool` → zeigt Checkmark + Strikethrough

### Dateien (4):
1. `Sources/Views/BacklogRow.swift` — neues Prop, Checkbox-Icon
2. `Sources/Views/BacklogView.swift` — pendingCompletionIDs, Timer, modifizierter completeTask()
3. `FocusBloxMac/MacBacklogRow.swift` — neues Prop
4. `FocusBloxMac/ContentView.swift` — pendingCompletionIDs, Timer

### Geschätzt: ~±120 LoC

## Blast Radius
- **Sync:** KEIN Einfluss (Completion erst nach Timer → normaler Flow)
- **Recurring:** KEIN Einfluss (neue Instanz erst nach Timer erstellt)
- **Undo:** VEREINFACHT (Timer canceln statt Daten rückgängig)
- **Counters/Badges:** KEIN Einfluss (Task ist noch `isCompleted = false` während Delay)
- **FocusBlock/Notification/Siri:** Nicht betroffen (eigene Completion-Pfade ohne UI-Delay)
