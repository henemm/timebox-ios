# Bug 102: Coach-Sync iOS↔macOS — Analyse

## Symptom

Coach-Wahl auf iPhone (z.B. Troll) wird auf dem Mac nicht angezeigt. CoachBacklogView auf macOS zeigt keine Schwerpunkt-Sektion, Monster-Header bleibt leer.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- **Kein bisheriger Fix-Versuch** fuer Coach-Sync. Bug ist neu.
- SyncedSettings existiert seit Bug 38 (Feb 2026) fuer allgemeine Settings.
- Coach-Keys (`sync_selectedCoach`, `sync_selectedCoachDate`) wurden proaktiv hinzugefuegt.
- Push/Pull-Logik fuer Coach ist in SyncedSettings implementiert (Zeilen 94-96, 148-154).
- **Aber: Nie end-to-end getestet oder verifiziert.**

### Agent 2: Datenfluss-Trace
- **Dual-Storage:** DailyCoachSelection speichert in App Group (`dailyCoach_YYYY-MM-DD`) UND in `UserDefaults.standard` (`selectedCoach`).
- SyncedSettings synct NUR `UserDefaults.standard` → iCloud KV Store.
- App Group Defaults werden NICHT synced.
- Views nutzen `@AppStorage("selectedCoach")` (reaktiv) oder `DailyCoachSelection.load()` (nicht reaktiv).

### Agent 3: Alle Schreiber
- 8 Schreibstellen gefunden. Primaer: `MorningIntentionView.saveSelection()`.
- SetDailyIntentionIntent (Siri) ruft NICHT `pushToCloud()` auf — nur lokaler Save.
- `BacklogView.clearCoachFilter()` setzt `selectedCoach = ""` ohne `selectedCoachDate` zu aendern.

### Agent 4: Szenarien
- Kritische Luecke: **Kein expliziter `pullFromCloud()` beim App-Start/Resume.**
- `scenePhase .active` ruft NUR `pushToCloud()`, nicht `pullFromCloud()`.
- cloudDidChange-Notification kommt asynchron — kann NACH pushToCloud() feuern.
- Race Condition: macOS pushed leere Werte bevor iCloud-Daten ankommen.

### Agent 5: Blast Radius
- 3 UI-Surfaces betroffen: CoachBacklogView, MacCoachBacklogView, MorningIntentionView.
- NotificationService akzeptiert Coach-Parameter — wird korrekt weiterarbeiten.
- `coachModeEnabled` wird NICHT gesynced (separates Problem, nicht Bug 102).
- Moderate Blast Radius — bestehende Views nutzen @AppStorage und rendern reaktiv.

## Ueberlappung der Ergebnisse

Alle 5 Agenten konvergieren auf denselben Befund: **SyncedSettings hat Push/Pull-Logik fuer Coach, aber pullFromCloud() wird nie proaktiv aufgerufen.** Gleichzeitig pushed pushToCloud() bedingungslos leere Werte und ueberschreibt damit Remote-Daten.

---

## Hypothesen

### Hypothese 1: Race Condition — pushToCloud() ueberschreibt Remote-Daten mit leeren Werten
**Wahrscheinlichkeit: HOCH**

**Ablauf:**
1. iPhone: User waehlt Troll → `pushToCloud()` → iCloud hat `sync_selectedCoach = "troll"`, `sync_selectedCoachDate = "2026-03-14"`
2. macOS: App oeffnet → `SyncedSettings.init()` → `cloud.synchronize()` (async, nicht-blockierend)
3. macOS: `.active` feuert → `pushToCloud()` liest lokale UserDefaults → `selectedCoach = ""`, `selectedCoachDate = ""`
4. macOS pushed `""` und `""` nach iCloud → **UEBERSCHREIBT iPhones "troll"**
5. Spaeter: `cloudDidChange` feuert → `pullFromCloud()` → aber iCloud hat jetzt `""` (von macOS ueberschrieben)

**Beweis DAFUER:**
- `SyncedSettings.swift` Zeile 95: `cloud.set(defaults.string(forKey: LocalKey.selectedCoach) ?? "", ...)` — pushed IMMER, auch leere Strings
- `FocusBloxMacApp.swift` Zeile 320: `syncedSettings.pushToCloud()` ohne vorheriges Pull
- `NSUbiquitousKeyValueStore.synchronize()` ist nicht-blockierend → Notification kommt asynchron

**Beweis DAGEGEN:**
- Wenn macOS's cloudDidChange VOR `.active` feuert, wuerde pullFromCloud() die Remote-Werte holen und pushToCloud() wuerde korrekte Werte pushen. Aber das Timing ist nicht garantiert.

### Hypothese 2: Kein expliziter pullFromCloud() beim App-Start
**Wahrscheinlichkeit: HOCH (gleiche Root Cause, anderer Blickwinkel)**

**Ablauf:**
- `SyncedSettings.init()` (Zeile 46-57): Ruft NUR `cloud.synchronize()` und registriert Observer.
- Ruft NICHT `pullFromCloud()` auf.
- macOS startet → liest lokale UserDefaults → `selectedCoach = ""` → zeigt leeren Header.
- Erst wenn `didChangeExternallyNotification` feuert (asynchon, unbestimmte Verzoegerung), wuerde pullFromCloud() aufgerufen.

**Beweis DAFUER:**
- `SyncedSettings.init()` hat KEINEN `pullFromCloud()` Aufruf (Zeile 46-57 verifiziert)
- FocusBloxApp.swift Zeile 319: Nur `pushToCloud()`, kein `pullFromCloud()`
- FocusBloxMacApp.swift Zeile 320: Nur `pushToCloud()`, kein `pullFromCloud()`

**Beweis DAGEGEN:**
- Wenn der Observer zuverlaessig und schnell feuert, wuerde pullFromCloud() frueh genug aufgerufen. Aber Apple-Docs geben keine Timing-Garantie.

### Hypothese 3: Siri-Intent pushed nicht nach iCloud
**Wahrscheinlichkeit: MITTEL (separater Bug, nicht das Hauptproblem)**

**Ablauf:**
- `SetDailyIntentionIntent.perform()` ruft `selection.save()` aber NICHT `pushToCloud()`.
- Wenn Coach via Siri gewaehlt wird, ist es nur lokal gespeichert.
- Naechster `.active`-Trigger pushed, aber bis dahin koennte die andere Plattform schon gepulled haben.

**Beweis DAFUER:**
- `SetDailyIntentionIntent.swift` Zeile 19: Nur `.save()`, kein `pushToCloud()`.

**Beweis DAGEGEN:**
- Naechster `.active`-Trigger pushed die Daten trotzdem. Verzoegerung, aber kein Datenverlust.

### Hypothese 4: App Group vs. UserDefaults Desync
**Wahrscheinlichkeit: NIEDRIG**

- `DailyCoachSelection.load()` liest aus App Group.
- `@AppStorage("selectedCoach")` liest aus standard UserDefaults.
- SyncedSettings.pullFromCloud() schreibt NUR in standard UserDefaults, NICHT in App Group.
- `CoachMeinTagView` nutzt `DailyCoachSelection.load()` → bekommt leere Daten trotz Sync.

**Beweis DAFUER:**
- `pullFromCloud()` Zeile 152: Schreibt in `defaults` (standard), nicht in App Group.
- `CoachMeinTagView.swift` Zeile 42: Liest `DailyCoachSelection.load()` → liest App Group.

**Beweis DAGEGEN:**
- Das Hauptsymptom (MacCoachBacklogView zeigt leeren Header) nutzt `@AppStorage("selectedCoach")`, nicht App Group. Betrifft andere Views.

---

## Wahrscheinlichste Ursache(n)

**Hypothesen 1 + 2 zusammen = Root Cause.**

Die Kombination aus:
1. Kein proaktives `pullFromCloud()` beim App-Start → lokale Werte sind leer
2. Unbedingtes `pushToCloud()` auf `.active` → ueberschreibt Remote-Werte mit leeren Strings

ergibt: **macOS ueberschreibt iPhones Coach-Wahl in iCloud bei jedem App-Start.**

**Warum Hypothese 3 weniger wahrscheinlich:** Siri ist nicht der primaere Weg um den Coach zu waehlen. Das Hauptproblem tritt beim normalen Flow (MorningIntentionView → iPhone → macOS) auf.

**Warum Hypothese 4 weniger wahrscheinlich:** Das berichtete Symptom betrifft MacCoachBacklogView, die @AppStorage nutzt — nicht DailyCoachSelection.load().

---

## Debugging-Plan (Beweisfuehrung)

### Zum BESTAETIGEN der Top-Hypothese:

1. **Logging in `pushToCloud()`** (SyncedSettings.swift Zeile 95):
   ```swift
   print("[SyncedSettings] pushToCloud: selectedCoach='\(defaults.string(forKey: LocalKey.selectedCoach) ?? "")', selectedCoachDate='\(defaults.string(forKey: LocalKey.selectedCoachDate) ?? "")'")
   ```
   → Wenn macOS `""` pushed, ist die Hypothese bestaetigt.

2. **Logging in `pullFromCloud()`** (SyncedSettings.swift Zeile 148):
   ```swift
   print("[SyncedSettings] pullFromCloud: remoteCoach='\(cloud.string(forKey: CloudKey.selectedCoach) ?? "")', remoteDate='\(remoteCoachDate)', localDate='\(localCoachDate)'")
   ```
   → Zeigt ob Remote-Werte ankommen und ob die Datums-Vergleichslogik greift.

3. **Timing-Log in FocusBloxMacApp** (Zeile 320):
   ```swift
   print("[MacApp] scenePhase .active → calling pushToCloud()")
   ```

### Zum WIDERLEGEN:
- Wenn macOS "troll" pushed (nicht ""), dann ist Hypothese 1 falsch.
- Wenn `cloudDidChange` IMMER VOR `.active` feuert, ist das Timing kein Problem.

### Plattform: BEIDE pruefen (iOS pushed, macOS zerstoert die Daten)

---

## Challenge-Ergebnisse (Devil's Advocate)

**Verdict: LUECKEN → adressiert**

### Luecke 1: Warum schlaegt Sync fehl wenn macOS BEREITS LAEUFT?
**Antwort:** Wenn macOS schon offen ist und iPhone einen Coach pusht, SOLLTE der Observer-Pfad funktionieren (`cloudDidChange` → `pullFromCloud()`). ABER: Es gibt einen zusaetzlichen destruktiven Push in `FocusBloxMacApp.init()` Zeile 236: `syncedSettings.pushToCloud()`. Dieser feuert EINMAL beim App-Start und ueberschreibt iCloud mit leeren Werten. Danach funktioniert der Observer-Pfad zwar, aber iCloud hat bereits leere Werte. iPhone muss ERNEUT pushen (naechster `.active` oder naechste Coach-Wahl), damit macOS die Daten bekommt. Das erklaert das persistente Symptom: macOS oeffnen → iCloud zerstoert → stundenlange Verzoegerung bis iPhone erneut pushed.

### Luecke 2: Temporaere SyncedSettings-Instanzen
**Antwort:** `MorningIntentionView.saveSelection()` (Zeile 182) erstellt `SyncedSettings()` als neue, temporaere Instanz. Diese registriert einen Observer im init(), der beim Deallokieren haengen bleibt (Memory Leak). Funktional ist das kein Problem — `pushToCloud()` schreibt in den systemweiten NSUbiquitousKeyValueStore, nicht instanz-spezifisch. Aber es ist ein Design-Smell. **Out of scope fuer Bug 102.**

### Luecke 3: selectedCoachDate wird NUR von MorningIntentionView geschrieben
**Bestaetigter Fund:** `DailyCoachSelection.save()` schreibt `selectedCoach` in UserDefaults.standard (Zeile 198), aber NICHT `selectedCoachDate`. Nur `MorningIntentionView.saveSelection()` Zeile 180 schreibt `selectedCoachDate`. Das bedeutet:
- Siri-Intent (SetDailyIntentionIntent) setzt Coach via `.save()` → `selectedCoachDate` bleibt leer → `pushToCloud()` pushed Coach mit leerem Datum → `pullFromCloud()` auf anderem Geraet ignoriert es (weil `remoteCoachDate` leer).
- **Fix einbeziehen:** Siri-Intent muss auch `selectedCoachDate` setzen.

### Luecke 4: clearCoachFilter() erzeugt kaputten Zustand
**Bestaetigter Fund:** `BacklogView.clearCoachFilter()` setzt `selectedCoach = ""` aber aendert `selectedCoachDate` NICHT. Ergebnis: `selectedCoach=""` + `selectedCoachDate="2026-03-14"`. Naechster `pushToCloud()` sendet leeren Coach mit aktuellem Datum → andere Geraete akzeptieren das (weil Datum aktuell ist) und loeschen ihren Coach. **Out of scope fuer Bug 102** (clearCoachFilter ist bewusste User-Aktion), aber beachtenswert.

### Luecke 5: macOS App Group Entitlements
**Geprueft und OK:** macOS Entitlements enthalten `group.com.henning.focusblox`. App Group funktioniert auf macOS. Hypothese 4 bleibt NIEDRIG.

---

## Blast Radius

### Direkt betroffen (durch den Fix):
- `SyncedSettings.swift` — pullFromCloud()-Aufruf hinzufuegen, pushToCloud() schuetzen
- `FocusBloxApp.swift` — pullFromCloud() VOR pushToCloud() auf .active
- `FocusBloxMacApp.swift` — pullFromCloud() VOR pushToCloud() auf .active

### Indirekt betroffen (durch funktionierenden Sync):
- `CoachBacklogView` — Rendert neu wenn Coach synced (erwuenscht)
- `MacCoachBacklogView` — Zeigt jetzt iPhone-Coach (erwuenscht)
- `MorningIntentionView` — Zeigt synced Coach (erwuenscht)
- `NotificationService` — Monster-Bild in Notifications stimmt

### NICHT betroffen:
- Task CRUD, Focus Blocks, Calendar/Reminders — unabhaengig
- coachModeEnabled — wird separat nicht gesynced (out of scope fuer Bug 102)

### Aehnliche Patterns mit gleichem Problem:
- Alle anderen Settings in `pushToCloud()` haben dasselbe Timing-Problem, aber dort faellt es weniger auf weil:
  - Kalender-IDs werden nur gepushed wenn nicht-leer (Zeile 64-68: `if let calID...!calID.isEmpty`)
  - Bool-Werte haben sinnvolle Defaults (false)
  - Nur beim Coach sind die Defaults destruktiv ("" ueberschreibt valide Daten)
