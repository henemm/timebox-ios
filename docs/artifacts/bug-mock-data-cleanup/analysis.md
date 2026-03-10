# Bug-Analyse: Mock-Daten werden bei macOS Tests nicht geloescht

## Bug-Beschreibung
Bei macOS Tests werden sehr viele Mock-Daten (Tasks) angelegt und nicht mehr geloescht. Das manuelle Loeschen ist laestig.

## Agenten-Ergebnisse Zusammenfassung

### Architektur-Kontext
- App prueft auf `-UITesting` Launch-Argument
- Mit `-UITesting`: In-Memory Store, kein CloudKit, Mock-Daten verschwinden nach App-Ende
- Ohne `-UITesting`: Persistenter Store + CloudKit Sync → Daten bleiben PERMANENT

### Root Cause: 4 macOS UI Test-Dateien fehlt `-UITesting` Flag

**Ohne `-UITesting` (PERSISTENT - Daten bleiben!):**

| Datei | Flag | Erstellt Tasks? |
|-------|------|----------------|
| `FocusBloxMacUITests.swift` | Nur `-ApplePersistenceIgnoreState` | JA: "UI Test Task XXXX" |
| `MacSyncUIAlignmentUITests.swift` | Nur `-ApplePersistenceIgnoreState` | JA: "Badge Test Task XXXX", "Inspector Test Task XXXX", "Category Grid Test XXXX" |
| `MacBacklogTagsUITests.swift` | `-UITestMode` (FALSCHER Flag!) | NEIN (liest nur) |
| `RemindersSyncUITests.swift` | Nur `-ApplePersistenceIgnoreState` | NEIN (liest nur) |
| `FocusBloxMacUITestsLaunchTests.swift` | KEINE Flags | NEIN (nur Screenshot) |

**Die Hauptverursacher sind `FocusBloxMacUITests.swift` und `MacSyncUIAlignmentUITests.swift`:**
- Sie erstellen Tasks via `textField.typeText(title)` + `typeKey(.return)`
- Weil `-UITesting` fehlt, laeuft die App im Produktions-Modus
- Tasks werden in die echte SwiftData-Datenbank geschrieben
- Bei CloudKit-Sync werden sie auf ALLE Geraete synchronisiert

## Alle Hypothesen

### Hypothese 1: Fehlende `-UITesting` Flags bei macOS UI Tests (HOCH)
- **Beweis DAFUER:** 4 Test-Dateien haben kein `-UITesting` → App nutzt persistenten Store
- **Beweis DAGEGEN:** Keiner — Code ist eindeutig
- **Wahrscheinlichkeit:** HOCH

### Hypothese 2: Tasks bleiben nach UI Test-Run im persistenten Store (HOCH)
- **Beweis DAFUER:** Ohne `-UITesting` werden Tasks mit `try context.save()` in echte DB geschrieben. `tearDown` setzt nur `app = nil`, loescht keine Daten.
- **Beweis DAGEGEN:** Keiner
- **Wahrscheinlichkeit:** HOCH (Folge von Hypothese 1)

### Hypothese 3: CloudKit synchronisiert Test-Daten auf andere Geraete (MITTEL)
- **Beweis DAFUER:** Ohne `-UITesting` nutzt die App `cloudKitDatabase: .private("iCloud.com.henning.focusblox")`. Test-Daten werden synchronisiert.
- **Beweis DAGEGEN:** Simulator hat evtl. kein iCloud-Konto
- **Wahrscheinlichkeit:** MITTEL (haengt von Simulator-Setup ab)

## Wahrscheinlichste Ursache

**Hypothese 1+2 kombiniert:** Die macOS UI Tests `FocusBloxMacUITests.swift` und `MacSyncUIAlignmentUITests.swift` starten die App OHNE `-UITesting`, erstellen Tasks via UI, und diese werden in die echte Datenbank geschrieben. Bei jedem Test-Run kommen neue Tasks dazu (zufaellige Nummern im Titel).

## Fix-Vorschlag

1. **Root Cause beheben:** `-UITesting` und `-MockData` zu ALLEN macOS UI Tests hinzufuegen
2. **Bestehende Mock-Tasks loeschen:** Cleanup-Launch-Argument `-CleanupTestData` hinzufuegen das Tasks mit Mock-Patterns loescht

## Blast Radius
- Nur macOS UI Tests betroffen (iOS Tests haben korrekte Flags)
- 4 Dateien muessen gefixt werden
- Bestehende Mock-Daten muessen einmalig geloescht werden
