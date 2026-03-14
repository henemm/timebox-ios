# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!
> **Archiv:** Erledigte Items → `docs/ARCHIVE-todos.md`

---

## Bugs (offen)

### Bug 94: macOS — Neuer Task ueber Eingabeschlitz bekommt keinen Fokus
- **Status:** ERLEDIGT
- **Plattform:** macOS
- **Symptom:** Wenn man ueber den Eingabeschlitz einen neuen Task anlegt ("+"-Button), liegt der Fokus anschliessend NICHT auf dem neu erstellten Task. Man muss ihn manuell in der Liste suchen.
- **Root Cause:** `addTask()` nutzte `await LocalTaskSource.createTask()` das AI-Enrichment + Title-Improvement (3-8 Sek.) blockierte BEVOR der Inspector-Override gesetzt wurde. Der User sah solange "Kein Task ausgewaehlt".
- **Fix:** Task synchron erstellen (insert + save), Inspector-Override SOFORT setzen, AI-Enrichment im Hintergrund nachlaufen lassen.
- **Tests:** 2 UI Tests stabil gruen (3x3 Durchlaeufe, 100% Passrate)
- **Dateien:** ContentView.swift (macOS), Bug94FocusAfterAddUITests.swift, FocusBloxApp.swift
- **Commit:** 5986c27

### Bug 95: Neue Tasks bekommen immer Faelligkeitsdatum "heute"
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Symptom:** Alle neu erstellten Tasks erhalten automatisch das Faelligkeitsdatum "heute", unabhaengig vom Inhalt oder Kontext.
- **Root Cause:** TaskTitleEngine AI-Enrichment setzte dueDate auf "heute" fuer generische Titel, weil der System-Prompt kein Nil-Beispiel hatte. Die AI halluzinierte Datum-Keywords.
- **Fix:** (1) Deterministische Keyword-Pruefung `titleContainsDateKeyword()` als Guard vor AI-dueDate-Akzeptanz, (2) Nil-Beispiel im AI-Prompt, (3) RecurrenceService Date()-Fallback entfernt.
- **Commit:** (wird nach Commit ergaenzt)

### Bug 97: Apple Shortcut — "heute" im Titel wird nicht als Datum erkannt
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Symptom:** Tasks per Apple Shortcut/Siri mit "heute" im Titel bekamen kein Faelligkeitsdatum. Auch kein Title-Cleanup und keine Urgency-Erkennung.
- **Root Cause:** `CreateTaskIntent.perform()` erstellte Tasks ohne `needsTitleImprovement = true` zu setzen und ohne deterministische Datum-Extraktion. Die TitleEngine-Pipeline wurde nie getriggert.
- **Fix:** (1) Neue `extractDeterministicDueDate(from:)` Funktion fuer sofortige Datum-Extraktion aus Keywords (kein AI noetig), (2) `needsTitleImprovement = true` fuer spaeteres AI Title-Cleanup.
- **Tests:** 6 Unit Tests gruen (TaskTitleEngineTests)
- **Dateien:** CreateTaskIntent.swift, TaskTitleEngine.swift
- **Commit:** (wird nach Commit ergaenzt)

### Bug 96: Apple Shortcut oeffnet FocusBlox komplett statt Hintergrund-Save
- **Status:** ERLEDIGT
- **Plattform:** iOS
- **Symptom:** Der Siri-Shortcut "Task erstellen" oeffnete die App im Vordergrund statt den Task im Hintergrund zu speichern.
- **Root Cause:** Commit 382a5a1 hatte `openAppWhenRun=true` als Workaround gesetzt.
- **Fix:** `openAppWhenRun=false` + direkter SwiftData-Save statt UserDefaults-Handoff.
- **Commit:** (wird nach Commit ergaenzt)

### Bug 93: Swipe-Gesten bei eingerueckten Tasks funktionieren nicht (iOS)
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Root Cause:** `blockedRow()` hatte absichtlich keine `.swipeActions` — blockierte Tasks waren "gefangen".
- **Fix:** Swipe-Aktionen zu `blockedRow()` hinzugefuegt: Bearbeiten, Loeschen, Freigeben (Abhaengigkeit entfernen). macOS: Kontextmenue-Eintrag "Abhaengigkeit entfernen".
- **Tests:** 4 UI Tests gruen (BlockedTaskSwipeUITests)
- **Dateien:** BacklogView.swift (iOS), ContentView.swift (macOS)
- **Commit:** 271d993

---

## BACKLOG: Feature — Monster Coach Phase 3 "Der Tagesbogen"

- **User Story:** `docs/project/stories/monster-coach.md`
- **Vision:** Nach der Morgen-Intention passiert bisher NICHTS. Phase 3 schliesst die Luecke: Morgen → Tag → Abend als durchgaengiges Erlebnis.

**Bisherige Grundlage (Phase 1+2+3a+3b):**
- `Sources/Models/DailyIntention.swift` — Model mit `IntentionOption` Enum
- `Sources/Views/MorningIntentionView.swift` — Selection Grid + Zusammenfassung
- `Sources/Views/DailyReviewView.swift` — Review-Tab
- `Sources/Models/Discipline.swift` — Task-Disziplin Enum
- `Sources/Services/IntentionEvaluationService.swift` — Gap-Erkennung (aus Phase 3b)
- Phase 3a (Backlog-Filter) ERLEDIGT
- Phase 3b (Smart Notifications) ERLEDIGT

### Phase 3c: Abend-Spiegel mit automatischer Auswertung (Must) — ERLEDIGT
- Karte im Review-Tab (`DailyReviewView`) ab 18 Uhr
- FulfillmentLevel (fulfilled/partial/notFulfilled) + evaluateFulfillment() in IntentionEvaluationService
- EveningReflectionCard mit Stimmungs-Farbe, Badge, Fallback-Templates
- 40 Unit Tests + 5 UI Tests gruen
- **Dateien:** EveningReflectionCard.swift (NEU), IntentionEvaluationService.swift, DailyReviewView.swift

### Phase 3d: Foundation Models Abend-Text (Must) — ERLEDIGT
- EveningReflectionTextService: On-Device AI (Foundation Models) generiert persoenlichen Abend-Text
- buildPrompt() mit Intention, FulfillmentLevel, erledigten Tasks (max 5), FocusBlock-Stats
- Fallback auf handgeschriebene Template-Sprueche wenn AI nicht verfuegbar
- DailyReviewView laedt AI-Texte async, Card zeigt sofort Fallback bis AI fertig
- 11 Unit Tests + 2 neue UI Tests gruen (gesamt 7/7 UI Tests)
- **Dateien:** EveningReflectionTextService.swift (NEU), EveningReflectionCard.swift, DailyReviewView.swift

### Phase 3e: Abend Push-Notification (Should) — ERLEDIGT
- Konfigurierbare Abend-Push-Notification (Default 20:00 Uhr)
- Nur wenn coachModeEnabled UND Intention gesetzt (Dreifach-Guard in scenePhase)
- Settings: Toggle "Abend-Erinnerung" + Uhrzeit-Picker im Monster Coach Bereich
- Scheduling: Nach Intention-Save (MorningIntentionView) + bei App-Vordergrund (FocusBloxApp)
- 8 Unit Tests + 3 UI Tests gruen (+ 12 bestehende Coach-Tests unveraendert)
- **Dateien:** NotificationService.swift, AppSettings.swift, SettingsView.swift, MorningIntentionView.swift, FocusBloxApp.swift

### Phase 3f: Siri Integration / App Intents (Should) — ERLEDIGT
- GetEveningSummaryIntent: "Wie war mein Tag?" — Siri liest Abend-Auswertung vor (fallbackTemplate-Texte)
- SetDailyIntentionIntent: "Setz meine Intention auf Fokus" — setzt Tages-Intention per Sprache
- DailyIntention UserDefaults-Migration auf App Group (Siri-Prozess kann Intention lesen/schreiben)
- IntentionOptionEnum: AppEnum mit 6 deutschen Siri-Titeln
- 8 Unit Tests gruen (+ 85 bestehende Intention-Tests unveraendert)
- **Dateien:** DailyIntention.swift, IntentionOptionEnum.swift (NEU), GetEveningSummaryIntent.swift (NEU), SetDailyIntentionIntent.swift (NEU), FocusBloxShortcuts.swift

---

## BACKLOG: Feature — Monster Coach Phase 4 "Monster-Grafiken & Visualisierung"

- **User Story:** `docs/project/stories/monster-coach.md`
- **Kontext:** 4 Monster-Grafiken (PNG, transparent) fuer die 4 Disciplines erstellt. Muessen ins Projekt integriert und an allen relevanten Stellen angezeigt werden.

### Phase 4a: Monster-Assets einbinden (Must) — ERLEDIGT
- 4 PNGs als Image Assets: monsterFokus (Eule), monsterMut (Feuer), monsterAusdauer (Golem), monsterKonsequenz (Troll)
- `Discipline.imageName` computed property + `IntentionOption.monsterDiscipline` Mapping
- 12 Unit Tests gruen (MonsterGraphicsTests)
- **Dateien:** Discipline.swift, DailyIntention.swift, Assets.xcassets (4 ImageSets)

### Phase 4b: Farbiger Discipline-Kreis in Task-Zeilen (Should) — INTEGRIERT IN PHASE 5
- Wird als Teil der neuen Coach-Views umgesetzt (Phase 5a: CoachBacklogView)
- Discipline-Kreise nur in Coach-Views sichtbar, nicht in der normalen BacklogView

### Phase 4c: Monster in Morgen-Dialog (Must) — ERLEDIGT
- Monster-Grafik waehrend Chip-Auswahl (120px, dynamisch wechselnd) UND in Kompakt-Ansicht (44px Circle)
- Mapping: Survival/Balance → Golem, Fokus/Wachstum → Eule, BHAG → Feuer, Verbundenheit → Troll
- 4 UI Tests gruen (MonsterGraphicsUITests)
- **Dateien:** MorningIntentionView.swift

### Phase 4d: Monster im Abend-Spiegel (Must) — ERLEDIGT
- Monster-Icon (40x40 Circle) neben dem Intentions-Label in jeder Zeile der Abend-Karte
- 2 UI Tests SKIPPED (vorbestehendes Problem: EveningReflectionCard nicht sichtbar nach Tab-Wechsel — DailyIntention.load().isSet ist kein reaktives Binding)
- **Dateien:** EveningReflectionCard.swift

### Phase 4e: Monster in Push-Notifications (Could) — OFFEN
- Rich Notifications mit Monster-Bild als Attachment
- **Dateien:** NotificationService.swift

### Ueberlegung: Nutzer beim Kategorisieren der Tasks einbeziehen — OFFEN
- **Kontext:** Aktuell werden Tasks automatisch einer Discipline zugeordnet (AI-basiert via TaskTitleEngine). Der Nutzer hat keinen Einfluss darauf.
- **Ueberlegung:** Soll der Nutzer die Discipline manuell waehlen/korrigieren koennen? Z.B. beim Erstellen oder Bearbeiten eines Tasks.
- **Offene Fragen:** Wie integrieren? Optionaler Picker? Nur bei Coach-Modus? Automatik beibehalten mit Manual-Override?
- **Abhaengigkeiten:** Haengt eng mit Phase 5 (Coach-Views) zusammen — dort werden Disciplines prominent angezeigt. Falsche Zuordnung wuerde dort auffallen.

---

## BACKLOG: Feature — Monster Coach Phase 5 "Eigene Coach-Views"

- **User Story:** `docs/project/stories/monster-coach.md`
- **Kontext:** Coach-Modus = eigene Views statt Modifikationen an bestehenden Views. Saubere Trennung: Coach AN zeigt pro Tab eine eigene View, Coach AUS bleibt wie bisher.
- **Gesamtkonzept:** `docs/context/feature-coach-views.md`

### Phase 5a: CoachBacklogView (Must) — ERLEDIGT
- Coach-Modus AN → Backlog-Tab zeigt CoachBacklogView statt BacklogView
- Monster-Header zeigt transparent den aktiven Schwerpunkt (Intention)
- Zwei Sektionen: "Dein Schwerpunkt" (passende Tasks) + "Weitere Tasks" (Rest)
- Farbige Discipline-Kreise in Task-Zeilen (= Phase 4b integriert)
- **Spec:** `docs/specs/features/coach-views-backlog.md`
- **Dateien:** CoachBacklogView.swift (NEU), MainTabView.swift, Discipline.swift, BacklogRow.swift
- **Tests:** 6 Unit Tests + 4 UI Tests gruen
- **Commit:** (wird nach Commit ergaenzt)

### Phase 5b: CoachMeinTagView (Must) — IN ARBEIT
- Coach-Modus AN → "Mein Tag"-Tab zeigt eigene View statt DailyReviewView
- MorningIntentionView + EveningReflectionCard in eigenem Layout (nicht in Review eingebettet)
- Tages-Fortschritt bezogen auf die Intention
- Coach-Elemente aus DailyReviewView entfernen
- **Bug: Intention-Chips Text abgeschnitten** — Alle 6 Labels in der MorningIntentionView sind durch `.lineLimit(1)` + `.font(.caption)` im 2-Spalten-Grid abgeschnitten und nicht lesbar (z.B. "Egal, Tag ueb...", "Stolz: nicht..."). Muss beim Rework der View gefixt werden.
- **Spec:** `docs/specs/features/coach-views-meintag.md`
- **Dateien:** CoachMeinTagView.swift (NEU), MainTabView.swift, DailyReviewView.swift
- **Scope:** ~120-150 LoC, 3-4 UI Tests

---

## BACKLOG: Feature — Monster Coach Phase 6 "macOS-Paritaet"

- **Kontext:** Alle Monster Coach Features (Phase 1-5) existieren nur als iOS-UI. Die Business-Logik (Models, Services) liegt korrekt in `Sources/` und ist geteilt — aber `FocusBloxMac/` hat KEINE Coach-Views. macOS-Nutzer koennen den Coach-Modus weder aktivieren noch nutzen.
- **Abhaengigkeit:** Phase 5b (CoachMeinTagView) sollte zuerst auf iOS fertig sein, bevor macOS-Paritaet gebaut wird.

### Phase 6a: Coach-Settings in macOS (Must) — ERLEDIGT
- Neuer 5. Tab "Monster Coach" in MacSettingsView mit identischen Settings wie iOS
- Master-Toggle, Morgen-Erinnerung, Tages-Erinnerungen (Max/Von/Bis), Abend-Erinnerung
- 4 UI Tests gruen (MacCoachSettingsUITests)
- **Dateien:** MacSettingsView.swift, MacCoachSettingsUITests.swift
- **Spec:** docs/specs/features/coach-settings-macos.md
- **Commit:** (wird nach Commit ergaenzt)

### Phase 6b: CoachBacklogView in macOS (Must) — ERLEDIGT
- macOS ContentView zeigt bei `coachModeEnabled` die MacCoachBacklogView statt normale Backlog-View
- Monster-Header mit Intention, Disziplin-Farbkreise auf Checkboxen, Schwerpunkt/Weitere-Sektionen
- Sidebar vereinfacht bei Coach-Modus (nur "Backlog" Label, keine Filter)
- 4 UI Tests gruen (MacCoachBacklogUITests)
- **Dateien:** MacCoachBacklogView.swift (NEU), ContentView.swift, MacBacklogRow.swift
- **Commit:** (wird nach Commit ergaenzt)

### Phase 6c: MorningIntentionView in macOS (Must) — OFFEN
- Morgen-Dialog mit Intentions-Auswahl und Monster-Grafik fuer macOS
- Die shared MorningIntentionView aus `Sources/Views/` koennte direkt eingebettet werden — pruefen ob sie macOS-kompatibel ist oder Anpassungen braucht
- **Referenz:** Sources/Views/MorningIntentionView.swift
- **Dateien:** FocusBloxMac/ (Integration in macOS-Layout)
- **Komplexitaet:** S-M

### Phase 6d: EveningReflectionCard in macOS (Must) — OFFEN
- Abend-Spiegel mit Erfuellungsbewertung, Monster-Icons und KI-Texten fuer macOS
- Wie 6c: pruefen ob die shared View direkt nutzbar ist
- **Referenz:** Sources/Views/EveningReflectionCard.swift
- **Dateien:** FocusBloxMac/ (Integration in macOS-Layout)
- **Komplexitaet:** S-M

### Phase 6e: CoachMeinTagView in macOS (Should) — OFFEN
- Erst relevant wenn Phase 5b (iOS CoachMeinTagView) fertig ist
- macOS-Aequivalent fuer den "Mein Tag"-Tab im Coach-Modus
- **Abhaengigkeit:** Phase 5b
- **Komplexitaet:** M

---

### Bug 99: CoachBacklogView — Next-Up-Swipe fehlt
- **Status:** ERLEDIGT
- **Plattform:** iOS
- **Fix:** `.swipeActions(edge: .leading)` mit "Next Up"/"Entfernen"-Button in `coachRow()` ergänzt
- **Dateien:** CoachBacklogView.swift
- **Tests:** 5 UI Tests grün

### Bug 100: Intention-Labels — Umlaute fehlen + Texte als Tagesziel umformulieren
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Fix:** Alle 6 IntentionOption-Labels mit Umlauten und als Tagesziel-Formulierung (Infinitiv statt Vergangenheit). Siri-Labels und Notification-Text ebenfalls gefixt.
- **Neue Labels:** "Tag überleben", "Nicht verzetteln", "Das große Ding anpacken", "In allen Bereichen leben", "Etwas Neues lernen", "Für andere da sein"
- **Dateien:** DailyIntention.swift, IntentionOptionEnum.swift, NotificationService.swift, MorningIntentionTests.swift
- **Tests:** 13 Unit Tests grün

---

### Bug: Abend-Review Text zu generisch — nicht auf Intention bezogen
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Symptom:** Der AI-generierte Abend-Text war generisch und ging nicht auf die gesetzte Tages-Intention ein. Tasks wurden blind abgeschnitten statt nach Relevanz sortiert.
- **Root Cause:** `buildPrompt()` in EveningReflectionTextService hatte (1) keine Intention-Relevanz-Sortierung vor `.prefix(5)`, (2) keine Schwerpunkt-Guidance für die AI, (3) bei Balance keine Kategorie-Aufschlüsselung.
- **Fix:** Tasks nach Intention-Relevanz sortieren (BHAG→importance=3, Fokus→Block-Tasks, Growth→Learning, Connection→Giving-Back), Schwerpunkt-Zeile im Prompt, Balance mit konkreter Kategorie-Aufschlüsselung.
- **Tests:** 19 Unit Tests grün (EveningReflectionTextServiceTests) — inkl. Sortierungsreihenfolge, Balance-Kategorien, Guidance pro Intention
- **Dateien:** EveningReflectionTextService.swift, EveningReflectionTextServiceTests.swift

### Bug 98: Mein Tag Woche zeigt nur Sprint-Tasks — ausserhalb Sprints erledigte fehlen
- **Status:** OFFEN
- **Plattform:** iOS + macOS
- **Symptom:** Die Wochenansicht in "Mein Tag" zeigt nur Tasks die innerhalb von Sprints erledigt wurden. Tasks die ausserhalb von Sprints erledigt wurden, fehlen komplett — sollen aber gleichberechtigt angezeigt werden.

---

## Weitere offene Features

| # | Item | Prio | Kompl. |
|---|------|------|--------|
| 9 | MAC-031 Focus Mode Integration | P3 | M |
| 10 | MAC-030 Shortcuts.app | P3 | L |
| 11 | Emotionales Aufladen (Report) | Mittel | L |
| 12 | MAC-026 Enhanced Quick Capture | P2 | L |
| 14 | MAC-032 NC Widget | P3 | XL |
| 17 | ITB-C: OrganizeMyDay Intent | Mittel | XL |
| 20 | ITB-F: CaptureContextIntent (Siri On-Screen) | WARTEND | M |

**Komplexitaet:** XS = halbe Stunde | S = 1 Session | M = 2-3 Sessions | L = halber Tag | XL = ganzer Tag+

**WARTEND (Apple-Abhaengigkeit):** #20 ITB-F — wartet auf Siri On-Screen Awareness (iOS 26.5/27)

---

## Bundles (nur offene Items)

### Bundle D: Erfolge feiern
- Emotionales Aufladen im Report

### Bundle E: macOS Native Experience (P2/P3)
- Monster Coach Phase 6: macOS-Paritaet (6a-6e)
- MAC-026 Enhanced Quick Capture
- MAC-030 Shortcuts.app
- MAC-031 Focus Mode Integration
- MAC-032 NC Widget

### Bundle G: Intelligent Task Blox (Rest)
- ITB-F (CaptureContextIntent) — WARTEND auf Apple APIs
- ITB-C (OrganizeMyDay) — Komplexer Intent (XL)

---

## Backlog (Technical Debt)

### Verbleibende Tech-Debts (dokumentiert in `docs/context/tech-debt-analysis.md`)
- **TD-01:** God-Views (BlockPlanningView 1400 LoC, BacklogView 1181 LoC) — Aufwand: L
- **TD-02:** iOS/macOS View-Duplikation — Paket 1-3 ERLEDIGT (Badges, Sheets, Header: ~412 LoC eliminiert). Verbleibend: ~7500 LoC, Aufwand: XL
- **TD-03:** 3 Services ohne Unit Tests (NotificationService, FocusBlockActionService, GapFinder) — Aufwand: M

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
