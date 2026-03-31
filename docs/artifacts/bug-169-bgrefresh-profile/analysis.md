# Bug #169 Analyse: BGAppRefreshTask Dead Code + Profil-Beschreibung unklar

## Symptom
User erlebt keine Morning/Evening Notifications. Profil-Beschreibung in Settings ist unverständlich.

## Plattform
Beide (iOS + macOS)

---

## 5a. Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (Wiederholungs-Check)
- SmartNotificationEngine wurde in 4 Phasen implementiert (A-D), alle 2026-03-22/23
- Phase D (c97add0) fügte buildReviewRequests + buildNudgeRequests + Settings UI hinzu
- **Kein früherer Bug-Report für BGAppRefreshTask** — das Problem existiert seit Phase A
- Verwandte Bugs: BUG_90 (Delegate in init statt onAppear), BUG_55 (End-Notification 0/0), BUG_115/118 (Test-Anpassungen)

### Agent 2 (Datenfluss-Trace)
- BGAppRefreshTask registriert in `FocusBloxApp.requestPermissionsOnLaunch()` (Zeile 451)
- Handler macht NUR `setTaskCompleted(success: true)` — kein reconcile()
- reconcile() hat 2 Overloads (ModelContainer + ModelContext), 20+ Aufrufer
- **Info.plist fehlt `BGTaskSchedulerPermittedIdentifiers`** — BGTask wird vom System nie ausgeführt!
- Reconcile-Kette: reconcile → buildAllRequests → buildTimerRequests + buildTaskRequests + buildReviewRequests + buildNudgeRequests

### Agent 3 (Alle Schreiber)
- `notificationProfileRaw` geschrieben von: SettingsView Picker (iOS), MacSettingsView Picker (macOS)
- Beide haben `onChange` → reconcile(reason: .profileChanged)
- `registerBackgroundTask()` aufgerufen: 1x in FocusBloxApp.swift Zeile 451
- `scheduleBackgroundRefresh()` aufgerufen: 1x in FocusBloxApp.swift Zeile 452
- reconcile(): 20 Aufrufer in 11 Dateien

### Agent 4 (Alle Szenarien)
13 Szenarien identifiziert:
1. Profil "quiet" → kein Review/Morning
2. App nie geöffnet → kein reconcile
3. Permissions nicht erteilt
4. App nach 20:00 → Evening vorbei
5. **BGTask Handler ohne reconcile** (Kern-Bug)
6. App im Background sofort suspended → add() nicht fertig
7. macOS: kein BGAppRefreshTask
8. Zweite Öffnung nach 20:00 → removeAll löscht Evening ohne Neuplanung

### Agent 5 (Blast Radius)
- 3 Dateien betroffen: SmartNotificationEngine.swift, SettingsView.swift, MacSettingsView.swift
- ~35 LoC geschätzt
- Keine Seiteneffekte auf bestehende reconcile()-Aufrufer
- Kein anderer Stub-Dead-Code gefunden

---

## 5b. ALLE möglichen Ursachen

### Hypothese 1: BGAppRefreshTask-Handler ruft reconcile() nicht auf
- **Beschreibung:** Der Handler in Zeilen 413-417 macht nur `setTaskCompleted(success: true)`. Wenn iOS den Task im Hintergrund ausführt, werden keine Notifications geplant.
- **Beweis DAFÜR:** Code ist eindeutig — Zeile 416 ist der einzige Statement im Handler. Kein reconcile()-Aufruf.
- **Beweis DAGEGEN:** Keiner. Der Code ist offensichtlich unvollständig.
- **Wahrscheinlichkeit:** HOCH (100% — Code-Beweis)

### Hypothese 2: Info.plist fehlt BGTaskSchedulerPermittedIdentifiers
- **Beschreibung:** Der Identifier `com.henning.focusblox.notification-refresh` ist nicht in Info.plist unter `BGTaskSchedulerPermittedIdentifiers` registriert. iOS führt den BGTask daher nie aus.
- **Beweis DAFÜR:** Agent 2+3 haben Info.plist durchsucht — nur `remote-notification` in UIBackgroundModes, kein `BGTaskSchedulerPermittedIdentifiers` Array.
- **Beweis DAGEGEN:** Möglicherweise ist der Eintrag im Xcode-Projekt unter Capabilities gesetzt (nicht in Info.plist direkt).
- **Wahrscheinlichkeit:** HOCH — muss verifiziert werden

### Hypothese 3: Profil-Beschreibung ist unklar → User weiß nicht was er bekommt
- **Beschreibung:** Footer-Text "Leise: nur Sprint-Timer. Ausgeglichen: Timer + Fristen + Tagesreview. Aktiv: alle inkl. Motivations-Nudges." ist kryptisch.
- **Beweis DAFÜR:** Henning hat es explizit als unverständlich gemeldet
- **Beweis DAGEGEN:** Keiner
- **Wahrscheinlichkeit:** HOCH (User-Feedback = Beweis)

### Hypothese 4: macOS hat keinen Background-Reconcile-Mechanismus
- **Beschreibung:** `#if !os(macOS)` schließt BGAppRefreshTask aus. macOS hat keine Alternative.
- **Beweis DAFÜR:** Code ist klar — macOS reconcile() nur bei scenePhase-Changes
- **Beweis DAGEGEN:** macOS-Apps laufen typischerweise länger im Hintergrund, scenePhase .background triggert reconcile
- **Wahrscheinlichkeit:** MITTEL — macOS-Apps bleiben oft offen, Problem ist weniger akut

---

## 5c. Wahrscheinlichste Ursachen

**Primär:** Hypothese 1 + 2 zusammen — BGAppRefreshTask ist doppelt broken:
1. Handler ist ein leerer Stub (kein reconcile)
2. Info.plist-Registrierung fehlt möglicherweise (iOS führt Task nie aus)

**Sekundär:** Hypothese 3 — UX-Problem unabhängig von Logik-Bug

**Hypothese 4 (macOS)** ist weniger kritisch, weil macOS-Apps typischerweise länger laufen und bei jedem Foreground/Background-Wechsel reconcile() aufgerufen wird.

---

## 5d. Debugging-Plan

### Hypothese 1+2 bestätigen:
- **Logging:** Im BGAppRefreshTask-Handler ein `print("BGAppRefreshTask: fired at \(Date())")` einbauen
- **Info.plist prüfen:** Xcode-Projekt öffnen → Signing & Capabilities → Background Modes prüfen
- **Bestätigung:** Wenn nach App-Kill und Warten kein Log-Eintrag kommt → Info.plist fehlt
- **Wenn Log kommt aber keine Notifications:** Handler-Stub ist die Ursache

### Hypothese 3 bestätigen:
- Direkt bestätigt durch Hennings Feedback — kein Debugging nötig

---

## 5e. Blast Radius

### Direkt betroffen:
- Morning Notification (08:00) — kommt nicht ohne App-Start
- Evening Notification (20:00) — kommt nicht ohne App-Start nach letztem reconcile
- Nudge Notifications (9-19 Uhr, nur "Aktiv") — kommen nicht im Background

### Indirekt betroffen:
- Focus Block Timer werden bei Background-Reconcile ebenfalls nicht aktualisiert (falls Blöcke extern geändert werden)
- DueDate-Reminders werden im Background nicht aktualisiert

### Nicht betroffen:
- Alle Foreground-Reconcile-Pfade funktionieren korrekt
- Notification-Actions (NextUp, Postpone, Complete) funktionieren
- Profil-Wechsel triggert korrekt reconcile

---

## 5f. Challenge-Report Erkenntnisse (Devil's Advocate)

**Verdict: LÜCKEN — nachfolgend eingearbeitet**

### Übersehene Hypothese 5: buildReviewRequests() plant nur heute/morgen
- **Beschreibung:** `buildReviewRequests()` plant Evening nur für HEUTE 20:00 und Morning nur für MORGEN 08:00 — beide `repeats: false`. Nach 24-48h ohne App-Öffnung (und ohne BGTask) sind alle Review-Notifications abgefeuert, und keine neuen werden geplant.
- **Beweis DAFÜR:** Code Zeilen 316-351 — nur 2 Notifications (heute + morgen), keine Vorausplanung
- **Konsequenz:** Auch MIT korrekt implementiertem BGTask-Handler würde das Problem nur teilweise gelöst, wenn der BGTask nicht regelmäßig feuert
- **Fix:** Mehrere Tage im Voraus planen (z.B. 7 Tage = 14 Slots, Budget erlaubt das)
- **Wahrscheinlichkeit:** HOCH

### Übersehene Hypothese 6: scheduleBackgroundRefresh() wird nie re-scheduled
- **Beschreibung:** `scheduleBackgroundRefresh()` wird nur einmalig beim App-Start aufgerufen (FocusBloxApp Zeile 452). Der BGTask-Handler ruft es nicht erneut auf → iOS führt den Task nur EINMAL aus, dann nie wieder.
- **Beweis DAFÜR:** Im Handler (Zeilen 413-417) gibt es keinen Aufruf von `scheduleBackgroundRefresh()`
- **Konsequenz:** Selbst mit korrektem Handler feuert der BGTask nur einmal nach App-Start
- **Fix:** Handler muss am Ende `scheduleBackgroundRefresh()` aufrufen (Self-Rescheduling)
- **Wahrscheinlichkeit:** HOCH

### Korrektur zu Hypothese 2 (Info.plist)
- **Bestätigt:** Info.plist enthält KEIN `BGTaskSchedulerPermittedIdentifiers`. Auch kein Eintrag in FocusBlox.entitlements oder project.pbxproj. Das ist keine Hypothese mehr, sondern Tatsache.

### Korrektur der Ursachen-Priorisierung

**Primäre Root Cause (korrigiert):** Hypothese 5 — buildReviewRequests plant nur 1-2 Notifications für das unmittelbare Zeitfenster. Das erklärt warum AUCH User die die App täglich öffnen Notifications verpassen (z.B. letztes reconcile nach 20:00 → Evening weg, Morning für morgen geplant, aber übermorgen nicht).

**Sekundär:** Hypothesen 1+2+6 zusammen — BGAppRefreshTask ist dreifach broken:
1. Info.plist fehlt → Task wird nie ausgeführt
2. Handler ist Stub → selbst wenn ausgeführt, passiert nichts
3. Kein Re-Scheduling → Task feuert nur einmal

**Tertiär:** Hypothese 3 — UX-Problem (Profil-Beschreibung)

---

## Fix-Vorschlag (aktualisiert nach Challenge)

### Fix 1: buildReviewRequests() — Mehrere Tage im Voraus planen
**Datei:** `Sources/Services/SmartNotificationEngine.swift` Zeilen 311-354
**Änderung:** Statt nur heute/morgen → 7 Tage Morning + 7 Tage Evening planen (14 Slots, Budget budgetReview muss von 2 auf 14 erhöht werden)
**Call-Site:** Wird von buildAllRequests() aufgerufen (Zeile 93, 233) — bereits aktiv
**Warum:** Das ist die eigentliche Root Cause. Selbst mit BGTask-Fix wäre das Problem nicht gelöst.

### Fix 2: BGAppRefreshTask komplett reparieren
**Datei:** `Sources/Services/SmartNotificationEngine.swift` Zeilen 409-431
**Änderungen:**
1. Handler muss reconcile() aufrufen (braucht container + eventKitRepo als statische Properties)
2. Handler muss am Ende `scheduleBackgroundRefresh()` aufrufen (Self-Rescheduling)
3. Info.plist: `BGTaskSchedulerPermittedIdentifiers` Array + `fetch` in UIBackgroundModes hinzufügen
**Call-Site:** iOS ruft den Handler auf wenn BGTaskScheduler den Task ausführt

### Fix 3: Profil-Beschreibung verbessern
**Dateien:** `Sources/Views/SettingsView.swift`, `FocusBloxMac/MacSettingsView.swift`
**Änderung:** Footer-Text durch verständliche Beschreibung mit konkreten Zeitangaben ersetzen

### Geschätzte Änderungen:
- 3 Swift-Dateien (SmartNotificationEngine.swift, SettingsView.swift, MacSettingsView.swift)
- Info.plist (BGTaskSchedulerPermittedIdentifiers + UIBackgroundModes)
- ~60-70 LoC
- Budget-Konstante budgetReview: 2 → 14
