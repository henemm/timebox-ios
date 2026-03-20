---
entity_id: td-004-monster-cleanup
type: refactoring
created: 2026-03-20
updated: 2026-03-20
status: draft
version: "1.0"
tags: [tech-debt, dead-code, monster-removal, cleanup]
---

# TD_004 — Monster-Removal Dead Code Cleanup

## Approval

- [ ] Approved

## Purpose

Entfernt 6 verwaiste Artefakte die Commit 5f6ae47 (Monster/Coach-Feature-Entfernung, ~9500 LoC) uebersehen hat. Bereinigt tote Dateien, obsolete UI-Tests und Coach-Referenzen um den Codebase-Zustand konsistent mit der durchgefuehrten Feature-Entfernung zu machen.

## Scope

- **Dateien:** 8
- **LoC:** ~-407 (netto)
- **Risiko:** LOW — reiner Loeschvorgang und String-Korrektur, kein Verhaltensaenderung an aktiven Features

---

## Betroffene Dateien

### DELETE: `Sources/Models/DailyIntention.swift`

- **Groesse:** 131 LoC
- **Problem:** Enthaelt `IntentionOption` enum, `DailyIntention` struct und Filter-Logik. Kein einziger Import in `Sources/` oder `FocusBloxMac/` — vollstaendig verwaist seit Coach-Entfernung.
- **PBX-Refs:** `MINT01FILEREF00001`, `MINT02BUILD0000001` muessen aus `project.pbxproj` entfernt werden.
- **Aktion:** Datei loeschen + PBX-Eintraege entfernen.

### DELETE: `FocusBloxUITests/DisciplineHistoryUITests.swift`

- **Groesse:** 80 LoC
- **Problem:** Testet `CoachMeinTagView` — View wurde in 5f6ae47 geloescht. Tests verwenden `launchWithCoachMode()` mit `-coachModeEnabled` Launch-Argument und navigieren zum "Mein Tag" Tab, der nicht mehr existiert. Jeder Test-Run schlaegt fehl und liefert irrefuehrende Ergebnisse.
- **Aktion:** Datei loeschen + PBX-Ref entfernen.

### DELETE: `FocusBloxUITests/DisciplineTrendUITests.swift`

- **Groesse:** 73 LoC
- **Problem:** Testet das Trend-Segment in `CoachMeinTagView` — existiert nicht mehr. Selbe `launchWithCoachMode()` / "Mein Tag"-Abhaengigkeit wie oben.
- **Aktion:** Datei loeschen + PBX-Ref entfernen.

### DELETE: `FocusBloxUITests/CategoryTrendUITests.swift`

- **Groesse:** 71 LoC
- **Problem:** Testet Category-Trend in Coach-Mode — existiert nicht mehr. Selbe `launchWithCoachMode()` / "Mein Tag"-Abhaengigkeit wie oben.
- **Aktion:** Datei loeschen + PBX-Ref entfernen.

### MODIFY: `FocusBloxUITests/DebugHierarchyTest.swift`

- **Aenderung:** Methode `testPrintSettingsCoachMode()` entfernen (~40 LoC)
- **Problem:** Methode referenziert `coachDailyNudgesToggle` Accessibility-ID und navigiert zu Coach-Settings. Beides existiert nicht mehr. Die restliche Datei (Debug-Hierarchy-Ausgabe) ist harmlos und bleibt bestehen.

### MODIFY: `FocusBloxMacUITests/MacToolbarNavigationUITests.swift`

- **Aenderung:** Coach-Mode Icon-Fallback Zeilen 79-88 entfernen (~12 LoC)
- **Problem:** Test prueft ob "chart.bar" ODER "sun.and.horizon" (Coach-Mode Fallback) im Toolbar existiert. Coach-Mode gibt es nicht mehr. Der ODER-Zweig ist toter Test-Code der den Intent des Tests verwascht.
- **Nach Cleanup:** Nur noch `"chart.bar"` pruefen — kein Fallback.

### MODIFY: `Sources/Services/AITaskScoringService.swift`

- **Aenderung:** Zeile 110: String `"Produktivitaets-Coach"` ersetzen durch `"Produktivitaets-Assistent"` (1 LoC)
- **Problem:** AI-Prompt-String beschreibt die KI-Rolle noch als "Coach" — das ist inhaltlich inkorrekt nach Feature-Entfernung.
- **Seiteneffekte:** Keine funktionale Aenderung — nur der an OpenAI gesendete Prompt-Text aendert sich.

### MODIFY: `FocusBlox.xcodeproj/project.pbxproj`

- **Aenderung:** PBX-Eintraege fuer alle 4 geloeschten Dateien entfernen
- **Betroffene Sections:** `PBXFileReference`, `PBXBuildFile`, `PBXGroup`, `PBXSourcesBuildPhase`
- **Bekannte Refs:** `MINT01FILEREF00001`, `MINT02BUILD0000001` (DailyIntention), plus je 2 Refs pro geloeschter UITest-Datei
- **Risiko:** LOW — fehlende PBX-Refs fuer geloeschte Dateien verursachen Build-Warnungen aber keine Errors; saubere Entfernung ist dennoch Pflicht

---

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Sources/Models/DailyIntention.swift` | model | Wird geloescht — kein aktiver Aufrufer |
| `FocusBloxUITests/DisciplineHistoryUITests.swift` | test | Wird geloescht — testet nicht-existente View |
| `FocusBloxUITests/DisciplineTrendUITests.swift` | test | Wird geloescht — testet nicht-existente View |
| `FocusBloxUITests/CategoryTrendUITests.swift` | test | Wird geloescht — testet nicht-existente View |
| `FocusBloxUITests/DebugHierarchyTest.swift` | test | Wird partiell bereinigt |
| `FocusBloxMacUITests/MacToolbarNavigationUITests.swift` | test | Wird partiell bereinigt |
| `Sources/Services/AITaskScoringService.swift` | service | String-Korrektur |
| `FocusBlox.xcodeproj/project.pbxproj` | project | PBX-Refs fuer geloeschte Dateien entfernen |

---

## Implementation Details

```
Reihenfolge:
1. 4 UI-Test-Dateien loeschen (DisciplineHistory, DisciplineTrend, CategoryTrend loeschen;
   DebugHierarchyTest bereinigen)
2. DailyIntention.swift loeschen
3. MacToolbarNavigationUITests.swift: Coach-Fallback Zeilen 79-88 entfernen
4. AITaskScoringService.swift: String ersetzen
5. project.pbxproj: PBX-Refs fuer alle 4 geloeschten Dateien entfernen
6. Build ausfuehren — sicherstellen dass keine Refs verbleiben
7. Existierende Tests ausfuehren — alle gruen bestaetigen
```

---

## Expected Behavior

Nach dem Cleanup MUSS gelten:

- `DailyIntention.swift` existiert nicht mehr im Dateisystem
- `DisciplineHistoryUITests.swift` existiert nicht mehr im Dateisystem
- `DisciplineTrendUITests.swift` existiert nicht mehr im Dateisystem
- `CategoryTrendUITests.swift` existiert nicht mehr im Dateisystem
- `DebugHierarchyTest.swift` enthaelt keine `testPrintSettingsCoachMode`-Methode und keine `coachDailyNudgesToggle`-Referenz
- `MacToolbarNavigationUITests.swift` enthaelt keine `sun.and.horizon`-Referenz im Toolbar-Test
- `AITaskScoringService.swift` enthaelt den String `"Produktivitaets-Coach"` nicht mehr
- `project.pbxproj` enthaelt keine Refs auf geloeschte Dateien (kein `MINT01FILEREF00001`, `MINT02BUILD0000001`)
- `grep -r "DailyIntention" Sources/` liefert 0 Treffer
- `grep -r "coachModeEnabled" FocusBloxUITests/` liefert 0 Treffer
- iOS Build: 0 Errors, 0 Warnings bezueglich fehlender Dateien
- macOS Build: 0 Errors, 0 Warnings bezueglich fehlender Dateien

---

## Test Plan

**Validierungsstrategie: Build + bestehende Tests gruen**

Kein TDD-RED-Zyklus noetig — das Ticket loescht toten Code. Die Validierung erfolgt durch:

1. **Build-Validierung:**
   ```bash
   xcodebuild build -project FocusBlox.xcodeproj -scheme FocusBlox \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
   Erwartet: SUCCESS, 0 Errors

2. **Grep-Validierung (negative Tests):**
   ```bash
   grep -r "DailyIntention" Sources/ FocusBloxMac/
   grep -r "coachModeEnabled" FocusBloxUITests/
   grep -r "sun.and.horizon" FocusBloxMacUITests/
   grep -r "Produktivitaets-Coach" Sources/
   grep -r "MINT01FILEREF00001" FocusBlox.xcodeproj/
   ```
   Alle muessen 0 Treffer liefern.

3. **Unit Tests — alle gruen:**
   ```bash
   xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
     -destination 'id=1EC79950-6704-47D0-BDF8-2C55236B4B40'
   ```
   Erwartet: Alle verbleibenden Tests GRUEN (keine geloeschten Tests fehlen im Ergebnis als Failure)

---

## Known Limitations

- `BUG_114` in `docs/ACTIVE-todos.md` referenziert `coachBoostedIDs.getter` im Stack-Trace — dieser Code existiert nicht mehr. BUG_114 Status muss nach diesem Cleanup separat geprueft werden (moeglicherweise bereits geloest durch 5f6ae47).
- Dead-Code-Nest (`DisciplineTrendChart.swift`, `ReviewComponents.swift`, `DisciplineStatsService.swift`) hat nach Coach-Entfernung keine View-Aufrufer mehr — das ist ein separates TD-Ticket (`TD_003`) und ist NICHT Scope dieses Tickets.
- `docs/ACTIVE-todos.md` BUG_114 Stack-Trace-Update ist in der Kontext-Datei als Teil von Ticket A aufgefuehrt, wird aber als redaktionelle Aenderung behandelt und benoetigt keinen eigenen TDD-Zyklus.

---

## Changelog

- 2026-03-20: Initial spec created
