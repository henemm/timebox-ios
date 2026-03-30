# BUG_111 Analyse: macOS UI Tests TCC-Dialog blockiert Testlauf

## Symptom

Beim Ausführen von macOS UI Tests (`./scripts/sim.sh mac-test`) erscheint ein modaler System-Dialog:
> "XCTest möchte Enable UI Automation. Verwende Touch ID oder gib dein Passwort ein."

Dialog blockiert Test-Ausführung via SSH, da niemand den Dialog bestätigen kann.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- **Keine bisherigen Fix-Versuche** für BUG_111
- Infrastruktur existiert bereits: `sim.sh mac-test` (Zeilen 365-395), `run-mac-ui-tests.sh` (Keychain-Unlock für Code-Signing)
- **Überraschend:** `docs/artifacts/mac-ui-test-output.txt` (23. März) zeigt 31+ bestandene Tests — Tests liefen offenbar SCHON MAL erfolgreich
- Mögliche Erklärung: Jemand hat den Dialog einmal manuell am iMac bestätigt, TCC-Eintrag existierte temporär

### Agent 2: Datenfluss-Trace
- **Autorisierungs-Kette:** `xcodebuild test` → `xctrunner` (Bundle ID: `henemm.FocusBloxMacUITests.xctrunner`) → Accessibility APIs → TCC-Check
- **TCC.db aktueller Stand:** KEIN Eintrag für `henemm.FocusBloxMacUITests.xctrunner` → `auth_value=1` (UNKNOWN) → Dialog
- `DevToolsSecurity -enable` behandelt NUR `task_for_pid` (Debugger), NICHT `kTCCServiceAccessibility`
- `get-task-allow` Entitlement hat KEINEN Einfluss auf TCC
- **3 Fix-Methoden:** PPPC-Profil, manuelle TCC.db-Bearbeitung, einmalige interaktive Genehmigung

### Agent 3: Config-Inventar
- **Keine TCC/Accessibility-Konfiguration** im Projekt vorhanden
- macOS Entitlements: `get-task-allow=true`, `app-sandbox=true`, Kalender/Erinnerungen
- 23 macOS UI Test-Dateien, alle nutzen `-UITesting`/`-MockData` Launch-Arguments
- Kein PPPC-Profil, kein TCC-Script, keine Automatisierung vorhanden

### Agent 4: Szenarien-Matrix
- **Dialog erscheint:** Erstlauf, nach Xcode-Update, via SSH, via CLI (`xcodebuild`), nach macOS-Update
- **Dialog erscheint NICHT:** Nach manueller Genehmigung (TCC-Eintrag persistiert), mit PPPC-Profil, bei iOS Simulator (eigene Sandbox), in Xcode GUI (nutzt Xcode's eigenen TCC-Eintrag)
- **iOS vs macOS:** iOS Simulator hat eigenen virtualisierten Accessibility Server — kein Host-TCC nötig. macOS UI Tests laufen direkt auf dem Host.

### Agent 5: Blast Radius
- **79 macOS UI Test-Methoden** in **23 Test-Dateien** blockiert
- **TD_007** (macOS UI Tests in Workflow integrieren) hängt direkt von BUG_111 ab
- Aktueller Workaround: `mac-build` (Kompilierung) + manuelle Tests
- Tests sind KEINE Stubs — vollständige, produktionsreife Tests die nur nicht automatisiert ausführbar sind

## Hypothesen

### Hypothese 1: Fehlender TCC-Eintrag für xctrunner (HOCH)

**Beschreibung:** `henemm.FocusBloxMacUITests.xctrunner` hat keinen Eintrag in `/Library/Application Support/com.apple.TCC/TCC.db` für `kTCCServiceAccessibility`. Ohne Eintrag zeigt macOS bei jedem CLI-Lauf den Genehmigungsdialog.

**Beweis DAFÜR:**
- Agent 2 bestätigt: Kein TCC-Eintrag für xctrunner in der Datenbank
- Agent 4: Dialog-Verhalten passt exakt zu `auth_value=1` (UNKNOWN) Szenario
- Agent 3: Kein PPPC-Profil oder TCC-Automatisierung im Projekt

**Beweis DAGEGEN:**
- Agent 1 zeigt dass Tests am 23. März erfolgreich liefen — jemand könnte den Dialog manuell bestätigt haben, und ein Xcode/macOS-Update hat den Eintrag wieder gelöscht

**Wahrscheinlichkeit:** HOCH (90%)

### Hypothese 2: xctrunner Bundle-ID stimmt nicht überein (MITTEL)

**Beschreibung:** Die tatsächliche Bundle-ID des xctrunner könnte anders sein als `henemm.FocusBloxMacUITests.xctrunner`. Apple könnte das Format geändert haben (z.B. `com.apple.dt.xctest.henemm.FocusBloxMacUITests`).

**Beweis DAFÜR:**
- Agent 2 listet 3 mögliche Bundle-ID-Formate
- Kein definitiver Beweis welche ID macOS tatsächlich prüft

**Beweis DAGEGEN:**
- Die Konvention `<TestBundleID>.xctrunner` ist Standard seit Xcode 14+
- ACTIVE-todos.md nennt diese ID explizit

**Wahrscheinlichkeit:** MITTEL (30%) — relevant für den PPPC-Profil-Fix

### Hypothese 3: TCC-Eintrag wird bei jedem Build gelöscht (NIEDRIG)

**Beschreibung:** Jeder Clean Build ändert die Code-Signatur des xctrunner, wodurch macOS den TCC-Eintrag invalidiert und den Dialog erneut zeigt.

**Beweis DAFÜR:**
- Tests liefen am 23. März (nach manueller Genehmigung?), jetzt wieder blockiert
- Code-Signing Identity ändert sich potentiell bei jedem Build

**Beweis DAGEGEN:**
- TCC prüft primär Bundle-ID, nicht Code-Signatur-Hash
- PPPC-Profile nutzen `CodeRequirement` mit `anchor apple generic` — flexibel genug für Rebuilds

**Wahrscheinlichkeit:** NIEDRIG (15%)

## Debugging-Plan

### Hypothese 1 verifizieren:
```bash
# TCC.db auslesen — welche Einträge existieren für unser Bundle?
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "SELECT client, service, auth_value, auth_reason FROM access WHERE client LIKE '%FocusBlox%' OR client LIKE '%xctrunner%';"
```
**Erwartetes Ergebnis bei Hypothese 1:** Kein Eintrag für `*xctrunner*`

### Hypothese 2 verifizieren:
```bash
# xctrunner Binary finden und Bundle-ID extrahieren
find /Applications/Xcode.app -name "xctrunner" -type f 2>/dev/null | head -5
# Dann: codesign -dv --verbose=4 <pfad>
```
**Erwartetes Ergebnis:** Bundle-ID Format bestätigen

### Hypothese 3 verifizieren:
```bash
# Nach manuellem "Allow": TCC-Eintrag prüfen, dann Clean Build, erneut prüfen
# Vor Build:
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "SELECT * FROM access WHERE client LIKE '%xctrunner%';"
# Clean Build:
xcodebuild clean -scheme FocusBloxMac
xcodebuild build -scheme FocusBloxMac
# Nach Build:
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "SELECT * FROM access WHERE client LIKE '%xctrunner%';"
```

## Fix-Ansatz: PPPC-Konfigurationsprofil

**Empfehlung:** PPPC-Profil (`.mobileconfig`) erstellen, das `henemm.FocusBloxMacUITests.xctrunner` für `kTCCServiceAccessibility` vorautorisiert.

**Dateien:**
1. `scripts/focusblox-uitest-tcc.mobileconfig` — PPPC-Profil
2. `scripts/install-tcc-profile.sh` — Installations-Script
3. `scripts/sim.sh` — Erweitern um TCC-Check vor `mac-test`

**Vorteile:**
- Persistiert über Xcode-Updates
- Funktioniert via SSH ohne User-Interaktion
- Standard Apple-Mechanismus (kein Hack)
- Kann in CI/CD installiert werden

**Risiken:**
- Bundle-ID muss exakt stimmen (Hypothese 2)
- `sudo profiles -I -F` benötigt Admin-Rechte
- Profil muss bei Bundle-ID-Änderung aktualisiert werden

## Blast Radius

- **Direkt betroffen:** 79 macOS UI Tests in 23 Dateien
- **Indirekt betroffen:** TD_007 (Workflow-Integration), Adversary-Gate für macOS
- **Nicht betroffen:** iOS Tests (Simulator), macOS Unit Tests, macOS Build
