# Bug-Analyse: macOS FocusBlock MenuBar nicht sichtbar + Sync

## Bug-Beschreibung

Hennings Worte: "Im FocusBlox: macOS: nicht sichtbar (war im Konzept anders vorgesehen). Kein Sync zwischen abgehakten/erledigten Items waehrend eines FokusBlox zwischen macOS und iOS."

Klaerung: "In der Spec stand, dass waehrend ein FokusBlox laeuft, dieses deutlich sichtbar sein soll. Tatsaechlich muss man aber auf das Menuebar Icon klicken um das festzustellen."

---

## 5a. Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (History)
- Commit 5c71089 (2026-02-16): FocusBlock-Status im Popover implementiert (Timer, Progress, Complete/Skip)
- Commit d6290d6 (2026-02-17): Bug 58 - MenuBarExtra durch NSStatusItem+NSPopover ersetzt
- **Kritisch:** Die Bug 58 Migration ersetzte MenuBarExtra (das dynamische Labels kann) durch NSStatusItem - dabei wurde das dynamische Label aus der Spec NIE implementiert
- Die Spec `menubar-focusblock-status.md` ist Status DRAFT (nie approved) und beschreibt noch MenuBarExtra-Code

### Agent 2 (Datenfluss)
- **Pfad 1 (Icon):** `MenuBarController.setup()` setzt `button.image = "cube.fill"` EINMALIG (Zeile 38-40). Kein Code aktualisiert das Icon danach.
- **Pfad 2 (Popover):** `MenuBarView.loadFocusBlock()` pollt EventKit alle 60s (idle) bzw. 1s (aktiver Block). Popover zeigt Status KORREKT.
- **Pfad 3 (Sync):** Task-Completion -> `FocusBlockActionService.completeTask()` -> EventKit + SwiftData save -> CloudKit export -> Remote NSPersistentStoreRemoteChange
- **Problem:** MenuBarView hat KEINEN Zugang zum `CloudKitSyncMonitor` (nicht injiziert in MenuBarController.setup())

### Agent 3 (Alle Schreiber)
- NSStatusItem.button: NUR 1 Schreibzugriff (FocusBloxMacApp.swift:38-40, einmalig)
- activeBlock: Geschrieben in MenuBarView:367, MacFocusView:425, FocusLiveView:483
- isCompleted: Geschrieben via SyncEngine.completeTask(), FocusBlockActionService.completeTask(), TaskInspector.toggle()
- **Problem:** TaskInspector nutzt `.toggle()` direkt statt SyncEngine -> umgeht RecurrenceService

### Agent 4 (Szenarien)
- 5 Szenarien fuer Problem 1 (Icon statisch): Alle = Code-Bug (Icon wird nie aktualisiert)
- 5 Szenarien fuer Problem 2 (Sync): Mischung aus Timing, fehlender Observation, Race Conditions
- Kritischstes Szenario: iOS hakt Task ab -> macOS MenuBar pollt 60s -> bis zu 60s Verzoegerung

### Agent 5 (Blast Radius)
- MenuBarController hat nur 1 Call-Site (FocusBloxMacApp:143-146)
- Wenn Icon dynamisch wird: `squareLength` -> `variableLength` noetig (Popover-Anker aendert sich)
- MenuBarView empfaengt `syncMonitor` NICHT (fehlt in Environment-Injection)
- Geschaetzer Aufwand: ~30-40 LoC, sehr lokalisiert

---

## 5b. ALLE moeglichen Ursachen

### Hypothese 1: NSStatusItem Icon wird nie dynamisch aktualisiert (HOCH)

**Beschreibung:** Das MenuBar-Icon wird beim App-Start einmalig auf `cube.fill` gesetzt und danach NIE geaendert, egal ob ein FocusBlock aktiv ist oder nicht.

**Beweis DAFUER:**
- `FocusBloxMacApp.swift:38-40`: `button.image = NSImage(systemSymbolName: "cube.fill")` - einmalige Zuweisung
- Grep nach `button.image`, `button.title`, `statusItem` in MenuBarController: KEINE weiteren Schreibzugriffe
- Die Spec (Acceptance Criteria 1+2) fordert dynamisches Label, wurde aber nie implementiert

**Beweis DAGEGEN:**
- Keiner. Der Code ist eindeutig: einmaliges Setup, keine Updates.

**Wahrscheinlichkeit:** HOCH (99%)

---

### Hypothese 2: Bug 58 Migration hat dynamisches Label verloren (HOCH)

**Beschreibung:** Die Spec beschreibt ein MenuBarExtra mit dynamischem Label (`Text(formatTime(remainingSeconds))`). Bug 58 ersetzte MenuBarExtra durch NSStatusItem. Dabei ging die dynamische Label-Faehigkeit verloren - nicht weil NSStatusItem es nicht kann, sondern weil es nie implementiert wurde.

**Beweis DAFUER:**
- Spec zeigt Code mit `MenuBarExtra { ... } label: { ... }` mit dynamischem Label
- Bug 58 Migration (commit d6290d6) fokussierte auf das Hidden-Bar-Problem, nicht auf das dynamische Label
- NSStatusItem KANN dynamisch aktualisiert werden (button.image und button.title sind aenderbar)

**Beweis DAGEGEN:**
- NSStatusItem hat andere API als MenuBarExtra - erfordert aktive Updates statt deklarativer Bindings

**Wahrscheinlichkeit:** HOCH (95%) - Das ist die Erklaerung WARUM Hypothese 1 besteht

---

### Hypothese 3: MenuBarView empfaengt kein CloudKit Sync Signal (MITTEL)

**Beschreibung:** Wenn ein Task auf iOS completed wird, synct CloudKit die Aenderung. macOS empfaengt NSPersistentStoreRemoteChange in CloudKitSyncMonitor. ABER: MenuBarView hat keinen Zugang zum syncMonitor und wird nicht ueber Sync-Events benachrichtigt.

**Beweis DAFUER:**
- `FocusBloxMacApp.swift:49-53`: MenuBarView wird erstellt mit `.modelContainer(container)` und `.environment(\.eventKitRepository, ...)` - ABER OHNE `syncMonitor`
- ContentView erhaelt syncMonitor (Zeile 124), MenuBarView nicht
- FocusBlock-Status kommt aus EventKit (nicht SwiftData) - @Query hilft hier nicht

**Beweis DAGEGEN:**
- SwiftData @Query fuer LocalTask sollte automatisch aktualisieren (isCompleted)
- FocusBlock.completedTaskIDs kommt aus EventKit notes - EventKit hat eigenen iCloud-Sync

**Wahrscheinlichkeit:** MITTEL (70%) - Betrifft Task-Liste im Popover, nicht den FocusBlock-Status

---

### Hypothese 4: EventKit Sync ist unabhaengig von CloudKit (NIEDRIG-MITTEL)

**Beschreibung:** FocusBlock-Daten (completedTaskIDs) werden in EKEvent.notes gespeichert und ueber iCloud Calendar Sync gesynct. Dies ist ein komplett separater Kanal von CloudKit/SwiftData. Der Sync koennte langsamer sein oder gar nicht funktionieren bei bestimmten Kalender-Konfigurationen.

**Beweis DAFUER:**
- FocusBlock speichert in `event.notes = "focusBlock:true\ntasks:...\ncompleted:..."` (EventKit)
- LocalTask.isCompleted in SwiftData/CloudKit (separater Kanal)
- Zwei Wahrheitsquellen die desynchronisieren koennen

**Beweis DAGEGEN:**
- iCloud Calendar Sync ist robust und schnell (in der Regel 1-5s)
- Beide Geraete nutzen denselben Calendar

**Wahrscheinlichkeit:** NIEDRIG-MITTEL (40%)

---

### Hypothese 5: Timer-Deadlock — loadFocusBlock() wird waehrend aktivem Block NIE aufgerufen (HOCH)

**Beschreibung:** Die Timer-Logik in MenuBarView hat einen strukturellen Deadlock:
- `activeTimer` (1s): Aktualisiert NUR `currentTime`, ruft NICHT `loadFocusBlock()` auf (Zeile 88-91)
- `pollingTimer` (60s): Hat `guard activeBlock == nil` (Zeile 93) — wird NICHT ausgefuehrt wenn ein Block aktiv ist

Das bedeutet: Sobald `activeBlock != nil`, wird `loadFocusBlock()` NIE MEHR automatisch aufgerufen. Aenderungen von iOS (completed Tasks) kommen auf macOS NIE an waehrend ein Block laeuft.

**Beweis DAFUER:**
- MenuBarView.swift:88-91: `onReceive(activeTimer)` → `guard activeBlock != nil` → nur `currentTime = time`
- MenuBarView.swift:92-94: `onReceive(pollingTimer)` → `guard activeBlock == nil` → `loadFocusBlock()` — ABER nur wenn kein Block aktiv!
- `loadFocusBlock()` wird nur in 3 Faellen aufgerufen: `.onAppear` (Zeile 87), `markTaskComplete` (Zeile 429), `skipTask` (Zeile 442)
- Wenn iOS einen Task abhakt, gibt es KEINEN Trigger der macOS zum Reload zwingt

**Beweis DAGEGEN:**
- @Query fuer LocalTask (nextUpTasks, backlogTasks) aktualisiert sich automatisch via SwiftData
- ABER: FocusBlock.completedTaskIDs kommt aus EventKit, NICHT SwiftData — @Query hilft hier nicht

**Wahrscheinlichkeit:** HOCH (95%) - Das ist der ECHTE Sync-Bug, unabhaengig vom Icon-Problem

---

## 5c. Wahrscheinlichste Ursachen (KORRIGIERT nach Devil's Advocate)

### Es sind ZWEI unabhaengige Bugs:

**Bug A: MenuBar Icon statisch (Hypothese 1+2)**
Das NSStatusItem Icon wird einmalig auf `cube.fill` gesetzt und nie geaendert. Die Spec forderte ein dynamisches Label, aber die Bug-58-Migration implementierte nur das Popover.

**Bug B: Timer-Deadlock verhindert EventKit-Refresh waehrend aktivem Block (Hypothese 5)**
Waehrend ein FocusBlock aktiv ist, wird `loadFocusBlock()` nie automatisch aufgerufen. Completed Tasks von iOS kommen im macOS Popover NIE an — nicht nach 60s, nicht nach 1s, UNBEGRENZT. Nur eigene Complete/Skip-Actions oder Popover-Schliessen/Oeffnen triggern einen Reload.

**Beide Bugs muessen unabhaengig gefixt werden.** Ein Fix am Icon behebt NICHT den Sync-Bug.

---

## 5d. Debugging-Plan

### Fuer Bug A (Icon statisch):

**Bestaetigung:** Kein Logging noetig - der Code ist eindeutig. `button.image` wird 1x gesetzt (Zeile 38-40), nie aktualisiert.

**Widerlegung:** Grep bestaetigt: KEINE andere Stelle setzt `button.image` oder `button.title`.

### Fuer Bug B (Timer-Deadlock):

**Bestaetigung:** In MenuBarView.swift:88-94 den Code lesen:
```swift
.onReceive(activeTimer) { time in
    guard activeBlock != nil else { return }  // Nur currentTime Update
    currentTime = time
}
.onReceive(pollingTimer) { _ in
    guard activeBlock == nil else { return }  // BLOCKIERT wenn Block aktiv!
    loadFocusBlock()
}
```
Der 1s-Timer aktualisiert nur die Uhrzeit (fuer den Countdown). Der 60s-Timer ist durch den Guard blockiert. Ergebnis: Kein EventKit-Refresh waehrend Block laeuft.

**Fix-Verifizierung:** Den activeTimer erweitern um periodisch `loadFocusBlock()` aufzurufen (z.B. alle 10-15s).

**Plattform:** macOS (Popover-Verhalten waehrend aktivem Block)

---

## 5e. Blast Radius

### Direkt betroffen:
- `FocusBloxMacApp.swift` - MenuBarController.setup() muss dynamische Updates ermoeglichen
- `MenuBarView.swift` - Muss StatusItem-Updates ausloesen wenn activeBlock sich aendert

### Mittelbar betroffen:
- Popover-Positionierung (wenn Button von Image zu Text wechselt, aendert sich `button.bounds`)
- NSStatusItem.squareLength muss zu variableLength werden

### NICHT betroffen:
- iOS App (komplett unabhaengig)
- macOS ContentView / MacFocusView (eigene Timer)
- Shared Services (FocusBlockActionService, SyncEngine)

### Aehnliche Patterns:
- Watch Complication koennte aehnliches Problem haben (nicht geprueft)
- iOS Widget / Live Activity hat eigene Implementierung (nicht betroffen)
