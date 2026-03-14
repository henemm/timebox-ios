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

### Phase 4b: Farbiger Discipline-Kreis in Task-Zeilen (Should) — OFFEN
- Abhak-Kreis am Anfang jeder Task-Zeile kraeftiger und in Discipline-Farbe
- Discipline-Klassifizierung fuer offene Tasks (rescheduleCount >= 2 → Konsequenz, importance == 3 → Mut, sonst Ausdauer; Fokus erst nach Erledigung)
- **Dateien:** BacklogRow.swift, Discipline.swift

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
