# Analyse: Refiner-Tab entfernen + Auto-Confirm Pipeline

## Bug-Beschreibung

Das Bewertungssystem fuer neue AdHoc Tasks (Refiner-Tab) wurde neu implementiert. Der Refiner-Tab ergibt keinen Sinn mehr. Alle neuen Tasks sollen automatisch im Hintergrund ueberarbeitet werden, ohne Freigabe durch den Nutzer. Der Refiner-Tab entfaellt. Auswirkung: "More"-Tab verschwindet, "Review" wird direkt sichtbar.

## Agenten-Ergebnisse

### 1. Wiederholungs-Check
- RW_1.1 (Commit 2787634): TaskLifecycleStatus + Quick Dump eingefuehrt
- RW_1.2/1.3 (Commit 55ce84f): Refiner-Tab mit AI Suggestion Chips
- RW_1.4 (Commit 692b1bf): AI Enrichment Rework — Kategorie + Zeitschaetzung statt Titel-AI
- Keine frueheren Versuche, den Refiner zu entfernen

### 2. Datenfluss-Trace: lifecycleStatus Pipeline
```
Task-Erstellung → lifecycleStatus = "raw"
    ↓
SmartTaskEnrichmentService.enrichTask() → suggested*-Felder
    ↓
[Aktuell: User swipt "Bestaetigen" im Refiner]
    ↓
confirmSuggestions() → suggested* → Hauptfelder, status → "active"
    ↓
Task erscheint im Backlog (LocalTaskSource filtert "raw" raus)
```

### 3. Alle Schreiber von lifecycleStatus = "raw"
| Datei | Zeile | Kontext |
|-------|-------|---------|
| Sources/Views/QuickCaptureView.swift | 362 | iOS Quick Capture |
| FocusBloxMac/QuickCapturePanel.swift | 329 | macOS Quick Capture |
| Sources/Intents/CreateTaskIntent.swift | 19 | Siri/Spotlight Intent |
| FocusBloxWatch/VoiceInputSheet.swift | 46 | Watch Voice Input |
| FocusBloxMacShareExtension/ShareViewController.swift | 160 | macOS Share Extension |

### 4. Szenarien-Analyse (Auto-Confirm Risiken)
| Szenario | Risiko | Loesung in Option A |
|----------|--------|---------------------|
| AI nicht verfuegbar | suggested* bleiben nil → leerer Task | confirmSuggestions() kopiert nur non-nil Felder → Task bleibt mit leeren Attributen, wird aber sichtbar im Backlog |
| aiScoringEnabled = false | Kein Enrichment | Gleich wie oben — Task funktioniert, nur ohne AI-Attribute |
| Enrichment-Fehler | Silent failure | Task wird trotzdem confirmed, nur ohne Suggestions |
| Race Condition | Auto-confirm vor Enrichment | **KEIN Risiko bei Option A**: enrichTask() ist await, danach confirmSuggestions() |
| Offline | AI-Call schlaegt fehl | Task wird confirmed ohne Suggestions |

### 5. Blast Radius
**UI-Dateien (zu aendern):**
- `Sources/Views/MainTabView.swift` — Refiner-Tab + rawTasks Query entfernen
- `Sources/Views/RefinerView.swift` — Datei loeschen
- `Sources/Views/RefinerTaskCard.swift` — Datei loeschen (SuggestionChip + FlowLayout pruefen ob anderswo genutzt)
- `FocusBloxMac/SidebarView.swift` — MainSection.refiner entfernen
- `FocusBloxMac/ContentView.swift` — .refiner Case entfernen

**Logik-Dateien (zu aendern):**
- `Sources/Services/TaskSources/LocalTaskSource.swift` — Nach enrichTask() automatisch confirmSuggestions() + lifecycleStatus-Filter ggf. anpassen
- `Sources/Models/LocalTask.swift` — confirmSuggestions() bleibt (wird automatisch aufgerufen)
- `Sources/FocusBloxApp.swift` — Mock-Daten mit "raw" Tasks entfernen, Deep Link "refiner" entfernen

**Weitere Erstellungspfade (auto-confirm noetig):**
- `Sources/Intents/CreateTaskIntent.swift` — nach Enrichment auto-confirm
- `FocusBloxWatch/VoiceInputSheet.swift` — nach Enrichment auto-confirm
- `FocusBloxMacShareExtension/ShareViewController.swift` — nach Enrichment auto-confirm

**Tests (zu aendern/loeschen):**
- `FocusBloxUITests/RefinerUITests.swift` — loeschen
- `FocusBloxTests/RefinerTests.swift` — confirmSuggestions()-Tests behalten, Refiner-UI-Tests entfernen
- `FocusBloxTests/LifecycleStatusTests.swift` — "raw"-Filter-Tests anpassen
- `FocusBloxTests/MonsterRemovalCleanupTests.swift` — AppTab.refiner aus Tab-Liste entfernen

## Hypothesen

### H1: Zentraler Auto-Confirm in LocalTaskSource.createTask() (HOCH)
**Ansatz:** In `LocalTaskSource.createTask()` nach `await enrichment.enrichTask(task)` automatisch `task.confirmSuggestions()` aufrufen. Alle Tasks werden sofort "active".
- **Dafuer:** Zentraler Punkt, alle iOS-Erstellungspfade laufen hier durch
- **Dagegen:** Share Extension + Watch + Intents haben eigene Erstellungspfade
- **Wahrscheinlichkeit:** Hoch — deckt den Hauptpfad ab

### H2: Auto-Confirm an jedem Erstellungspunkt (MITTEL)
**Ansatz:** An jedem der 5 Erstellungspunkte nach Enrichment auto-confirm.
- **Dafuer:** Deckt alle Pfade ab
- **Dagegen:** Code-Duplikation, fehleranfaellig
- **Wahrscheinlichkeit:** Mittel — funktioniert aber nicht elegant

### H3: lifecycleStatus "raw" komplett abschaffen (NIEDRIG)
**Ansatz:** Tasks direkt als "active" erstellen, Enrichment schreibt direkt in Hauptfelder.
- **Dafuer:** Einfachster Code
- **Dagegen:** Groesster Umbau, suggested*-Felder werden nutzlos, mehr Dateien betroffen
- **Wahrscheinlichkeit:** Niedrig — zu invasiv fuer den Scope

## Empfohlene Loesung: H1 (Zentraler Auto-Confirm)

**Aenderungen:**
1. `LocalTaskSource.createTask()`: Nach `enrichTask()` → `task.confirmSuggestions()` aufrufen
2. Alle anderen Erstellungspfade (Intent, Watch, Share Extension, macOS QC): Ebenfalls auto-confirm nach Enrichment
3. Refiner-Tab aus iOS + macOS Navigation entfernen
4. RefinerView + RefinerTaskCard loeschen
5. Tests anpassen

**Plattform:** iOS UND macOS betroffen.

## Blast Radius
- Keine anderen Features nutzen den Refiner-Code
- BacklogView filtert via LocalTaskSource, der "raw" ausschliesst → nach Auto-Confirm sind alle Tasks sofort sichtbar
- SmartTaskEnrichmentService.enrichAllTbdTasks() skippt "raw" Tasks → muss angepasst werden wenn Tasks nie mehr "raw" sind
