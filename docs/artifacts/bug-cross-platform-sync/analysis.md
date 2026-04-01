# Bug-Analyse: Cross-Platform Sync — Tasks auf iOS abgehakt, macOS zeigt noch aktiv

## Symptom
Tasks wurden auf iOS als erledigt markiert. Nach 30 Minuten zeigt macOS diese Tasks immer noch als aktiv an.

## Architektur-Kontext

Die App nutzt **SwiftData + CloudKit** (`iCloud.com.henning.focusblox`). Sync-Mechanismus:
1. `SyncEngine.completeTask()` setzt `isCompleted=true`, `completedAt=Date()`
2. `modelContext.save()` → SwiftData exportiert automatisch via `NSPersistentCloudKitContainer`
3. Zielgerät empfängt `NSPersistentStoreRemoteChange` Notification
4. `CloudKitSyncMonitor.remoteChangeCount += 1`
5. Views reagieren via `.onChange(of: remoteChangeCount)` → `refreshTasks()`

**Beide Plattformen (iOS + macOS) nutzen denselben Mechanismus** — `remoteChangeCount` Observer ist in BacklogView (iOS, Zeile 357) UND ContentView (macOS, Zeile 226).

## Hypothesen

### Hypothese 1: macOS refresht Tasks NICHT bei App-Aktivierung (HOCH)

**Kern-Problem:** Wenn macOS in den Hintergrund geht und zurückkehrt, wird die Task-Liste NICHT neu geladen.

**Code-Beweis:**
- `FocusBloxMacApp.swift:437-442`: Bei `.active` wird `syncMonitor.triggerSync()` aufgerufen
- `triggerSync()` (`CloudKitSyncMonitor.swift:254-260`) macht nur `container.mainContext.save()` — das aktualisiert den Model-Context, aber ContentView's `@State tasks` Array bleibt stale
- ContentView hat KEINEN eigenen `scenePhase`-Observer
- ContentView refresht NUR bei: `.task` (erster Appear) und `onChange(of: remoteChangeCount)`
- **Wenn CloudKit-Daten während Background in den Persistent Store importiert wurden, sind sie nach `triggerSync()` im Context verfügbar — aber kein `fetch()` holt sie in die UI**

**Zeitlicher Ablauf des Bugs:**
1. iOS completed Tasks → CloudKit Export → CloudKit Import auf macOS Persistent Store
2. macOS war im Hintergrund → `NSPersistentStoreRemoteChange` feuerte → `remoteChangeCount` inkrementierte → aber SwiftUI-View war inaktiv, `onChange` lief möglicherweise nicht
3. macOS kommt zurück → `triggerSync()` → `save()` → Context hat neue Daten → aber `@State tasks` ist noch das alte Array
4. **Kein neuer `remoteChangeCount`-Increment → kein `refreshTasks()` → UI zeigt stale Daten**

**Beweis DAGEGEN:**
- Wenn macOS die ganze Zeit im Vordergrund war, sollte `onChange(of: remoteChangeCount)` sofort feuern
- Das 30-Minuten-Fenster könnte auch auf langsamen CloudKit-Transport hindeuten

### Hypothese 2: CloudKit-Transport auf macOS grundsätzlich langsamer (MITTEL)

**Beweis DAFÜR:**
- macOS hat aggressiveres Power-Management als iOS
- `NSPersistentCloudKitContainer` auf macOS kann Background-Fetch stärker drosseln
- Silent Push Notifications werden auf macOS anders priorisiert als auf iOS
- Das ist die vierte dokumentierte Sync-Problematik (Bug 38, 90, 102 → jetzt dieser)

**Beweis DAGEGEN:**
- 30 Minuten sind SEHR lang für CloudKit — normalerweise synct es in Sekunden bis wenigen Minuten
- Wenn grundsätzlich langsam, hätten andere User es gemeldet

### Hypothese 3: NSPersistentStoreRemoteChange feuert auf macOS nicht zuverlässig (MITTEL)

**Beweis DAFÜR:**
- Keine Logs zitiert die bestätigen dass die Notification auf macOS tatsächlich feuert
- Debug-Print in `CloudKitSyncMonitor.swift:107`: `"[CloudKit Debug] >>> NSPersistentStoreRemoteChange FIRED <<<"` — müsste im Console Output sichtbar sein
- Wenn die Notification nie feuert, bleibt `remoteChangeCount` bei 0 und ContentView refresht nie

**Beweis DAGEGEN:**
- `NSPersistentStoreRemoteChange` ist eine lokale Notification vom Persistent Store Coordinator — nicht netzwerkabhängig
- Sie feuert NACHDEM CloudKit Daten in den lokalen Store geschrieben hat
- Wenn CloudKit-Import funktioniert, feuert sie zuverlässig

### Hypothese 4: forceCloudKitFieldSync überschreibt iOS-Änderungen (SEHR NIEDRIG)

Ausgeschlossen — ist ein One-Time-Job (UserDefaults-Flag), berührt `isCompleted`/`completedAt` nicht.

---

## Wahrscheinlichstes Szenario (Kombination H1 + H2)

1. iOS completed Tasks → CloudKit Export funktioniert
2. macOS war im Hintergrund oder schlief → CloudKit Import kam verzögert
3. `NSPersistentStoreRemoteChange` feuerte auf macOS, `remoteChangeCount` inkrementierte
4. **ABER:** ContentView war nicht aktiv → `onChange` Handler lief nicht effektiv
5. macOS kam zurück in den Vordergrund → `triggerSync()` lief → **aber kein `refreshTasks()`**
6. Keine neue `NSPersistentStoreRemoteChange` → kein Refresh → UI stale

**Der Fix ist klar:** Wenn macOS in den Vordergrund kommt, MUSS `refreshTasks()` aufgerufen werden — als Sicherheitsnetz für alle Fälle wo der `remoteChangeCount`-Observer das Update nicht rechtzeitig mitbekommen hat.

## Debugging-Plan (BESTÄTIGUNG)

**Log prüfen:** macOS Console öffnen, nach `[CloudKit Debug]` filtern:
- `"NSPersistentStoreRemoteChange FIRED"` → Notification kam an
- `"remoteChangeCount incremented to X"` → Counter stieg
- Wenn KEINE solchen Logs → CloudKit-Import hat nicht stattgefunden

**Zum BESTÄTIGEN von H1:** macOS App starten → iOS Task abhaken → macOS in Hintergrund → 2 Min warten → macOS zurück → Task noch aktiv = BUG bestätigt. Dann macOS App neustarten → Task sollte als erledigt erscheinen.

## Blast Radius

| Bereich | Betroffen? | Grund |
|---------|-----------|-------|
| Alle Task-Felder (isNextUp, assignedFocusBlockID, etc.) | Ja | Gleicher fehlender Refresh bei App-Aktivierung |
| macOS `markTasksCompleted()` (Zeile 1063) | Ja (separater Bug) | Kein `refreshTasks()` nach lokaler Completion |
| MacFocusView, TaskInspector, MacPlanningView | Ja (separater Bug) | Kein Refresh nach lokaler Mutation |
| iOS | Nein | Gleicher Observer-Mechanismus, aber iOS-Apps werden bei Background aggressiver terminiert und bei Rückkehr neu gestartet (→ `.task` läuft erneut) |

## Architektur-Hinweis

Dies ist der **vierte** Sync-Fix (Bug 38 → 90 → 102 → jetzt). Das Pattern wiederholt sich: "Daten sind im Store, aber UI zeigt sie nicht". Ein zentrales "Refresh bei App-Aktivierung"-Pattern auf macOS würde alle diese Fälle auf einmal lösen.
