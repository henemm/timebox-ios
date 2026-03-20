# Context: Monster-Removal Validation

## Request Summary
Prüfung ob Commit 5f6ae47 (Entfernung des Monster/Coach-Features) vollständig war. Lücken identifizieren und umfangreiche Validierungstests erstellen.

## Ergebnis der Lücken-Analyse

### LÜCKE 1: `DailyIntention.swift` — Tote Datei (NICHT gelöscht)
| File | Relevanz |
|------|----------|
| `Sources/Models/DailyIntention.swift` | 132 LoC, NICHT mehr referenziert — komplett verwaist |

- Datei enthält `IntentionOption` enum + `DailyIntention` struct + Filter-Logik
- **Kein einziger Import** in Sources/ oder FocusBloxMac/ — reine tote Datei
- Noch im Xcode-Projekt referenziert (MINT01FILEREF00001, MINT02BUILD0000001)
- **Aktion:** Datei löschen + aus project.pbxproj entfernen

### LÜCKE 2: 3 Verwaiste UI-Test-Dateien (Coach-Mode Tests)
| File | Problem |
|------|---------|
| `FocusBloxUITests/DisciplineHistoryUITests.swift` | Testet `CoachMeinTagView` — View existiert nicht mehr |
| `FocusBloxUITests/DisciplineTrendUITests.swift` | Testet `CoachMeinTagView` Trend-Segment — existiert nicht mehr |
| `FocusBloxUITests/CategoryTrendUITests.swift` | Testet Category-Trend in Coach-Mode — existiert nicht mehr |

- Alle 3 nutzen `launchWithCoachMode()` mit `-coachModeEnabled` Launch-Argument
- Alle navigieren zu "Mein Tag" Tab — Tab existiert nicht mehr
- **Aktion:** Dateien löschen + aus project.pbxproj entfernen

### LÜCKE 3: `DebugHierarchyTest.swift` — Veraltete Coach-Referenzen in Kommentaren
| File | Problem |
|------|---------|
| `FocusBloxUITests/DebugHierarchyTest.swift` | Coach-Mode Kommentare + `coachDailyNudgesToggle` ID |

- Debug-Datei (nicht für produktive Tests)
- Enthält veraltete Coach-Referenzen in Kommentaren und Test-Code
- **Aktion:** Coach-Referenzen bereinigen oder Datei löschen

### LÜCKE 4: `MacToolbarNavigationUITests.swift` — Coach-Mode Fallback
| File | Problem |
|------|---------|
| `FocusBloxMacUITests/MacToolbarNavigationUITests.swift` Zeile 79-88 | Coach-Mode Icon-Fallback ("sun.and.horizon") |

- Test prüft ob "chart.bar" ODER "sun.and.horizon" (Coach-Mode) existiert
- Coach-Mode gibt es nicht mehr → Fallback ist toter Code
- **Aktion:** Coach-Fallback entfernen, nur "chart.bar" prüfen

### LÜCKE 5: AI-Prompt String (harmlos)
| File | Problem |
|------|---------|
| `Sources/Services/AITaskScoringService.swift` Zeile 110 | "Produktivitaets-Coach" im AI-Prompt |

- Kontextual für KI-Rolle, KEIN funktionaler Coach-Code
- **Aktion:** Optional zu "Produktivitaets-Assistent" ändern (low priority)

### LÜCKE 6: `BUG_114` Beschreibung referenziert `coachBoostedIDs`
| File | Problem |
|------|---------|
| `docs/ACTIVE-todos.md` BUG_114 | Stack-Trace enthält `coachBoostedIDs.getter` — Code existiert nicht mehr |

- Bug-Beschreibung ist veraltet — der referenzierte Code wurde entfernt
- Bug könnte durch die Entfernung bereits gelöst sein
- **Aktion:** BUG_114 Status prüfen und ggf. schließen

## Bestandsaufnahme: Was wurde KORREKT entfernt

| Kategorie | Status |
|-----------|--------|
| CoachType.swift | ✅ Gelöscht |
| CoachMission/Pitch Services | ✅ Gelöscht |
| CoachBacklog Views + ViewModel | ✅ Gelöscht |
| CoachMeinTagView | ✅ Gelöscht |
| MorningIntentionView | ✅ Gelöscht |
| EveningReflectionCard + Service | ✅ Gelöscht |
| IntentionEvaluationService | ✅ Gelöscht |
| Monster Images (iOS + Mac) | ✅ Gelöscht |
| Siri Intents (Intention + Evening) | ✅ Gelöscht |
| AppShortcuts (Coach) | ✅ Gelöscht |
| Settings Coach-Section (iOS) | ✅ Bereinigt |
| MacSettingsView | ✅ Gelöscht |
| MacCoachReviewView | ✅ Gelöscht |
| SyncedSettings Coach-Keys | ✅ Bereinigt |
| AppSettings Coach-Keys | ✅ Bereinigt |
| NotificationService Coach-Notifications | ✅ Bereinigt |
| BacklogView Coach-Filter | ✅ Bereinigt |
| MainTabView "Mein Tag" Tab | ✅ Entfernt |
| Discipline.imageName → SF Symbols | ✅ Refactored |
| 33 Test-Dateien | ✅ Gelöscht |

## Validierungstests — Strategie

### Phase A: Entfernungs-Validierung (Negative Tests)
- Keine Monster/Coach-Referenzen im aktiven Code
- Keine "Mein Tag" Tab
- Keine Coach-Settings
- Keine Morning Intention UI
- Keine Evening Reflection UI
- Keine Monster-Images

### Phase B: Bestehende Funktionalität (Positive Tests)
- 4-Tab-Navigation funktioniert (Backlog, Blöcke, Fokus, Rückblick)
- Discipline-Klassifizierung funktioniert ohne Coach
- Task-Scoring funktioniert ohne Coach-Boost
- Settings-View hat keine Coach-Section
- BacklogView zeigt alle View-Modes korrekt
- Review-View funktioniert ohne CoachMeinTag

## Analysis

### Type
Refactoring + Validation (Cleanup verwaister Artefakte + Regressionstests)

### Ticket-Split (Scoping-Limit: 4-5 Dateien, ±250 LoC)

**Ticket A — Dead Code Cleanup (~-407 LoC)**

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/DailyIntention.swift` | DELETE | 131 LoC tote Datei, kein Import |
| `FocusBloxUITests/DisciplineHistoryUITests.swift` | DELETE | 80 LoC, testet geloeschte CoachMeinTagView |
| `FocusBloxUITests/DisciplineTrendUITests.swift` | DELETE | 73 LoC, testet geloeschtes Trend-Segment |
| `FocusBloxUITests/CategoryTrendUITests.swift` | DELETE | 71 LoC, testet geloeschten Coach-Trend |
| `FocusBloxUITests/DebugHierarchyTest.swift` | MODIFY | testPrintSettingsCoachMode() entfernen (~40 LoC) |
| `FocusBloxMacUITests/MacToolbarNavigationUITests.swift` | MODIFY | Coach-Fallback Zeilen 79-88 entfernen (~12 LoC) |
| `Sources/Services/AITaskScoringService.swift` | MODIFY | Zeile 110: "Coach" → "Assistent" (1 LoC) |
| `FocusBlox.xcodeproj/project.pbxproj` | MODIFY | PBX-Refs fuer geloeschte Dateien entfernen |
| `docs/ACTIVE-todos.md` | MODIFY | BUG_114 Stack-Trace aktualisieren |

**Ticket B — Validierungstests (~+80 LoC)**

| File | Change Type | Description |
|------|-------------|-------------|
| Neuer Test oder existierende erweitern | CREATE/MODIFY | Negative Tests: kein Coach-Tab, keine Coach-Settings |
| `FocusBloxTests/TaskPriorityScoringServiceTests.swift` | MODIFY | Regression: kein Coach-Boost im Score |
| `FocusBloxTests/DisciplineTests.swift` | MODIFY | Regression: keine Coach-Override-Logik |

### Scope Assessment
- **Ticket A:** 9 Dateien (6 DELETE, 3 MODIFY), -407 LoC, Risiko: LOW
- **Ticket B:** 2-3 Dateien, +60-80 LoC, Risiko: LOW
- **Gesamt:** ~12 Dateien, -327 LoC netto

### Entdecktes Dead-Code-Nest (separates TD-Ticket)
Folgende Dateien haben nach Coach-Entfernung KEINE Aufrufer mehr in Views:
- `Sources/Views/DisciplineTrendChart.swift` — kein Aufrufer
- `Sources/Views/ReviewComponents.swift` — DisciplineBar-Structs ohne Aufrufer
- `Sources/Services/DisciplineStatsService.swift` — nur noch in Unit Tests
→ Empfehlung: `TD_003` im Backlog anlegen

### Reihenfolge
1. Ticket A zuerst (Cleanup) — kein Risiko, sofort commitbar
2. Ticket B danach (Tests) — erst wenn A committed und gruen ist

### Risks & Considerations
- BUG_114 koennte durch Coach-Entfernung geloest sein (Stack Trace referenziert entfernten Code)
- DailyIntention.swift verursacht keine Build-Fehler, aber belastet den Compile-Prozess unnoetig
- Verwaiste Tests koennten bei Test-Runs fehlschlagen und irrefuehrende Ergebnisse liefern
- Dead-Code-Nest (DisciplineTrendChart etc.) ist harmlos aber sollte als TD_003 getrackt werden
