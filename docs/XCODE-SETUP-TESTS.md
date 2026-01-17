# Xcode Setup: Eisenhower Matrix Tests aktivieren

**Zeitaufwand:** ~5 Minuten
**Ziel:** 22 neue Tests zu Xcode Targets hinzufügen und ausführen

---

## Schritt 1: Xcode öffnen

```bash
open TimeBox.xcodeproj
```

Warte bis Xcode vollständig geladen ist.

---

## Schritt 2: Unit Tests hinzufügen (10 Tests)

**2.1 Im Project Navigator (linke Sidebar):**
- Suche den Ordner `TimeBoxTests` (blauer Ordner-Icon)
- **WICHTIG:** Rechtsklick direkt auf den ORDNER `TimeBoxTests`, NICHT auf das Target

**2.2 Im Kontextmenü:**
- Wähle: **"Add Files to "TimeBox"..."**

**2.3 File Picker öffnet sich:**
- Navigiere zu: `TimeBox/TimeBoxTests/`
- Wähle die Datei: **`EisenhowerMatrixTests.swift`**
- ✅ **KRITISCH:** Im Dialog unten:
  - ✅ **"Copy items if needed"** - UNCHECKED (Datei ist schon im Repo)
  - ✅ **"Added folders"** - "Create groups" (ausgewählt)
  - ✅ **"Add to targets"** - **CHECKED bei `TimeBoxTests`** ← WICHTIG!

**2.4 Klicke "Add"**

**2.5 Verifiziere:**
- `EisenhowerMatrixTests.swift` sollte jetzt unter `TimeBoxTests` Ordner sichtbar sein
- Icon sollte BLAU sein (nicht grau)

---

## Schritt 3: UI Tests hinzufügen (12 Tests)

**3.1 Im Project Navigator:**
- Suche den Ordner `TimeBoxUITests` (blauer Ordner-Icon)
- Rechtsklick auf den ORDNER `TimeBoxUITests`

**3.2 Im Kontextmenü:**
- Wähle: **"Add Files to "TimeBox"..."**

**3.3 File Picker:**
- Navigiere zu: `TimeBox/TimeBoxUITests/`
- Wähle die Datei: **`EisenhowerMatrixUITests.swift`**
- ✅ **KRITISCH:** Im Dialog unten:
  - ✅ "Copy items if needed" - UNCHECKED
  - ✅ "Create groups" (ausgewählt)
  - ✅ **"Add to targets"** - **CHECKED bei `TimeBoxUITests`** ← WICHTIG!

**3.4 Klicke "Add"**

**3.5 Verifiziere:**
- `EisenhowerMatrixUITests.swift` sollte unter `TimeBoxUITests` sichtbar sein
- Icon sollte BLAU sein

---

## Schritt 4: Target Membership verifizieren

**Für BEIDE Test-Files:**

**4.1 Wähle `EisenhowerMatrixTests.swift` im Navigator**

**4.2 Öffne File Inspector (rechte Sidebar, Tab 1 - Dokument Icon)**

**4.3 Section "Target Membership":**
- ✅ `TimeBoxTests` sollte CHECKED sein
- ❌ `TimeBox` sollte UNCHECKED sein (Test gehört nicht ins App Target!)
- ❌ `TimeBoxUITests` sollte UNCHECKED sein

**4.4 Wiederhole für `EisenhowerMatrixUITests.swift`:**
- ✅ `TimeBoxUITests` sollte CHECKED sein
- ❌ `TimeBox` sollte UNCHECKED sein
- ❌ `TimeBoxTests` sollte UNCHECKED sein

---

## Schritt 5: Build & Test

**Option A: Xcode GUI (empfohlen für ersten Test)**

**5.1 Product Menu:**
- Product → Test (oder CMD+U)

**5.2 Warte auf Build + Tests:**
- Build sollte erfolgreich sein
- Tests laufen auf Simulator
- **Erwartung:**
  - Existing: 92 tests
  - NEU: +10 Unit Tests (EisenhowerMatrixTests)
  - NEU: +12 UI Tests (EisenhowerMatrixUITests)
  - **Total: 114 tests passed** ✅

**5.3 Test Results anzeigen:**
- Test Navigator (linke Sidebar, Test Icon - Diamant)
- Expandiere: TimeBoxTests → EisenhowerMatrixTests
- Expandiere: TimeBoxUITests → EisenhowerMatrixUITests
- Alle Tests sollten grüne Checkmarks haben ✅

---

**Option B: Command Line (für CI/Automation)**

```bash
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "(Test Suite|Executed|passed|failed)" | tail -20
```

**Erwartetes Output:**
```
Test Suite 'All tests' started
...
Test Suite 'EisenhowerMatrixTests' passed
  Executed 10 tests, with 0 failures
Test Suite 'EisenhowerMatrixUITests' passed
  Executed 12 tests, with 0 failures
...
Test Suite 'All tests' passed
  Executed 114 tests, with 0 failures (0 unexpected)
```

---

## Schritt 6: Nur neue Tests ausführen (Optional)

**Nur Eisenhower Unit Tests:**
```bash
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TimeBoxTests/EisenhowerMatrixTests
```

**Nur Eisenhower UI Tests:**
```bash
xcodebuild test -project TimeBox.xcodeproj -scheme TimeBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TimeBoxUITests/EisenhowerMatrixUITests
```

---

## Troubleshooting

### Problem: "No such module 'XCTest'"
**Lösung:** Target Membership falsch → Schritt 4 wiederholen

### Problem: "File not found in scope"
**Lösung:** File nicht zum Target hinzugefügt → Schritt 2/3 wiederholen

### Problem: Tests erscheinen nicht im Test Navigator
**Lösung:**
1. Clean Build: Product → Clean Build Folder (Shift+CMD+K)
2. Rebuild: Product → Build (CMD+B)
3. Test Navigator refreshen: Rechtsklick → "Refresh Tests"

### Problem: Icon ist GRAU statt BLAU
**Lösung:** File ist nicht im Projekt → Schritt 2/3 wiederholen, Target Membership prüfen

### Problem: UI Tests starten nicht
**Lösung:**
1. Simulator manuell starten: Xcode → Window → Devices and Simulators
2. iPhone 17 Pro Simulator auswählen
3. Tests erneut starten

---

## Nach erfolgreichem Test

**Wenn alle 114 Tests grün sind ✅:**

```bash
# Git Status prüfen (sollte clean sein, Tests sind schon committed)
git status

# Falls Xcode Metadata geändert wurde:
git add TimeBox.xcodeproj/project.pbxproj
git commit -m "chore: Add Eisenhower Matrix tests to Xcode targets"
```

---

## Zusammenfassung

**Vor Setup:** 92 tests
**Nach Setup:** 114 tests (+22 neue Tests für Eisenhower Matrix)
**Test Coverage:**
- Eisenhower Matrix Filterlogik ✅
- UI Navigation & Quadranten ✅
- Edge Cases (Empty State, Completed Tasks) ✅

**Nächster Schritt:** Phase 2 als validiert markieren, dann Phase 3 mit korrektem TDD-Workflow starten! 🚀
