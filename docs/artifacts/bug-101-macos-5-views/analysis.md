# Bug 101: macOS hat 5 Views statt 4 — Analyse

## Agenten-Ergebnisse (Zusammenfassung)

### Agent 1: Wiederholungs-Check
- **Keine vorherigen Fix-Versuche** — Bug 101 wurde noch nie angegangen
- iOS wurde am 03.03.2026 konsolidiert (Commit `4861e2f`: "Unified Calendar View")
- macOS bekam 5 Sections am 20.02.2026 (Commit `d10d752`)
- Labels wurden auf Englisch geaendert (Bug 67), aber Struktur blieb bei 5

### Agent 2: Datenfluss-Trace
- `MainSection` Enum in `SidebarView.swift:11-27` definiert 5 Cases
- `@State selectedSection` in `FocusBloxMacApp.swift:203`
- Toolbar-Picker in `ContentView.swift:232-244` iteriert `MainSection.allCases`
- Switch-Router in `ContentView.swift:250-277` routet `.planning` → `MacPlanningView`, `.assign` → `MacAssignView`
- Block-Tap in MacPlanningView navigiert zu `.assign` Tab

### Agent 3: Alle Schreiber
- Nur 3 Stellen definieren/nutzen die Navigation:
  1. `SidebarView.swift` — Enum-Definition
  2. `ContentView.swift` — Picker + Switch
  3. `FocusBloxMacApp.swift` — State-Initialisierung
- Kein NavigationLink, kein NavigationStack — rein State-gesteuert

### Agent 4: Merge-Szenarien
- **MacPlanningView (663 LoC):** Timeline, Kalender-Events, Free Slots, Block-Drag
- **MacAssignView (463 LoC):** Block-Cards, Task-Drag-Drop, Task-Reorder
- **iOS BlockPlanningView (1.263 LoC):** Beides unified in einer View
- Ueberlappung: Beide haben identische "Next Up" Sidebar
- Schluesselentscheidung: Block-Tap → Sheet (wie iOS) oder Scroll-zu-Card?

### Agent 5: Blast Radius
- **4 UI Test-Dateien brechen:** MacToolbarNavigationUITests, UnifiedBlockNavigationUITests, MacTextTruncationBlastRadiusUITests, MacPlanningViewUITests
- **1 Unit Test bricht:** UnifiedTabSymbolsTests (erwartet 5 statt 4)
- **464 LoC Dead Code:** MacAssignView wird unerreichbar
- **State-Cleanup:** `highlightedBlockID` in ContentView wird ungenutzt

---

## Hypothesen

### Hypothese 1: Fehlende Portierung (HOCH — 95%)
**Beschreibung:** iOS wurde konsolidiert (Commit `4861e2f`), macOS wurde einfach vergessen/uebersprungen.

**Beweis DAFUER:**
- Git-History zeigt klar: iOS hatte auch 5 Tabs, wurde am 03.03.2026 auf 4 reduziert
- macOS wurde nie angefasst — kein Commit nach dem iOS-Unified-View der macOS betrifft
- `MainSection` Enum hat sich seit Feb 2026 nicht geaendert

**Beweis DAGEGEN:**
- Keiner — alle Daten stuetzen diese Hypothese

**Wahrscheinlichkeit:** HOCH

### Hypothese 2: Technische Einschraenkung (NIEDRIG — 3%)
**Beschreibung:** macOS kann die Unified View technisch nicht umsetzen (z.B. NavigationSplitView-Limitierung).

**Beweis DAFUER:**
- macOS nutzt `NavigationSplitView` statt `NavigationStack`
- macOS Timeline-Rendering ist anders (HSplitView statt ScrollView)

**Beweis DAGEGEN:**
- iOS BlockPlanningView nutzt auch kein NavigationStack fuer die Unified-Logik
- macOS kann problemlos eine View mit Timeline + Block-Cards darstellen (ist nur Layout)
- `FocusBlockTasksSheet` ist bereits shared und funktioniert auf macOS

**Wahrscheinlichkeit:** NIEDRIG

### Hypothese 3: Bewusste UX-Entscheidung (NIEDRIG — 2%)
**Beschreibung:** Die Trennung auf macOS ist gewollt, weil der groessere Bildschirm separate Views rechtfertigt.

**Beweis DAFUER:**
- macOS hat mehr Platz, zwei separate Views koennen uebersichtlicher sein
- Assign-View ist fuer Bulk-Assignment effizienter (kein Sheet noetig)

**Beweis DAGEGEN:**
- Bug 101 ist explizit als Bug dokumentiert, nicht als Feature
- Henning hat "4 Sections wie iOS" als erwartetes Verhalten definiert
- iOS-Paradigma ist die Referenz

**Wahrscheinlichkeit:** NIEDRIG

---

## Wahrscheinlichste Ursache

**Hypothese 1: Fehlende Portierung.** macOS wurde nach der iOS-Konsolidierung nie aktualisiert. Das ist kein Bug im klassischen Sinn (kein Regressionstest moeglich), sondern eine **fehlende Feature-Portierung**.

---

## Challenger-Korrekturen (LUECKEN-Verdict behoben)

### Korrektur 1: MacPlanningView hat BEREITS FocusBlockTasksSheet
MacPlanningView.swift:119-120 oeffnet bereits ein FocusBlockTasksSheet bei Block-Tap.
Es gibt KEINEN Tab-Wechsel zu Assign. Der "empfohlene Fix" (Block-Tap → Sheet) ist schon implementiert.
→ MacPlanningView braucht KEINE Aenderungen.

### Korrektur 2: highlightedBlockID ist in ContentView.swift:60, nicht FocusBloxMacApp
Die Bereinigung betrifft ContentView.swift, nicht FocusBloxMacApp.

### Korrektur 3: Es gab einen frueheren Plan (openspec/unified-block-detail-navigation)
Dieser Plan wollte das GEGENTEIL: Block-Tap in Planning sollte ZUM Assign-Tab navigieren.
Wurde nie implementiert (alle Checkboxen offen). Ist durch Bug 101 OBSOLET.

### Korrektur 4: Fix ist VIEL einfacher als urspruenglich analysiert
Der Fix besteht hauptsaechlich aus LOESCHUNGEN. MacPlanningView bleibt wie sie ist.

## Korrigierter Fix-Plan

**Kein Debugging noetig** — fehlende Portierung, kein technischer Bug.

**Tatsaechlicher Fix (4 Schritte):**
1. `.assign` Case aus `MainSection` Enum entfernen (SidebarView.swift)
2. `.assign` Switch-Case aus `mainContentView` entfernen (ContentView.swift)
3. `highlightedBlockID` State entfernen (ContentView.swift)
4. MacAssignView.swift LOESCHEN (464 LoC Dead Code)

**MacPlanningView bleibt UNVERAENDERT** — hat bereits FocusBlockTasksSheet.

### Features die mit MacAssignView verloren gehen:
- Drag-Drop von Tasks direkt auf Block-Cards (ohne Sheet)
- Block-Auslastungs-Anzeige (Minuten genutzt/verfuegbar)
- Inline-Remove-Button pro Task

Diese Features gibt es auf iOS auch nicht — dort funktioniert alles ueber FocusBlockTasksSheet.
Der Verlust bringt macOS also IN LINE mit iOS.

---

## Blast Radius

### Korrigierter Blast Radius:
| Datei | Aenderung | LoC-Impact |
|-------|-----------|------------|
| `SidebarView.swift` | `.assign` Case + Icon entfernen | -3 |
| `ContentView.swift` | `.assign` Switch-Case + `highlightedBlockID` entfernen | -8 |
| `MacAssignView.swift` | **LOESCHEN** | -464 |
| `MacToolbarNavigationUITests.swift` | 4 statt 5 Sections | ~-5 |
| `UnifiedBlockNavigationUITests.swift` | **LOESCHEN** (testet nie-implementiertes Feature) | -250 |
| `MacTextTruncationBlastRadiusUITests.swift` | Assign-Test entfernen | -20 |
| `UnifiedTabSymbolsTests.swift` | 4 statt 5 Sections | -2 |

### Geschaetzter Netto-Impact: ~-750 LoC (fast nur Loeschungen)
### MacPlanningView: KEINE Aenderung noetig

### Aehnliche Patterns mit gleichem Problem:
- Keine — die Sidebar-Navigation ist die einzige Stelle mit dieser Divergenz

---

## Scope-Einschaetzung (korrigiert)

Nach Challenger-Korrektur ist der Fix KLEINER als urspruenglich angenommen:
- ~5 Dateien mit echten Aenderungen (davon 2 Loeschungen)
- ~750 LoC Netto-Reduktion (fast nur Loeschungen)
- Keine Neuentwicklung in MacPlanningView noetig
- Tests: Hauptsaechlich Loeschungen + kleine Anpassungen

**Passt in die Scoping-Limits** wenn man beruecksichtigt dass Loeschungen weniger riskant sind als Neuschreibungen.
