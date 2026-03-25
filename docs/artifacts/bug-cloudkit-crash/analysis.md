# Bug-Analyse: App crasht beim Start (CloudKit-Init)

## Symptom

App crasht sofort beim normalen Start (ohne `-UITesting`). EXC_BREAKPOINT/SIGTRAP in `PFCloudKitContainerProvider containerWithIdentifier:options:`. Betrifft iOS Simulator ohne iCloud-Account. Pre-existing seit Commit `5946410`.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 — Wiederholungs-Check
- Commit `165a2b1` fuehrte `.automatic` ein (Bug 38 Fix)
- Commit `5946410` aenderte `.automatic` zu `.private("iCloud.com.henning.focusblox")` fuer deterministische Sync
- Motivation: `.automatic` hatte undefiniertes Verhalten bei Schema-Aenderungen
- Kein bisheriger Fix fuer "App crasht bei fehlendem iCloud-Account"

### Agent 2 — Datenfluss-Trace
- `sharedModelContainer` ist lazy-evaluierte Closure (Zeilen 46-91)
- Branch A (UITesting): `.none` — sicher
- Branch B (AppGroup vorhanden): `.private(...)` — crasht wenn kein iCloud
- Branch C (AppGroup fehlt): `.private(...)` — crasht wenn kein iCloud
- **SIGTRAP ist kein Swift throws** — der catch-Block faengt es NICHT
- watchOS hat als EINZIGE Plattform einen Fallback zu `.none`

### Agent 3 — Alle Schreiber
- **13 ModelConfiguration-Instanzen** mit cloudKitDatabase in 6 Targets
- iOS App, macOS App, watchOS, iOS Share Extension, macOS Share Extension, Siri Intents
- Alle nutzen `.private("iCloud.com.henning.focusblox")`
- Nur watchOS hat Fallback

### Agent 4 — Crash-Szenarien
- **Hauptursache:** Kein iCloud-Account → `ubiquityIdentityToken == nil` → CloudKit-Init crasht
- `.private()` crasht weil es einen expliziten Container erwartet der ohne iCloud nicht erreichbar ist
- SIGTRAP wird intern von CloudKit ausgeloest, nicht als Swift Error
- iOS Share Extension hat zusaetzlich fehlende CloudKit-Entitlements (separater Bug)

### Agent 5 — Blast Radius
- Wenn CloudKit `.none`: Lokale Daten funktionieren, aber kein Sync zwischen Geraeten
- Widgets/Live Activities unberuehrt (nutzen UserDefaults, nicht SwiftData)
- Share Extensions + Siri Intents wuerden auch crashen (kein Fallback)

## Hypothesen

### Hypothese 1: Kein iCloud-Account auf Simulator (HOCH)
- **Dafuer:** Simulator hat standardmaessig keinen iCloud-Account. `.private()` versucht CloudKit zu kontaktieren → SIGTRAP
- **Dafuer:** UITesting-Modus (`.none`) funktioniert einwandfrei
- **Dafuer:** Crash-Report zeigt `PFCloudKitContainerProvider` als Crash-Ort
- **Dafuer:** watchOS hat genau diesen Fall abgefangen mit Fallback
- **Dagegen:** Nichts — alles passt zusammen
- **Wahrscheinlichkeit:** HOCH

### Hypothese 2: Container nicht provisioned im Simulator (MITTEL)
- **Dafuer:** Simulator-Builds haben nicht immer vollstaendiges Provisioning
- **Dagegen:** Entitlements sind korrekt konfiguriert in `FocusBlox.entitlements`
- **Dagegen:** Auf echtem Device mit iCloud funktioniert die App (Henning nutzt sie taeglich)
- **Wahrscheinlichkeit:** MITTEL (waere Neben-Ursache, nicht Haupt)

### Hypothese 3: Race Condition bei Container-Init (NIEDRIG)
- **Dafuer:** Crash ist in Thread 2, nicht Main Thread
- **Dagegen:** Crash passiert JEDES Mal, nicht intermittierend
- **Dagegen:** Crash-Stack zeigt klar CloudKit-Init, nicht Threading-Problem
- **Wahrscheinlichkeit:** NIEDRIG

## Wahrscheinlichste Ursache

**Hypothese 1: Kein iCloud-Account.** Der Code prueft `containerURL(forSecurityApplicationGroupIdentifier:)` aber NICHT `ubiquityIdentityToken`. Auf dem Simulator ist die App Group verfuegbar (Branch B wird genommen), aber CloudKit kann nicht initialisiert werden weil kein iCloud-Account existiert.

## Debugging-Plan

### Bestaetigung:
- `print(FileManager.default.ubiquityIdentityToken as Any)` vor CloudKit-Init einbauen
- Erwartung: Gibt `nil` aus auf Simulator → beweist fehlenden iCloud-Account

### Widerlegung:
- Wenn `ubiquityIdentityToken != nil` aber App trotzdem crasht → Container-Provisioning-Problem, nicht iCloud-Account

## Blast Radius

| Komponente | Impact bei Fix (.none Fallback) |
|------------|--------------------------------|
| iOS App | Laeuft lokal, kein Sync |
| macOS App | Gleiches Problem, gleicher Fix noetig |
| watchOS | Bereits abgesichert |
| Share Extensions | Separater Bug (fehlende Entitlements) |
| Siri Intents | Gleiches Problem |
| Widgets | Nicht betroffen |

## Fix-Ansatz (Vorschlag)

watchOS-Pattern auf iOS + macOS uebertragen:
1. `ubiquityIdentityToken` pruefen BEVOR `.private()` gesetzt wird
2. Wenn kein iCloud → `cloudKitDatabase: .none` (lokaler Speicher)
3. Bestehender try/catch als zweite Sicherheitslinie

**Betroffene Dateien:**
- `Sources/FocusBloxApp.swift` (iOS)
- `FocusBloxMac/FocusBloxMacApp.swift` (macOS)

**Scope:** 2 Dateien, ~10 LoC pro Datei
