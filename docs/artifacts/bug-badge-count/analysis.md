# Bug: Badge zeigt (8), erwartet 4 oder 9

## Symptom
- iOS App-Icon Badge zeigt **(8)**
- User sieht **4 ueberfaellige Tasks** und **5 Tasks fuer heute**
- Erwartung: Badge zeigt **4** (nur ueberfaellig) oder **9** (ueberfaellig + heute)

### Warum nicht 9?
Badge zaehlt NUR ueberfaellige Tasks: `dueDate < startOfToday`. Die 5 "heute" Tasks haben `dueDate == heute` (>= startOfToday), werden also vom Badge-Filter NICHT erfasst. Badge ist by-design "overdue only", nicht "overdue + today".

## Agenten-Ergebnisse

### Agent 1: History-Check
- Badge-Feature implementiert in Commit `b48ccb6`
- Keine bisherigen Badge-Count-Bugs bekannt
- Badge wurde als "overdue only" designed

### Agent 2: Datenfluss-Trace
- Badge wird in `NotificationService.updateOverdueBadge()` berechnet (NotificationService.swift:45-62)
- Trigger: App kommt in Vordergrund (scenePhase .active) + nach Notification-Action
- Formel: `dueDate != nil && !isCompleted && !isTemplate` → dann `dueDate < startOfToday`

### Agent 3: Alle Schreiber
- **Genau 1 Stelle** schreibt die Badge: `NotificationService.swift:58`
- **Genau 2 Call-Sites**: FocusBloxApp.swift:304 (foreground) + NotificationActionDelegate.swift:85 (action)

### Agent 4: Szenarien
- Badge wird NUR bei App-Foreground und nach Notification-Action aktualisiert
- Kein Midnight-Rollover, kein CloudKit-Sync-Update
- Keine Badge-Aktualisierung bei Task-Edit/Create/Delete in der App

### Agent 5: Blast Radius — KERNFUND
- **3 verschiedene Overdue-Zaehlungen mit unterschiedlichen Filtern!**

## Die Diskrepanz: Badge vs. UI

### Badge-Logik (NotificationService.swift:45-62):
```
Fetch: dueDate != nil && !isCompleted && !isTemplate
Filter: dueDate < startOfToday
→ Zaehlt ALLE ueberfaelligen Tasks
```

### BacklogView "Ueberfaellig" (BacklogView.swift:91-107):
```
backlogTasks: !isCompleted && !isNextUp && assignedFocusBlockID == nil
overdueTasks: backlogTasks.filter { dueDate < startOfToday }
→ Zaehlt nur ueberfaellige Tasks die NICHT in NextUp und NICHT einem FocusBlock zugewiesen sind
```

### Ergebnis:
| Was | Count | Filter |
|-----|-------|--------|
| Badge | **8** | Alle ueberfaelligen (inkl. NextUp + FocusBlock-zugewiesene) |
| UI "Ueberfaellig" | **4** | Nur Backlog-ueberfaellige (ohne NextUp, ohne FocusBlock) |
| Differenz | **4** | Tasks die ueberfaellig sind, aber in NextUp oder einem FocusBlock stecken |

## Hypothesen

### Hypothese 1: Badge zaehlt NextUp + FocusBlock-zugewiesene Tasks mit (HOCH)
- **Beweis DAFUER:** Badge-Filter hat `!isCompleted && !isTemplate`, aber NICHT `!isNextUp && assignedFocusBlockID == nil`. BacklogView hat genau diese zusaetzlichen Filter. Differenz: 8 - 4 = 4 Tasks stecken in NextUp/FocusBlocks.
- **Beweis DAGEGEN:** Koennte Zufall sein dass die Differenz genau 4 ist. Muesste mit echten Daten verifiziert werden.
- **Wahrscheinlichkeit:** HOCH — Code ist eindeutig

### Hypothese 2: Recurring-Instanzen werden doppelt gezaehlt (NIEDRIG)
- **Beweis DAFUER:** Erledigte recurring-Instanzen haben `isCompleted=true`, aber neue Instanzen koennten mit altem dueDate erstellt werden.
- **Beweis DAGEGEN:** `!isTemplate` schliesst Templates aus, und Instanzen bekommen korrekte Daten via RecurrenceService.
- **Wahrscheinlichkeit:** NIEDRIG

### Hypothese 3: Stale Badge wegen fehlendem Update-Trigger (NIEDRIG)
- **Beweis DAFUER:** Badge wird NICHT bei Task-Edit aktualisiert. Tasks koennten seit letztem App-Start verschoben worden sein.
- **Beweis DAGEGEN:** User hat die App gerade geoeffnet → Badge wird bei .active aktualisiert. Beide Zahlen (Badge + UI) spiegeln denselben Zeitpunkt.
- **Wahrscheinlichkeit:** NIEDRIG

### Hypothese 4: ModelContext-Divergenz zwischen Badge und UI (NIEDRIG)
- **Beweis DAFUER:** `updateOverdueBadge()` erstellt einen NEUEN `ModelContext(container)` (NotificationService.swift:46), waehrend die UI `mainContext` nutzt. Theoretisch koennten beide unterschiedliche Daten sehen (bekanntes SwiftData-Pattern, vgl. Bug 38).
- **Beweis DAGEGEN:** Der neue Context liest direkt vom Persistent Store. Bei App-Foreground sind pending Changes typischerweise bereits persistiert. Wuerde ausserdem zufaellige Schwankungen verursachen, nicht konsistente +4 Differenz.
- **Wahrscheinlichkeit:** NIEDRIG

### Hypothese 5: isVisibleInBacklog filtert zusaetzliche Tasks (IRRELEVANT)
- BacklogView nutzt `isVisibleInBacklog` via LocalTaskSource. Dieses Property filtert future-dated recurring instances (`dueDate >= startOfTomorrow`).
- **Fuer ueberfaellige Tasks irrelevant:** Wenn `dueDate < startOfToday`, dann ist `dueDate < startOfTomorrow` immer true → `isVisibleInBacklog` gibt true zurueck.
- Diese Hypothese entfaellt als Ursache fuer die Badge-Diskrepanz bei ueberfaelligen Tasks.

## Wahrscheinlichste Ursache

**Hypothese 1: Badge zaehlt breiter als die UI.**

Die Badge-Berechnung in `NotificationService.updateOverdueBadge()` filtert `!isNextUp` und `assignedFocusBlockID == nil` NICHT heraus, waehrend die BacklogView genau diese Filter hat.

4 von Hennings ueberfaelligen Tasks sind in NextUp oder einem FocusBlock zugewiesen → Badge zaehlt sie mit, UI-Ansicht "Ueberfaellig" nicht.

## Debugging-Plan (falls noetig)

Logging in `updateOverdueBadge()`:
```swift
let overdueAll = tasks.filter { $0.dueDate! < startOfToday }
for task in overdueAll {
    print("BADGE-DEBUG: \(task.title) isNextUp=\(task.isNextUp) block=\(task.assignedFocusBlockID ?? "nil")")
}
```
- **Bestaetigt:** Wenn 4 der 8 Tasks `isNextUp=true` oder `assignedFocusBlockID != nil` haben
- **Widerlegt:** Wenn alle 8 Tasks `isNextUp=false` und `assignedFocusBlockID == nil` haben

## Fix-Vorschlag

Badge-Berechnung an BacklogView-Logik angleichen — zusaetzliche Filter `!isNextUp` und `assignedFocusBlockID == nil` einbauen.

**Aenderung:** `NotificationService.swift:49-52` (1 Datei, ~2 Zeilen)

## Blast Radius
- macOS ContentView.swift:99-104 `overdueCount` nutzt `visibleTasks` (filtert `isVisibleInBacklog` aber NICHT `!isNextUp`) → Sidebar-Badge zaehlt NextUp-Tasks ebenfalls mit, allerdings weniger relevant da macOS kein App-Icon-Badge hat
- Die macOS `.overdue`-Ansicht (Zeile 295+) filtert korrekt `!task.isNextUp` → der eigentliche Overdue-Listeninhalt stimmt
- Kein anderer Code betroffen (NextUpSection, Timeline etc. nutzen eigene, korrekte Filter)
