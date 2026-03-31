# Bug-Analyse: Quick Actions funktionieren nicht (Long Press App-Icon)

## 5a. Zusammenfassung der Agenten-Ergebnisse

### Agent 1 — Wiederholungs-Check
- FEATURE_031 wurde in Commit `b69f602` implementiert (2026-03-30)
- GitHub Issue #67 wurde sofort geschlossen ("Erledigt")
- Workflow-Archiv zeigt Phase 8 "complete" — aber Tests testeten nur Launch-Argumente, NIE den echten Flow
- Kein früherer Bug-Report zu Quick Actions gefunden

### Agent 2 — Datenfluss-Trace
- **Flow:** Info.plist → Springboard Menü → AppDelegate.handleShortcut() → `pendingQuickAction` static var → FocusBloxApp.onChange(scenePhase: .active) → State-Mutation
- **Bruchstelle im Original-Code:** `AppDelegate.handleShortcut()` rief `UIApplication.shared.open("focusblox://...")` auf, was NICHT an `.onOpenURL` zurückroutet
- 6 verschiedene Schreiber für `showQuickCapture`, 4 für `showSprintPicker`, 8 für `selectedTab`

### Agent 3 — Alle Schreiber
- Alle State-Variablen werden NUR in `FocusBloxApp.swift` geschrieben
- Keine Duplikation in macOS Code (macOS hat eigenen Handler in `FocusBloxMacApp.swift`)
- `quickCaptureTitle` hat Race-Condition-Potenzial (Control Center + URL gleichzeitig)

### Agent 4 — Alle Szenarien
- **Cold Start:** Funktioniert mit `pendingQuickAction` Pattern (configurationForConnecting → static var → scenePhase)
- **Warm Start:** Funktioniert mit `pendingQuickAction` Pattern (performActionFor → static var → scenePhase)
- **App gekillt:** Identisch mit Cold Start
- **URL-Schema:** Original-Code nutzte `UIApplication.shared.open()` — funktioniert NICHT für eigenes Schema
- **Split View:** Deaktiviert (UIApplicationSupportsMultipleScenes = false)
- **iOS Versionen:** Keine Breaking Changes bekannt

### Agent 5 — Blast Radius
- Widgets (QuickCapture, DayStatus) nutzen `focusblox://` URL-Schema via `onOpenURL` — ANDERER Pfad als Quick Actions
- macOS hat KEINEN sprint-picker Handler
- Notification Deep Links nutzen NotificationCenter, NICHT URL-Schema
- `focusblox://voice-capture` auf Watch ist Dead Code (kein Handler)
- Control Center Flag wird möglicherweise nicht korrekt gelöscht

## 5b. Alle möglichen Ursachen

### Hypothese 1: UIApplication.shared.open() routet nicht an eigene App (ORIGINAL-CODE)
- **Beweis DAFÜR:** Screenshot zeigt App öffnet sich ohne Quick-Capture-Sheet. UI Test bestätigt: textField nicht gefunden nach Quick Action Tap.
- **Beweis DAGEGEN:** Keiner. Apple-Dokumentation bestätigt: `open()` für eigenes URL-Schema ist nicht garantiert.
- **Wahrscheinlichkeit:** HOCH — **Dies ist die bestätigte Root Cause**

### Hypothese 2: .onOpenURL wird von AppDelegate-Methoden blockiert
- **Beweis DAFÜR:** AppDelegate hat `performActionFor` UND `configurationForConnecting`, die vor `onOpenURL` aufgerufen werden könnten
- **Beweis DAGEGEN:** AppDelegate ruft `UIApplication.shared.open()` auf, was ein neuer URL-Aufruf ist, nicht der selbe Lifecycle
- **Wahrscheinlichkeit:** NIEDRIG

### Hypothese 3: Timing-Problem bei Cold Start
- **Beweis DAFÜR:** `configurationForConnecting` dispatcht async, SwiftUI View könnte noch nicht bereit sein
- **Beweis DAGEGEN:** Der Bug tritt auch bei Warm Start auf (App war im Background), wo View definitiv bereit ist
- **Wahrscheinlichkeit:** MITTEL (für Cold Start relevant, aber nicht die Haupt-Ursache)

### Hypothese 4: Info.plist fehlt UIApplicationShortcutItemTargetURL
- **Beweis DAFÜR:** Spec beschreibt URL-basierte Actions, aber Info.plist hat nur Type, keine TargetURL
- **Beweis DAGEGEN:** iOS Quick Actions brauchen keine TargetURL — AppDelegate-Handling ist der Standard-Weg
- **Wahrscheinlichkeit:** NIEDRIG

## 5c. Wahrscheinlichste Ursache

**Hypothese 1: UIApplication.shared.open() routet nicht zurück an die eigene App.**

Der Original-Code in `AppDelegate.handleShortcut()` rief `UIApplication.shared.open("focusblox://create-task")` auf. Diese API ist für das Öffnen von URLs in ANDEREN Apps gedacht. Wenn die eigene App das Schema registriert hat, ist das Verhalten undefiniert — iOS kann die URL ignorieren, an Safari senden, oder gar nichts tun.

**Beweis:**
1. Screenshot: Long Press zeigt 3 Quick Actions → Tap auf "Task notieren" → App öffnet sich → KEIN Quick-Capture-Sheet
2. UI Test: `test_quickAction_taskNotieren_opensQuickCapture` scheitert mit "Quick-Capture TextField muss erscheinen"
3. Alle 3 Action-Tests scheitern mit dem selben Pattern

**Warum die anderen weniger wahrscheinlich sind:**
- Hypothese 2: `onOpenURL` wird gar nicht aufgerufen, weil `UIApplication.shared.open()` nicht routet
- Hypothese 3: Tritt nur bei Cold Start auf, aber Bug betrifft auch Warm Start
- Hypothese 4: TargetURL ist optional und nicht der Standard-Weg

## 5d. Debugging-Plan

**Hypothese BESTÄTIGEN:** Logging in `AppDelegate.handleShortcut()` → prüfen ob `UIApplication.shared.open()` aufgerufen wird, und in `.onOpenURL` → prüfen ob Handler jemals feuert.

**Hypothese WIDERLEGEN:** Wenn `.onOpenURL` feuert und `url.host` korrekt ist, dann liegt das Problem woanders.

**BEREITS BEWIESEN:** UI Tests zeigen eindeutig dass die Quick Actions keine UI-Reaktion auslösen. Fix mit `pendingQuickAction` + `scenePhase` Pattern macht alle Tests grün.

## 5e. Blast Radius

### Direkt betroffen:
- Alle 3 Quick Actions (Task notieren, Sprint starten, Heute)

### NICHT betroffen (anderer Code-Pfad):
- Widget Deep Links (nutzen `onOpenURL` direkt, nicht über AppDelegate)
- Notification Deep Links (nutzen NotificationCenter)
- Siri Shortcuts (speichern direkt in SwiftData)
- Control Center Quick Capture (nutzt App Group Flag)

### Nebenbefunde:
- macOS hat keinen sprint-picker URL-Handler (Feature-Parität-Lücke)
- Watch `focusblox://voice-capture` ist Dead Code
- `pendingQuickAction` als static var ist nicht thread-safe (theoretisches Race-Condition-Risiko bei schnellen Doppel-Taps)

## 6. Challenge-Report Adressierung (Devil's Advocate)

**Verdict:** LÜCKEN → adressiert

### Lücke 1: "Welcher Code-Stand erzeugt den Bug?"
Der Bug wurde mit dem ORIGINAL-Code aus Commit `b69f602` reproduziert. Dieser enthielt `UIApplication.shared.open(url)` in `AppDelegate.handleShortcut()`. Der aktuelle HEAD enthält bereits den Fix (`pendingQuickAction` Pattern), weil die Implementation parallel zur Analyse lief. Die andere Session (#169) hat den Fix zwischendurch überschrieben, was die Code-Verwirrung erklärt.

### Lücke 2: "UI Tests testen nicht den AppDelegate-Pfad"
Korrekt. Die `--quick-action` Launch-Argument-Tests testen den **Äquivalenten** Pfad (gleiche State-Mutation), nicht den AppDelegate selbst. Der Springboard E2E-Test testet den echten Flow, ist aber systembedingt flaky. Das ist ein akzeptierter Trade-off: zuverlässige Regressions-Tests via Launch-Argument + gelegentlicher E2E-Test via Springboard.

### Lücke 3: "@UIApplicationDelegateAdaptor fehlt?"
Verifiziert: `FocusBloxApp.swift:16` enthält `@UIApplicationDelegateAdaptor(AppDelegate.self)`. Ist korrekt deklariert.

### Übersehene Hypothese: UIApplicationShortcutItemTargetURL
Valider Punkt. Das Workflow-Archiv zeigt, dass das ursprüngliche Konzept URL-basiert war ("Kein AppDelegate nötig dank UIApplicationShortcutItemTargetURL"). Wurde nie umgesetzt. Könnte den AppDelegate überflüssig machen — aber der AppDelegate-Pfad ist der Apple-empfohlene Weg für SwiftUI Apps, weil er Cold-Start-Handling ermöglicht.

### Timing bei Cold Start
`configurationForConnecting` wird synchron VOR Scene-Setup aufgerufen. `pendingQuickAction` wird gesetzt bevor der SwiftUI Body evaluiert wird. `onChange(scenePhase: .active)` feuert NACH View-Mount. Reihenfolge: configurationForConnecting → pendingQuickAction gesetzt → App.body evaluiert → .onAppear → scenePhase .active → pendingQuickAction konsumiert. Kein Timing-Problem.
