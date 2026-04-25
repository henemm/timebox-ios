# Bug #289 — Synthese-Analyse

**Bug:** macOS MenuBar-Popover zeigt Tasks, die im Hauptfenster unsichtbar sind. Abhaken tauscht Positionen statt zu entfernen.

---

## User-Erwartung (User Advocate)

> "Das Popover und das Hauptfenster sind synchron. Was ich nicht im Hauptfenster sehe, existiert nicht. Wenn ich abhake, ist es weg."

Beim User entsteht ein Vertrauensbruch: er weiss nicht mehr, welcher Stelle er trauen soll. User vermutet selbst: "Sind das Aufgaben die eigentlich nicht für heute gedacht sind und trotzdem auftauchen? Das würde bedeuten, das Popover filtert falsch."

→ **Genau das ist der Fall.**

---

## Root Cause

**`FocusBloxMac/MenuBarView.swift:25-31`** — Die zwei `@Query`-Deklarationen umgehen die zentrale Filter-Logik (`LocalTaskSource.fetchIncompleteTasks()`), die das Hauptfenster nutzt.

```swift
// IST (fehlerhaft):
@Query(filter: #Predicate<LocalTask> { !$0.isCompleted && $0.isNextUp })
private var nextUpTasks: [LocalTask]

@Query(filter: #Predicate<LocalTask> { !$0.isCompleted && !$0.isNextUp })
private var backlogTasks: [LocalTask]
```

Das Hauptfenster fetcht via `LocalTaskSource.fetchIncompleteTasks()` (Zeile 45):
```swift
return allIncomplete.filter { $0.isVisibleInBacklog && $0.lifecycleStatus != "raw" }
```

→ **Divergenz-Punkt:** `MenuBarView` greift direkt auf SwiftData zu. Dadurch fehlen:
- `isVisibleInBacklog == true` (filtert Templates + future-dated recurring)
- `lifecycleStatus != "raw"` (filtert Refiner-Tasks)
- `assignedFocusBlockID == nil` (filtert FocusBlock-zugewiesene Tasks)
- `blockerTaskID == nil` (filtert blockierte Sub-Tasks)

**KRITISCH (von Investigator 5 entdeckt):** `isVisibleInBacklog` ist eine **Computed Property** auf `LocalTask`. SwiftData `#Predicate` kann Computed Properties NICHT verwenden — der Fix muss als **Post-Fetch-Filter** in Swift implementiert werden (analog `LocalTaskSource.fetchIncompleteTasks()`).

---

## Sekundäres Symptom: "Tasks tauschen Position statt zu verschwinden"

**`FocusBloxMac/MenuBarView.swift:415-425`** — `toggleComplete()` ruft `syncEngine.completeTask()` synchron auf, ohne Refresh-Pfad.

Was bei Recurring passiert (von Investigator 2 ausgespurt):
1. User klickt Checkbox → `syncEngine.completeTask()`
2. SyncEngine setzt `isCompleted=true`, `isNextUp=false` auf Original-Task
3. **`RecurrenceService.createNextInstance()` legt sofort eine neue Instanz an** — diese hat `isCompleted=false`, `isNextUp=false`
4. Die neue Instanz besteht das unvollständige `@Query`-Predicate ebenfalls → erscheint sofort
5. Optisch wirkt es wie ein "Position-Tausch", obwohl der Task ausgetauscht wurde

Bei Templates (von Investigator 3 entdeckt): `SyncEngine.completeTask()` Zeile 158 hat `if task.isTemplate { return }` — Templates werden lautlos abgelehnt. UI bekommt keine Reaktion → Task bleibt sichtbar.

---

## ⚡ Spannungen / Auflösungen

**Spannung 1:** Investigator 3 vermutet `isTemplate`-Probleme (Templates kommen durchs Filter). Investigator 2 sagt: Es ist die fehlende `isVisibleInBacklog`-Prüfung. **Auflösung:** Beides stimmt — `isVisibleInBacklog` filtert Templates AUCH heraus (Zeile 86 in LocalTask). Der Filter `isVisibleInBacklog` ist die übergeordnete Lösung.

**Spannung 2:** Investigator 4 vermutet Sort-Race als Ursache des Position-Tausches. Investigator 2 sagt klar: neue Recurrence-Instanz ist die Ursache. **Auflösung:** Investigator 2's Erklärung passt zum Daten-Befund (Task ist `recurrencePattern=weekly`).

---

## Verwandter Bug

**Bug #287** ("Abhaken tauscht Task-Positionen statt zu entfernen") hat sehr wahrscheinlich **denselben Root Cause** — fehlender Post-Fetch-Filter in MenuBarView. Eine korrekte Lösung von #289 löst auch #287.

---

## Szenario-Matrix (Investigator 4)

| Szenario | Hauptfenster | Popover | Divergenz |
|----------|--------------|---------|-----------|
| recurring + dueDate=Zukunft | ❌ | ✅ | **JA** (Zehnagel) |
| lifecycleStatus="raw" | ❌ | ✅ | **JA** |
| isTemplate=true | ❌ | ✅ | **JA** |
| assignedFocusBlockID gesetzt | ❌ | ✅ | **JA** |
| recurring + dueDate=heute | ✅ | ✅ | nein |
| recurring + dueDate=nil | ✅ | ✅ | nein |

---

## Blast Radius (Investigator 5)

- **MenuBarView** wird nur von einem Ort konsumiert: `FocusBloxMacApp.swift:114`
- **Keine Tests** testen den @Query-Filter aktuell — `MenuBarIconStateTests` testet nur das Icon-Enum
- **Plattform-Parität:** Problem ist macOS-exklusiv. iOS nutzt `LocalTaskSource` direkt.
- Fix-Lokalisierung: 1 Datei, ~10-15 LoC. **Klein.**
- **Risiko:** Falls Fix versucht `isVisibleInBacklog` direkt in `#Predicate` einzubauen → Silent-Fail möglich (kein Crash, aber kein Filter wirkt). Fix MUSS Post-Fetch-Filter sein.

---

## Wahrscheinlichste Ursache (Synthese)

`MenuBarView` hat zwei separate, unvollständige `@Query`-Deklarationen, die zentrale Filter-Logik komplett umgehen. Der Fix:

1. `@Query` weiterhin nutzen für DB-Effizienz (`!isCompleted` ist Predicate-fähig)
2. **Post-Fetch-Filter** als computed property einführen, der `isVisibleInBacklog && lifecycleStatus != "raw" && assignedFocusBlockID == nil && blockerTaskID == nil` anwendet
3. Toggle-Handler: nach `completeTask()` braucht es keinen expliziten Refresh — SwiftData feuert das @Query automatisch. Das tatsächliche "Verschwinden" geschieht dann durch den Post-Fetch-Filter (neue Recurrence-Instanz hat Future-DueDate → `isVisibleInBacklog=false`)

---

## Affected Files (geplant)

- `FocusBloxMac/MenuBarView.swift` (Filter + ggf. Toggle)
- `FocusBloxTests/MenuBarFilterTests.swift` (NEU — Unit Test)

→ 1 Code-Datei + 1 Test-Datei. ±50 LoC.

---

**Status:** Analyse abgeschlossen. Bereit für Checkpoint 1.
