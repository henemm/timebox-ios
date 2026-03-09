# Bug Analysis: Sheet Dismiss Not Working on iOS

## Symptom
Beim Speichern (unter iOS) wird der Dialog nicht geschlossen. Betrifft mindestens Create und Edit Sheets. Bisher war das Verhalten anders und besser.

## Plattform
iOS (gemeldet), macOS nicht getestet

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 — Wiederholungs-Check
- Kein bisheriger Bug zu Sheet-Dismiss gefunden
- TD-02 Paket 2 (Commit `e8927d7`) hat CreateFocusBlockSheet und EventCategorySheet von inline in BlockPlanningView nach SharedSheets.swift extrahiert
- EditFocusBlockSheet und TaskFormSheet wurden NICHT veraendert

### Agent 2 — Datenfluss-Trace
- Alle Sheets nutzen `@Environment(\.dismiss) private var dismiss`
- CreateFocusBlockSheet: `onCreate(...)` → `dismiss()` (synchron)
- EditFocusBlockSheet: `onSave(...)` → `dismiss()` (synchron)
- TaskFormSheet (edit): `onSave?(...)` → `dismiss()` (synchron)
- TaskFormSheet (create): `Task { try await createTask(...) → await MainActor.run { dismiss() } }` (async)
- Alle Parent-Callbacks spawnen async `Task { ... await loadData() }` nach Return

### Agent 3 — Alle Schreiber
- `dismiss()` wird in JEDEM Sheet korrekt aufgerufen nach dem Callback
- Kein Sheet ueberspringt `dismiss()`
- TaskFormSheet create: `dismiss()` nur bei Erfolg, bei Fehler: `isSaving = false` (kein dismiss, kein Error-UI)

### Agent 4 — Alle Szenarien
- Alle Sheets verwenden NavigationStack + `.presentationDetents()`
- BlockPlanningView hat 4 `.sheet(item:)` Modifiers auf derselben View
- Parent-Callbacks loesen State-Mutationen aus (isLoading, planItems, focusBlocks)
- `loadData()` setzt `isLoading = true` was die gesamte Content-View austauscht

### Agent 5 — Blast Radius
- Betrifft: BlockPlanningView (4 Sheets), BacklogView (7 Sheets), TaskFormSheet (self-dismiss)
- Alle Sheets teilen das Pattern: NavigationStack + presentationDetents + dismiss()

## Hypothesen

### Hypothese 1: Parent State-Mutation waehrend Dismiss-Animation (HOCH)

**Beschreibung:** Die Callbacks (onCreate, onSave) loesen in den Parent-Views async Tasks aus, die `loadData()` aufrufen. `loadData()` setzt `isLoading = true`, was die GESAMTE Content-Hierarchy des Parent-Views austauscht (von `timelineContent` zu `ProgressView`). Wenn diese State-Mutation waehrend der Dismiss-Animation passiert, koennte SwiftUI die Animation abbrechen und das Sheet erneut praesentieren.

**Beweis DAFUER:**
- ALLE Parent-Callbacks spawnen `Task { await loadData() }` sofort nach Return
- `loadData()` setzt `isLoading = true` (BlockPlanningView:490, BacklogView:361)
- `isLoading = true` ersetzt den gesamten Body-Content (BlockPlanningView:28-55)
- Erklaert warum ALLE Sheets betroffen sind

**Beweis DAGEGEN:**
- `dismiss()` sollte das Binding (`selectedSlot`, etc.) sofort auf nil setzen
- Der async Task laeuft in einer separaten Execution-Queue
- Dieses Pattern hat "frueher funktioniert" (aber iOS 26.2 koennte das Timing geaendert haben)

**Wahrscheinlichkeit:** HOCH

### Hypothese 2: iOS 26.2 Regression NavigationStack + presentationDetents (MITTEL)

**Beschreibung:** iOS 26 fuehrte das "Liquid Glass" Design-System ein mit grundlegenden Aenderungen an NavigationStack und Sheet-Praesentation. Eine Regression in der Interaktion zwischen NavigationStack-inside-Sheet und `.presentationDetents()` koennte `dismiss()` blockieren.

**Beweis DAFUER:**
- ALLE betroffenen Sheets verwenden NavigationStack + presentationDetents
- User sagt "bisher war das Verhalten anders" — konsistent mit OS-Regression
- iOS 26 hat fundamentale UI-Aenderungen eingefuehrt

**Beweis DAGEGEN:**
- Kein konkreter Apple-Bug-Report bekannt
- Wuerde auch andere Apps betreffen (nicht nur FocusBlox)
- EditFocusBlockSheet hat sich nicht geaendert, war schon immer so gebaut

**Wahrscheinlichkeit:** MITTEL

### Hypothese 3: TD-02 Refactoring aenderte Dismiss-Kontext (NIEDRIG)

**Beschreibung:** TD-02 Paket 2 extrahierte CreateFocusBlockSheet und EventCategorySheet von inline-Definitions in BlockPlanningView.swift nach SharedSheets.swift. Die Extraktion koennte die `@Environment(\.dismiss)` Capture-Semantik veraendert haben.

**Beweis DAFUER:**
- Zeitlich korreliert: TD-02 war der letzte grosse Refactor vor dem Bug-Report
- Code wurde von inline zu separater Datei verschoben

**Beweis DAGEGEN:**
- `@Environment(\.dismiss)` wird von SwiftUI basierend auf Praesentation injiziert, nicht Datei-Location
- EditFocusBlockSheet und TaskFormSheet wurden NICHT veraendert, sind aber AUCH betroffen
- Wenn alle Sheets betroffen sind, kann es nicht an der Extraktion von 2 Sheets liegen

**Wahrscheinlichkeit:** NIEDRIG

### Hypothese 4: TaskFormSheet Create-Mode async Dismiss-Fehler (NIEDRIG)

**Beschreibung:** Im Create-Mode von TaskFormSheet wird `dismiss()` innerhalb eines async `Task { await MainActor.run { dismiss() } }` aufgerufen. Wenn `createTask()` fehlschlaegt, wird `dismiss()` NICHT aufgerufen (nur `isSaving = false` wird gesetzt, kein Error wird dem User gezeigt).

**Beweis DAFUER:**
- Silent Error Swallowing in Zeile 452-454
- Async Dismiss ist fragiler als synchroner Dismiss

**Beweis DAGEGEN:**
- Betrifft NUR den Create-Mode von TaskFormSheet
- Edit-Mode und andere Sheets haben synchronen Dismiss
- User sagt "alle" sind betroffen

**Wahrscheinlichkeit:** NIEDRIG (fuer das Gesamtproblem, koennte aber ein zusaetzlicher Bug sein)

### Hypothese 5: NavigationStack ueberlagert dismiss() Environment (HOCH) — Devil's Advocate

**Beschreibung:** Alle betroffenen Sheets wrappen ihren Content in NavigationStack. Die Picker-Sheets (DurationPicker, ImportancePicker, CategoryPicker) die KEIN NavigationStack haben und das Binding direkt auf nil setzen, sind NICHT betroffen. In iOS 26.2 koennte NavigationStack den `\.dismiss` Environment-Value ueberlagern, sodass `dismiss()` den NavigationStack-Kontext statt das Sheet schliesst.

**Beweis DAFUER:**
- ALLE betroffenen Sheets: NavigationStack + dismiss() + presentationDetents
- ALLE nicht-betroffenen Sheets (Pickers): KEIN NavigationStack, KEIN dismiss(), parent setzt Binding auf nil
- Perfekte Korrelation: NavigationStack = broken, kein NavigationStack = working
- Das ist ein bekanntes SwiftUI-Thema (NavigationStack overrides presentation dismiss)

**Beweis DAGEGEN:**
- In Standard-SwiftUI sollte dismiss() das naechste Presentation-Level schliessen (Sheet > NavigationStack)
- War bisher kein Problem in früheren iOS-Versionen

**Wahrscheinlichkeit:** HOCH

### Hypothese 6: onCreateComplete vor dismiss() im async Block (MITTEL-NIEDRIG)

**Beschreibung:** Im TaskFormSheet Create-Mode (Zeile 448-450):
```swift
await MainActor.run {
    onCreateComplete?()  // ERST Callback
    dismiss()            // DANN dismiss
}
```
Der Callback triggert `Task { await loadTasks() }` im Parent. Dieser Task koennte `isLoading = true` setzen BEVOR `dismiss()` verarbeitet wird.

**Wahrscheinlichkeit:** MITTEL-NIEDRIG (spezifisch nur fuer Create-Mode)

## Wahrscheinlichste Ursache

**Hypothese 5: NavigationStack ueberlagert dismiss() Environment (NEU nach Devil's Advocate)**

Begruendung: Die Korrelation ist perfekt:
- Sheets MIT NavigationStack + dismiss() → betroffen
- Sheets OHNE NavigationStack + direktes Binding-nil → NICHT betroffen

Dies erklaert warum ALLE Sheets betroffen sind UND warum die Pickers funktionieren.
Hypothese 1 (State-Mutation) ist fuer BacklogView-Edit widerlegt (refreshLocalTasks setzt isLoading NICHT), aber koennte ein verstaerkender Faktor in BlockPlanningView sein.

## Debugging-Plan

### Bestaetigung der Hypothese 1:
1. In `BlockPlanningView.createFocusBlock()`: Log vor dem `Task {}` und in `loadData()` bei `isLoading = true`
2. In `CreateFocusBlockSheet.createButton`: Log vor und nach `dismiss()`
3. **Erwartung wenn Hypothese stimmt:** `loadData()` -> `isLoading = true` wird geloggt BEVOR die Dismiss-Animation abgeschlossen ist
4. **Widerlegung:** Wenn die Logs zeigen, dass `dismiss()` vollstaendig abgeschlossen ist BEVOR `loadData()` startet

### Test-Ansatz (TDD RED):
1. UI Test: Sheet oeffnen → Speichern → Sheet muss verschwinden (timeout 3s)
2. Wenn der Test fehlschlaegt → Bug bestaetigt
3. Fix: `dismiss()` VOR dem Callback aufrufen, oder State-Mutation verzoegern

## Blast Radius

Betrifft:
- BlockPlanningView: CreateFocusBlockSheet, EditFocusBlockSheet, EventCategorySheet, FocusBlockTasksSheet
- BacklogView: TaskFormSheet (create + edit), TaskDetailSheet, DurationPicker, ImportancePicker, CategoryPicker
- Potentiell alle Sheets die NavigationStack + presentationDetents nutzen

## Fix-Ansatz (Vorschlag)

**Option A (EMPFOHLEN):** NavigationStack aus den Sheets entfernen. Stattdessen direkt den Content mit inline-Buttons rendern (wie die funktionierenden Picker-Sheets). Dies wuerde das dismiss()-Problem umgehen.

**Option B:** `dismiss()` durch explizites Binding-nil ersetzen. Statt `dismiss()` im Sheet, einen `onDismiss`-Callback zum Parent zurueckgeben der das Binding auf nil setzt. Wie bei den funktionierenden Picker-Sheets.

**Option C:** `dismiss()` ZUERST aufrufen, DANN den Callback — damit ist die Dismiss-Animation gestartet bevor State-Mutationen passieren.

**Option D:** In den Sheet-Views den `dismiss()` Aufruf durch eine explizite Presentation-Binding-Manipulation ersetzen (z.B. als Binding<Bool> oder Binding<Optional> Parameter an das Sheet uebergeben).
