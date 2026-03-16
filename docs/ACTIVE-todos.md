# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!
> **Archiv:** Erledigte Items → `docs/ARCHIVE-todos.md`

---

## Priorisierte Reihenfolge (nur offene Items)

| Prio | Item | Typ | Kompl. | Warum diese Reihenfolge? |
|------|------|-----|--------|--------------------------|
| **1** | Coach-Redesign abschliessen | Feature | S | DONE — 116 Unit Tests + 14 UI Tests gruen. Committed. |
| **2** | Bug 102: Coach-Sync iOS↔macOS | Bug P0 | S-M | DONE — pullFromCloud() vor pushToCloud(), Guard gegen leere Coach-Pushes. 7 Unit + 2 UI Tests gruen. |
| **3** | Phase 6d: Abend-Spiegel macOS | Feature | S-M | DONE — EveningReflectionCard in MacCoachReviewView (angezeigt ab 18:00). 7 UI Tests gruen (4 Phase 6c + 3 neue). |
| **4** | Phase 6e: CoachMeinTagView macOS | Feature | M | DONE — MacCoachReviewView geloescht, shared CoachMeinTagView mit #if os(). macOS bekommt AI-Abend-Text. 7+3 UI Tests gruen. |
| **5** | Bug 101: macOS 5 statt 4 Views | Bug | M | DONE — Assign entfernt, MainSection 5→4, MacAssignView geloescht (-720 LoC). 6 UI + 2 Unit Tests gruen. |
| **6** | Bug 98: Mein Tag Woche unvollstaendig | Bug | S-M | DONE — DailyReviewView Guard gefixt + CoachMeinTagView Weekly Mode mit Coach-Texten. 68 Unit Tests gruen. |
| **7** | Discipline manuell ueberschreiben | Feature | M | DONE — Long-Press Context Menu mit 4 farbigen Disziplin-Optionen + Zuruecksetzen. iOS + macOS. 10 Unit + 6 UI Tests gruen. |
| **8** | Coach Mission Card | Feature | S | DONE — Monster spricht mit konkreter Tages-Mission an. Pro Coach eigene Logik. 10 Unit Tests gruen. iOS + macOS Build OK. |
| **8b** | Coach Preview + AI Pitches | Feature | S | DONE — Coach-Auswahl zeigt konkrete Tasks + Apple Intelligence Pitches. Empfohlen-Badge. 23 Tests gruen. |
| **9** | Bug 104: Coach-Backlog Feature-Paritaet iOS+macOS | Bug P1 | M | DONE — Volle Feature-Paritaet: ViewMode-Switcher (5 Modi), Coach-Boost-Section, Priority-Tiers, alle Callbacks, Blocked Tasks, Undo, Sync. iOS + macOS. 24 Unit Tests gruen. |
| **10** | UX: Tag-Auswahl redesignen | Enhancement | S | Tag-Sektion in TaskFormSheet ist unuebersichtlich: "Neuer Tag" Textfeld dominiert, bestehende Tags kommen erst danach. Redesign: Bestehende Tags zuerst als antippbare Chips (Toggle-Auswahl), "Neuer Tag" Textfeld darunter. Vorbild: Apple Erinnerungen. |
| **11** | Watch: Quick Capture vereinfachen | Bug | S | Komplikation-Tap zeigt unnoetig "Was moechtest du tun?" + Abbrechen. Soll direkt Spracheingabe oeffnen, nach "Fertig" sofort speichern. Kein Zwischenscreen, keine Rueckfragen. War nie anders spezifiziert. |
| **12** | TD-03: Services ohne Tests | Tech Debt | M | DONE — 44 Unit Tests (GapFinder 15, NotificationService 17, FocusBlockActionService 12). Sicherheitsnetz fuer 3 Services. |
| **13** | Disziplin-Entwicklung sichtbar machen | Feature | M | Historische Auswertung ueber Wochen/Monate — welche Disziplinen gestaerkt? |
| **14** | Stille-Regel: Nudges dynamisch canceln | Enhancement | S | Geplante Nudges stoppen wenn Intention tagsueber erfuellt wird. |
| **15** | MAC-026: Enhanced Quick Capture | Feature | L | macOS Produktivitaet. Kein Blocker. |
| **16** | TD-01: God-Views aufbrechen | Tech Debt | L | BacklogView 1181 LoC, BlockPlanningView 1400 LoC — Wartbarkeit. |
| **17** | MAC-030: Shortcuts.app | Feature | L | macOS Automatisierung. P3. |
| **18** | MAC-031: Focus Mode Integration | Feature | M | macOS System-Integration. P3. |
| **19** | TD-02: View-Duplikation | Tech Debt | XL | ~7300 LoC. Langfristig wichtig, kurzfristig kein Blocker. |
| **20** | ITB-C: OrganizeMyDay Intent | Feature | XL | Komplexer Intent. Kann warten. |
| **21** | ITB-F: CaptureContextIntent | Feature | M | WARTEND auf Apple APIs (iOS 26.5/27). |

---

## Offene Bugs

### Bug 104: Coach-Backlog Feature-Paritaet — iOS + macOS — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Problem:** CoachBacklogView (iOS) und MacCoachBacklogView (macOS) fehlten zahlreiche Features der normalen BacklogView.
- **Fix (7 Pakete):**
  - P0: macOS Completion-Button repariert (onToggleComplete verdrahtet)
  - P1: CoachBacklogViewModel erweitert: coachBoostedTasks, remainingTasks, overdueTasks, tierTasks, recentTasks, completedTasks, recurringTasks, coachSectionTitle (shared Logic)
  - P2a: iOS alle Callbacks verdrahtet (11 BacklogRow-Closures), DurationPicker/CategoryPicker Sheets, TaskFormSheet, Postpone-Kontextmenu, DeferredSort/Completion
  - P2b: iOS ViewMode-Switcher (5 Modi: Prioritaet/Zuletzt/Ueberfaellig/Wiederkehrend/Erledigt), Coach-Boost-Section, Priority-Tier-Sections (4 Stufen), deduplizierte Task-Zuordnung
  - P3: macOS volle Paritaet: ViewMode-Switcher, alle MacBacklogRow-Callbacks, Tier-Sections, Coach-Boost, Postpone/Disziplin/Delete Context-Menu
  - P4: iOS CloudKit Sync Auto-Refresh + Shake-to-Undo
  - P5: Blocked-Task-Rendering (Lock-Icon, Einrueckung, Freigeben-Aktion) auf beiden Plattformen
- **Tests:** 24 CoachBacklogViewModelTests gruen (7 neue Methoden getestet)
- **Dateien:** CoachBacklogViewModel.swift, CoachBacklogView.swift, MacCoachBacklogView.swift, CoachBacklogViewModelTests.swift
- **Verbleibend (bewusst nicht im Scope):** Recurring-Serie-Dialoge, macOS Inspector, macOS Quick-Add, macOS Drag-Reorder — separate Tickets

### Bug 103: NextUp-Section fehlt in Monster-Modus — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Root Cause:** CoachBacklogView wurde in Phase 5a mit nur 2 Sections ("Dein Schwerpunkt" + "Weitere Tasks") designed — eine dedizierte NextUp-Section wurde nie implementiert. NextUp-Tasks waren unsichtbar in der Masse. macOS hatte zusaetzlich keinen NextUp-Toggle.
- **Fix:** (1) `CoachBacklogViewModel.nextUpTasks()` als neue Filterfunktion, (2) NextUp-Section mit gruenem Header + Count-Badge in CoachBacklogView (iOS) + MacCoachBacklogView (macOS), (3) NextUp-Tasks aus "Dein Schwerpunkt" und "Weitere Tasks" ausgeschlossen (keine Duplikation), (4) macOS Context-Menu um "Zu Next Up hinzufuegen/entfernen" erweitert
- **Tests:** 5 Unit Tests + 2 iOS UI Tests + 1 macOS UI Test — alle gruen
- **Dateien:** CoachBacklogViewModel.swift, CoachBacklogView.swift, MacCoachBacklogView.swift, CoachBacklogViewModelTests.swift, CoachBacklogViewUITests.swift, MacCoachBacklogUITests.swift

### Bug: macOS Coach Backlog leer im Monster-Mode — ERLEDIGT
- **Status:** DONE
- **Plattform:** macOS
- **Root Cause:** `.task { refreshTasks() }` war an `backlogView` gebunden — bei `coachModeEnabled == true` wird `backlogView` nie gerendert, daher lief `refreshTasks()` nie.
- **Fix:** `.task` und `.onChange` von `backlogView` auf NavigationSplitView verschoben + `cloudKitDatabase: .none` fuer In-Memory-Test-Container.
- **Dateien:** ContentView.swift, FocusBloxMacApp.swift

### Bug 102: Coach-Wahl wird NICHT zwischen iOS und macOS synchronisiert — P0
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Root Cause:** pushToCloud() ueberschrieb valide Remote-Daten mit leeren lokalen Werten weil pullFromCloud() nie proaktiv aufgerufen wurde.
- **Fix:** (1) pullFromCloud() vor pushToCloud() auf beiden Plattformen, (2) Guard gegen leere Coach-Pushes, (3) pullFromCloud() in SyncedSettings.init()
- **Tests:** 7 Unit Tests (Guard-Logik) + 2 UI Tests (Synced Coach Header) — alle gruen
- **Dateien:** SyncedSettings.swift, FocusBloxApp.swift, FocusBloxMacApp.swift

### Bug 98: Mein Tag Woche zeigt nur Sprint-Tasks — ausserhalb Sprints erledigte fehlen
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Root Cause:** Zwei Probleme: (1) DailyReviewView Guard `weekBlocks.isEmpty` war zu restriktiv — zeigte leeren Zustand auch wenn Tasks ohne Sprint erledigt wurden. (2) CoachMeinTagView hatte keine Wochenansicht.
- **Fix:** (1) Guard erweitert auf `weekBlocks.isEmpty && weekCompletedTasks.isEmpty` + weekOutsideSprintSection hinzugefuegt. (2) CoachMeinTagView bekommt Heute/Diese-Woche-Picker mit Weekly-Fulfillment-Bewertung + motivierenden Coach-Wochen-Texten (AI + 12 Fallback-Templates).
- **Tests:** 48 IntentionEvaluationServiceTests + 20 EveningReflectionTextServiceTests — alle gruen
- **Dateien:** DailyReviewView.swift, CoachMeinTagView.swift, IntentionEvaluationService.swift, EveningReflectionTextService.swift

### Bug 101: macOS hat 5 Views statt 4 — Unified Calendar View nicht umgesetzt — ERLEDIGT
- **Status:** DONE
- **Plattform:** macOS
- **Root Cause:** iOS wurde am 03.03.2026 von 5 auf 4 Tabs konsolidiert (Commit 4861e2f). macOS wurde nie nachgezogen.
- **Fix:** `.assign` aus MainSection Enum entfernt, MacAssignView.swift geloescht (-463 LoC), UnifiedBlockNavigationUITests geloescht (-250 LoC). MacPlanningView unveraendert (hatte bereits FocusBlockTasksSheet).
- **Tests:** 6/6 MacToolbarNavigationUITests + 2/2 UnifiedTabSymbolsTests gruen. Neuer Test: testNoAssignSectionExists.
- **Netto:** ~-720 LoC

## Erledigte Bugs (Archiv-Kandidaten)

<details>
<summary>Bug 93, 94, 95, 96, 97, 99, 100, Abend-Review — alle ERLEDIGT</summary>

### Bug 94: macOS — Neuer Task bekommt keinen Fokus — ERLEDIGT
- **Commit:** 5986c27

### Bug 95: Neue Tasks bekommen immer Faelligkeitsdatum "heute" — ERLEDIGT

### Bug 96: Apple Shortcut oeffnet App statt Hintergrund-Save — ERLEDIGT

### Bug 97: Apple Shortcut — "heute" nicht als Datum erkannt — ERLEDIGT

### Bug 93: Swipe-Gesten bei eingerueckten Tasks — ERLEDIGT
- **Commit:** 271d993

### Bug 99: CoachBacklogView — Next-Up-Swipe fehlt — ERLEDIGT

### Bug 100: Intention-Labels — ERLEDIGT (OBSOLET nach Coach-Redesign)

### Bug: Abend-Review Text zu generisch — ERLEDIGT

</details>

---

## BACKLOG: Feature — Monster Coach Phase 3 "Der Tagesbogen" — KOMPLETT ERLEDIGT

- **User Story:** `docs/project/stories/monster-coach.md`
- **Vision:** Morgen → Tag → Abend als durchgaengiges Coach-Erlebnis.
- **Hinweis:** Phase 3 wurde mit dem alten 6-Intentionen-System gebaut. Seit dem **Coach-Redesign** (4 Coaches statt 6 Absichten) nutzt der gesamte Code `CoachType` statt `IntentionOption`. Die Grundfunktionalitaet bleibt identisch.

**Aktuelle Grundlage (nach Redesign):**
- `Sources/Models/CoachType.swift` — 4 Coaches: Troll, Feuer, Eule, Golem (ersetzt IntentionOption)
- `Sources/Models/DailyCoachSelection.swift` — Tages-Coach-Wahl (ersetzt DailyIntention)
- `Sources/Views/MorningIntentionView.swift` — Coach-Auswahl Grid
- `Sources/Services/IntentionEvaluationService.swift` — Coach-basierte Fulfillment + Gap-Erkennung
- `Sources/Services/EveningReflectionTextService.swift` — Coach-persoenlichkeitsbasierte AI-Texte
- Phase 3a-3f: ALLE ERLEDIGT

### Phase 3c: Abend-Spiegel mit automatischer Auswertung (Must) — ERLEDIGT
- FulfillmentLevel pro Coach: Troll (aufgeschobene Tasks), Feuer (grosse Tasks), Eule (Block-Completion), Golem (Kategorie-Balance)
- EveningReflectionCard mit Stimmungs-Farbe, Badge, Coach-spezifische Fallback-Templates
- **Dateien:** EveningReflectionCard.swift, IntentionEvaluationService.swift, DailyReviewView.swift

### Phase 3d: Foundation Models Abend-Text (Must) — ERLEDIGT
- buildPrompt() mit Coach-Persoenlichkeit, FulfillmentLevel, erledigten Tasks (nach Coach-Relevanz sortiert, max 5)
- Coach-spezifische Schwerpunkt-Guidance (Troll: aufgeschobene Tasks, Feuer: grosse Herausforderung, Eule: Focus-Blocks, Golem: Kategorie-Balance)
- **Dateien:** EveningReflectionTextService.swift, EveningReflectionCard.swift

### Phase 3e: Abend Push-Notification (Should) — ERLEDIGT
- Konfigurierbare Abend-Push-Notification mit Coach-Monster-Attachment
- Nur wenn coachModeEnabled UND Coach gewaehlt
- **Dateien:** NotificationService.swift, AppSettings.swift, SettingsView.swift, FocusBloxApp.swift

### Phase 3f: Siri Integration / App Intents (Should) — ERLEDIGT
- GetEveningSummaryIntent: "Wie war mein Tag?" — Siri liest Coach-Abend-Auswertung vor
- SetDailyIntentionIntent: "Waehle Troll als Coach" — setzt Tages-Coach per Sprache
- CoachTypeEnum: AppEnum mit 4 deutschen Siri-Titeln (Troll, Feuer, Eule, Golem)
- **Dateien:** CoachType.swift, CoachTypeEnum.swift, GetEveningSummaryIntent.swift, SetDailyIntentionIntent.swift, FocusBloxShortcuts.swift

---

## BACKLOG: Feature — Monster Coach Phase 4 "Monster-Grafiken & Visualisierung" — KOMPLETT ERLEDIGT

- **User Story:** `docs/project/stories/monster-coach.md`
- **Kontext:** 4 Monster-Grafiken (PNG, transparent) fuer die 4 Coaches. Seit dem Redesign ist das Mapping direkt: Jeder Coach HAT ein Monster (1:1 statt frueher 6→4 Mapping).

### Phase 4a: Monster-Assets einbinden (Must) — ERLEDIGT
- 4 PNGs: monsterFokus (Eule), monsterMut (Feuer), monsterAusdauer (Golem), monsterKonsequenz (Troll)
- `Discipline.imageName` + `CoachType.discipline` Mapping (jeder Coach = eine Discipline)
- **Dateien:** Discipline.swift, CoachType.swift, Assets.xcassets (4 ImageSets)

### Phase 4b-4e: ALLE ERLEDIGT
- Monster in Coach-Auswahl, Abend-Spiegel, Push-Notifications
- `buildMonsterAttachment(for: CoachType)` — `coach: CoachType? = nil` Parameter
- **Dateien:** MorningIntentionView.swift, EveningReflectionCard.swift, NotificationService.swift

### Feature: Discipline manuell ueberschreiben — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Aenderung:** Long-Press/Right-Click auf Task im Coach-Backlog zeigt Context Menu mit 4 farbigen Disziplin-Optionen (Konsequenz=gruen, Ausdauer=grau, Mut=rot, Fokus=blau) + "Zuruecksetzen". Override hat Vorrang vor Auto-Berechnung, aendert Checkbox-Kreisfarbe. Coach-Sektionszuordnung bleibt unabhaengig.
- **Fix:** `manualDiscipline: String?` auf LocalTask, `Discipline.resolveOpen()` fuer Override-Logik, `SyncEngine.updateDiscipline()`, Context Menu auf coachRow() (iOS + macOS)
- **Tests:** 10 Unit Tests (6 neue resolveOpen + 4 bestehende) + 6 UI Tests (5 bestehende + 1 neuer Context Menu) — alle gruen
- **Dateien:** Discipline.swift, LocalTask.swift, PlanItem.swift, CoachBacklogView.swift, MacCoachBacklogView.swift, SyncEngine.swift
- **Spec:** `docs/specs/features/discipline-override.md`

---

## BACKLOG: Feature — Monster Coach Phase 5 "Eigene Coach-Views"

- **User Story:** `docs/project/stories/monster-coach.md`
- **Kontext:** Coach-Modus = eigene Views statt Modifikationen an bestehenden Views. Saubere Trennung: Coach AN zeigt pro Tab eine eigene View, Coach AUS bleibt wie bisher.
- **Gesamtkonzept:** `docs/context/feature-coach-views.md`

### Phase 5a: CoachBacklogView (Must) — ERLEDIGT
- Coach-Modus AN → Backlog-Tab zeigt CoachBacklogView statt BacklogView
- Monster-Header zeigt transparent den aktiven Coach
- Zwei Sektionen: "Dein Schwerpunkt" (Coach-gefilterte Tasks) + "Weitere Tasks" (Rest)
- Filter-Logik: `CoachBacklogViewModel.relevantTasks(from:selectedCoach:)`
- **Dateien:** CoachBacklogView.swift, CoachBacklogViewModel.swift, MainTabView.swift

### Phase 5b: CoachMeinTagView (Must) — ERLEDIGT
- Coach-Modus AN → "Mein Tag"-Tab zeigt CoachMeinTagView statt DailyReviewView
- MorningIntentionView + EveningReflectionCard in eigenem Layout
- Tages-Fortschritt ("X Tasks erledigt") mit coachDayProgress ID
- **Dateien:** CoachMeinTagView.swift, MainTabView.swift, DailyReviewView.swift, FocusBloxApp.swift

---

## BACKLOG: Feature — Monster Coach Phase 6 "macOS-Paritaet"

- **Kontext:** Coach-Modus (4 Coaches: Troll/Feuer/Eule/Golem) ist auf iOS komplett. Business-Logik liegt shared in `Sources/`. macOS hat Settings + Backlog + Coach-Auswahl — fehlen noch Abend-Spiegel und volle Mein-Tag-View.
- **Abhaengigkeit:** Phase 5b (CoachMeinTagView iOS) ist ERLEDIGT.

### Phase 6a: Coach-Settings in macOS (Must) — ERLEDIGT
### Phase 6b: CoachBacklogView in macOS (Must) — ERLEDIGT
### Phase 6c: Coach-Auswahl in macOS (Must) — ERLEDIGT

### Phase 6d: EveningReflectionCard in macOS (Must) — ERLEDIGT
- Shared EveningReflectionCard erfolgreich in MacCoachReviewView eingebettet (angezeigt ab 18:00)
- Coach-Fulfillment mit Monster-Icon und Fallback-Template (KI-Text nicht verfuegbar auf macOS, EveningReflectionTextService nicht im macOS-Target)
- Guard gegen `coach == nil` verhindert Anzeige ohne Coach-Wahl
- **Dateien:** MacCoachReviewView.swift, MacCoachReviewUITests.swift (3 neue Tests), FocusBloxMacApp.swift (-MockIntentionSet Support)
- **Tests:** 7 UI Tests gruen (4 bestehend + 3 neue Phase 6d)

### Phase 6e: CoachMeinTagView in macOS (Should) — ERLEDIGT
- Shared `CoachMeinTagView` ersetzt `MacCoachReviewView` (82 Zeilen geloescht)
- `#if os(macOS)` fuer NavigationStack vs .frame(), sonst identisch
- EventKit via `@Environment(\.eventKitRepository)` statt `@State` (konsistent mit allen anderen Views)
- macOS bekommt jetzt auch AI-Abend-Text (Feature-Paritaet)
- **Dateien:** CoachMeinTagView.swift (edit), ContentView.swift (1 Zeile), MacCoachReviewView.swift (deleted), project.pbxproj (2 Build-File-Refs)
- **Tests:** 7/7 MacCoachReviewUITests + 3/3 CoachMeinTagUITests gruen
- **Netto:** ~-70 LoC

---

### Coach Preview + Apple Intelligence Pitches — ERLEDIGT
- **Status:** DONE
- **Plattform:** iOS + macOS
- **Aenderung:** Coach-Auswahl zeigt jetzt konkrete Tasks statt generische shortPitch-Texte. Jeder Coach zeigt was er heute anpacken wuerde (z.B. "3 aufgeschoben — z.B. Steuererklaerung"). Apple Intelligence generiert In-Character Pitches. Coach mit staerkstem Angebot bekommt Empfohlen-Badge.
- **Neue Typen:** `CoachPreview`, `CoachPitchService`
- **Logik:** Deterministischer Teaser sofort sichtbar → AI-Pitch laedt asynchron im Hintergrund → Text-Swap mit Animation
- **Tests:** 8 CoachPreviewTests + 5 CoachPitchServiceTests + 10 CoachMissionServiceTests = 23 Tests gruen
- **Dateien:** CoachMissionService.swift, CoachPitchService.swift (neu), MorningIntentionView.swift, CoachMeinTagView.swift, MacCoachReviewView.swift

### Coach-Redesign: 4 Coaches statt 6 Absichten — ERLEDIGT
- **Status:** ERLEDIGT (116 Unit Tests + 14 UI Tests gruen)
- **Plattform:** iOS + macOS
- **Aenderung:** 6 Morgen-Absichten ersetzt durch 4 Monster-Coaches mit klarer Persoenlichkeit
- **Coaches:** Troll (aufgeschobene Tasks), Feuer (wichtige Tasks), Eule (geplante Tasks max 3), Golem (Kategorie-Balance)
- **Neue Typen:** `CoachType`, `DailyCoachSelection`, `CoachGap`, `CoachTypeEnum`
- **Tests:** 116 Unit Tests gruen, iOS + macOS Build SUCCEEDED

---

## Backlog (Technical Debt)

### Verbleibende Tech-Debts (dokumentiert in `docs/context/tech-debt-analysis.md`)
- **TD-01:** God-Views (BlockPlanningView 1400 LoC, BacklogView 1181 LoC) — Aufwand: L
- **TD-02:** iOS/macOS View-Duplikation — Paket 1-3 ERLEDIGT (Badges, Sheets, Header: ~412 LoC eliminiert). TD-05 Coach-Pilot ERLEDIGT (~180 LoC konsolidiert). Verbleibend: ~7300 LoC, Aufwand: XL
- **TD-03:** 3 Services ohne Unit Tests (NotificationService, FocusBlockActionService, GapFinder) — Aufwand: M

### TD-04: Parallele Claude Code Sessions absichern — ERLEDIGT
- parallel_test_guard las falsche JSON-Datei (komplett funktionslos)
- test_lock_guard war nicht in settings.json registriert
- File-Overlap war nur WARNING statt BLOCK
- Kein File-Locking auf workflow_state.json (Korruptionsgefahr)
- **Fix:** load_state Import, fcntl.flock Locking, Overlap→Block, test_lock_guard registriert
- **Dateien:** parallel_test_guard.py, workflow_state_multi.py, strict_code_gate.py, settings.json
- **Nachtrag:** Phase-Eintritt-Guard hinzugefuegt — `set_phase()`, `advance_phase()`, `mark_red_test_done()` blockieren Betreten von TDD-Phasen wenn anderer Workflow dort aktiv ist (48h Stale-Threshold, Re-Enter erlaubt). Zwei-Layer-Schutz: Phase-Eintritt + xcodebuild-Guard.

### TD-05: Coach Views Cross-Platform Consolidation (Pilot) — ERLEDIGT
- Duplizierte Filter-Logik in shared `CoachBacklogViewModel` extrahiert (`relevantTasks`, `otherTasks`, `parseCoach`)
- MonsterIntentionHeader und DayProgressSection als shared Components in Sources/Views/Components/
- Seit Coach-Redesign: Filter nutzt `CoachType`-basierte Logik (Troll: rescheduleCount>=2, Feuer: importance==3, Eule: isNextUp max 3, Golem: Kategorie-Balance)
- **14 Unit Tests gruen** (CoachBacklogViewModelTests)
- **Dateien:** CoachBacklogViewModel.swift, MonsterIntentionHeader.swift, DayProgressSection.swift, CoachBacklogView.swift, MacCoachBacklogView.swift, MacCoachReviewView.swift, CoachMeinTagView.swift

---

## Status-Legende

| Status | Bedeutung |
|--------|-----------|
| **OFFEN** | Noch nicht begonnen |
| **SPEC READY** | Spec geschrieben & approved, Implementation ausstehend |
| **IN ARBEIT** | Aktive Bearbeitung |
| **ERLEDIGT** | Fertig → verschoben nach `docs/ARCHIVE-todos.md` |
| **BLOCKIERT** | Kann nicht fortgesetzt werden |

---

> **Dies ist das EINZIGE Backlog.** macOS-Features (MAC-xxx) stehen hier mit Verweis auf ihre Specs in `docs/specs/macos/`. Kein zweites Backlog.
> **Archiv:** Alle erledigten Items → `docs/ARCHIVE-todos.md`
