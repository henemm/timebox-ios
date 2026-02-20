# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!

---

## Status-Legende

| Status | Bedeutung |
|--------|-----------|
| **OFFEN** | Noch nicht begonnen |
| **SPEC READY** | Spec geschrieben & approved, Implementation ausstehend |
| **IN ARBEIT** | Aktive Bearbeitung |
| **ERLEDIGT** | Fertig (nur nach Phase 8 / vollstaendiger Validierung) |
| **BLOCKIERT** | Kann nicht fortgesetzt werden |

---

## Aufwand-Uebersicht (nur offene Items)

| # | Item | Prio | Kompl. | Tokens | Dateien | LoC |
|---|------|------|--------|--------|---------|-----|
| 0 | Settings UX: Build-Info + Vorwarnungs-Labels | NIEDRIG | XS | ~10-15k | 3-4 | ~30 |
| 1 | Einheitliche Symbole Tab-Bar/Sidebar | NIEDRIG | XS | ~10-15k | 2-3 | ~20 |
| 2 | NextUp Wischgesten (Edit+Delete) | MITTEL | XS | ~15-20k | 1 | ~20 |
| 3 | NextUp Long Press Vorschau | NIEDRIG | XS | ~15-20k | 1-2 | ~30 |
| 4 | Generische Suche (iOS+macOS) | MITTEL | S | ~15-20k | 2-3 | ~25 |
| 5 | MAC-022 Spotlight Integration | P2 | S | ~15-25k | 1-2 | ~30 |
| 6 | ~~Recurring Tasks Phase 1B/2 (inkl. Sichtbarkeit + Edit/Delete Dialog)~~ | ERLEDIGT | M-L | ~60-100k | 5-6 | ~200 |
| 7 | Kalender-App Deep Link (iOS+macOS) | MITTEL | M | ~40-50k | 3-4 | ~100 |
| 8 | ~~Push Notifications bei Frist~~ | ERLEDIGT | M | ~60-80k | 9 | ~180 |
| 9 | MAC-031 Focus Mode Integration | P3 | M | ~50-70k | 2-3 | ~100 |
| 10 | MAC-030 Shortcuts.app | P3 | L | ~60-80k | 2-3 | ~150 |
| 11 | Emotionales Aufladen (Report) | MITTEL | L | ~80-100k | 3-4 | ~200 |
| 12 | MAC-026 Enhanced Quick Capture | P2 | L | ~80-120k | 4 | ~200 |
| 13 | MAC-020 Drag & Drop Planung | P2 | XL | ~100-150k | 3-4 | ~250 |
| 14 | MAC-032 NC Widget | P3 | XL | ~80-120k | neues Target | ~200 |
| 15 | ITB-A: FocusBlockEntity (AppEntity) | MITTEL | S | ~30-40k | 2 | ~60 |
| 16 | ~~ITB-B: Smart Priority (AI-Enrichment + Hybrid-Scoring)~~ | ERLEDIGT | L | ~80-120k | 12 | ~250 |
| 17 | ITB-C: OrganizeMyDay Intent | MITTEL | XL | ~100-150k | 4-5 | ~250 |
| 18 | ITB-D: Enhanced Liquid Glass (aktive Blocks) | NIEDRIG | S | ~20-30k | 2 | ~40 |
| 19 | ITB-E: Share Extension / Transferable | MITTEL | L | ~80-120k | 3-4 + Target | ~200 |
| 20 | ITB-F: CaptureContextIntent (Siri On-Screen) | WARTEND | M | ~40-60k | 3-4 | ~80 |
| 21 | ITB-G: Proaktive System-Vorschlaege | RESEARCH | XL | unbekannt | unbekannt | unbekannt |

**Komplexitaet:** XS = halbe Stunde | S = 1 Session | M = 2-3 Sessions | L = halber Tag | XL = ganzer Tag+

**Guenstigste Quick Wins:** #1 Symbole (~10k), #2 Wischgesten (~15k), #3 Long Press (~15k)
**Teuerste Items:** #17 OrganizeMyDay (~150k), #13 Drag & Drop (~150k), #14 NC Widget (~120k)
**WARTEND (Apple-Abhaengigkeit):** #20 ITB-F — Developer-APIs verfuegbar, wartet auf Siri On-Screen Awareness (iOS 26.5/27)
**RESEARCH Items:** #21 ITB-G - API-Verifizierung noetig vor Planung

> **Dies ist das EINZIGE Backlog.** macOS-Features (MAC-xxx) stehen hier mit Verweis auf ihre Specs in `docs/specs/macos/`. Kein zweites Backlog.

---

## Bundles (thematische Gruppierung)

### Bundle A: Quick Wins (XS, eine Session)
- Settings UX: Build-Info + Vorwarnungs-Labels
- Einheitliche Symbole Tab-Bar/Sidebar
- NextUp Wischgesten (Edit+Delete)
- NextUp Long Press Vorschau

### Bundle B: Backlog & Suche
- Generische Suche (iOS+macOS)
- MAC-022 Spotlight Integration

### Bundle C: Erinnerungen & Verknuepfungen
- Push Notifications bei Frist
- Kalender-App Deep Link

### Bundle D: Erfolge feiern
- Emotionales Aufladen im Report

### Bundle E: macOS Native Experience (P2/P3)
- MAC-020 Drag & Drop Planung
- MAC-026 Enhanced Quick Capture
- MAC-030 Shortcuts.app
- MAC-031 Focus Mode Integration
- MAC-032 NC Widget

### Bundle F: Recurring Tasks vervollstaendigen
- ~~Phase 1B/2 (macOS Badge, Siri, Delete-Dialog, Filter)~~ ERLEDIGT
- ~~Dedup-Logik (gleichzeitiges Completion auf 2 Geraeten)~~ ERLEDIGT
- ~~macOS-Divergenz: Zukunfts-Filter + Wiederkehrend-Sidebar~~ ERLEDIGT
- ~~Quick-Edit Recurrence-Params Fix~~ ERLEDIGT
- Recurrence-Editing Phase 2: Intervalle + Eigene (z.B. "Jeden 3. Tag")

### Bundle G: Intelligent Task Blox (Apple Intelligence + System-Integration)
**Empfohlene Reihenfolge:**
1. ITB-D (Liquid Glass) - Quick Win, unabhaengig
2. ITB-A (FocusBlockEntity) - Grundlage fuer Intents
3. ITB-E (Share Extension) - unabhaengig von AI
4. ~~ITB-B (Smart Priority)~~ ERLEDIGT - AI-Enrichment + deterministischer Score
5. ITB-C (OrganizeMyDay) - braucht A+B
6. ITB-F (Context Capture) - WARTEND: Developer-APIs da, Siri On-Screen Awareness fehlt (iOS 26.5/27)
7. ITB-G (Proaktive Vorschlaege) - RESEARCH: API-Verifizierung zuerst

**Prinzip:** AI ergaenzt manuelles Scoring - schlaegt vor, User bestaetigt/ueberschreibt. Features unsichtbar auf Nicht-AI-Geraeten (Graceful Degradation).

---

## 🔴 OFFEN

---

### Refactoring: Reminders Import-Only (statt bidirektionalem Sync)
**Status:** ERLEDIGT
**Prioritaet:** HOCH
**Komplexitaet:** M (~40-60k Tokens)

- **Problem:** Bidirektionaler Reminders-Sync hat 7 Bugs verursacht (18, 32, 34, 48, 57, 59, 60). Export-Code war toter Code. Auf iOS lief Import bei CloudKit-aktiven Geraeten nie.
- **Loesung:** Komplett-Umbau auf Import-Only:
  - Neuer `RemindersImportService` (Import-Only, kein Export, kein Auto-Sync)
  - Import-Button in iOS Backlog + macOS Toolbar (statt automatischem Sync)
  - Nach erfolgreichem Import optional Reminders in Apple Erinnerungen abhaken
  - Migration bestehender "reminders"-Tasks zu "local" beim App-Start
  - PlanningView markReminderComplete entfernt (kein Rueckkanal)
  - Settings-Texte angepasst ("Importieren" statt "Synchronisieren")
- **Commit 1:** `d5812b9` Funktionale Aenderung (RemindersImportService, UI, Migration)
- **Commit 2:** Alter RemindersSyncService + 5 Bug-Tests geloescht, 12 neue RemindersImportServiceTests, MockEventKitRepository erweitert
- **Dateien:** `RemindersImportService.swift` (neu), `BacklogView.swift`, `ContentView.swift` (macOS), `SettingsView.swift`, `MacSettingsView.swift`, `FocusBloxApp.swift`, `PlanningView.swift`
- **Tests:** 14 Unit Tests (Import, Duplikate, Filter, Priority, Mark-Complete, Migration, Failure-Reporting) alle GREEN
- **Nachfix 1:** `ReminderData.id` nutzte `calendarItemExternalIdentifier` statt `calendarItemIdentifier` — `markReminderComplete()` konnte Erinnerungen nicht finden (silent fail). Gefixt: `id = calendarItemIdentifier`.
- **Nachfix 2:** `ImportResult` meldet jetzt `markedComplete` + `markCompleteFailures`. Feedback-Text zeigt alle Ergebnisse (importiert, bereits vorhanden, Abhaken fehlgeschlagen).
- **Nachfix 3:** macOS Import-Button war unsichtbar + kein Feedback. Root Cause: `UserDefaults.standard.bool()` statt `@AppStorage` (Default `false` statt `true`). Fix: `@AppStorage`, `os.Logger` fuer Debugging, `.alert()` statt Overlay (macOS Best Practice). `markReminderComplete()` wirft jetzt statt silent return.
- **Nachfix 4:** iOS Import-Feedback war zu schnell (3s Overlay, kaum sichtbar). Fix: `.alert()` mit OK-Button statt Overlay + Auto-Dismiss — konsistent mit macOS.
- **Workflow-Verbesserung:** `/10-bug` um "Ich liege falsch"-Grundannahme erweitert: Triage, Existenz-Check, Hypothesen-Beweis durch Logging, Post-Fix-Verifikation.

---

### Bug 59: Erledigte Apple Reminders erscheinen im Backlog
**Status:** ERLEDIGT
**Prioritaet:** HOCH
**Komplexitaet:** XS (~10-15k Tokens)
**Commit:** `3392695`

- **Location:** `Sources/Services/RemindersSyncService.swift`
- **Problem:** Bug 57 Fix aenderte Reminder-ID-Format, was Duplikate und Orphans erzeugte. Erledigte Reminders blieben als aktive lokale Tasks im Backlog.
- **Fix:** Drei Massnahmen in `RemindersSyncService.importFromReminders()`:
  1. **Orphan-Recovery:** Title-basierter Match findet alte Tasks (sourceSystem="local", externalID=nil) und stellt sie wieder her
  2. **Attribut-Transfer:** Bei vorhandenem Duplikat werden Benutzer-Attribute (importance, urgency, tags, duration, AI-Score etc.) vom Orphan uebertragen
  3. **Completed-Marking:** `handleDeletedReminders()` setzt jetzt `isCompleted=true` + `completedAt` statt nur Soft-Delete
- **Tests:** 4 Unit Tests (Bug59CompletedRemindersTests), 20 verwandte Sync-Tests alle GREEN, keine Regressionen.
- **HINWEIS:** Bug 60 hat Teile dieses Fixes superseded (sourceSystem bleibt jetzt "reminders" statt "local").

---

### Bug 60: Erweiterte Attribute verschwinden bei Reminders-Sync (7. Wiederholung)
**Status:** ERLEDIGT
**Prioritaet:** HOCH
**Komplexitaet:** M (~40-50k Tokens)
**Commit:** `341ea86`

- **Location:** `Sources/Services/RemindersSyncService.swift`
- **Problem:** 7. Wiederholung des Attributverlusts (Bug 18, 32, 34, 48, 57, 59, 60). Erweiterte Attribute (importance, urgency, estimatedDuration, taskType, tags) verschwinden nach Reminders-Sync.
- **Root Causes (5 strukturelle Probleme):**
  1. `externalID` wird auf nil gesetzt — macht Recovery permanent unmoeglich
  2. `isCompleted=true` blockiert Orphan-Recovery (Predicate filtert sie aus)
  3. Kein Title-Match fuer `sourceSystem="reminders"` Tasks
  4. `calendarItemExternalIdentifier` aendert sich bei iCloud-Resync
  5. `handleDeletedReminders` nutzt gefilterte statt aller IDs
- **Fix:** 3 Aenderungen in RemindersSyncService:
  1. Neuer 3-Stufen-Match: externalID → Titel (reminders) → Titel (orphan) → Neuanlage
  2. `handleDeletedReminders` nutzt ALLE Reminder-IDs (nicht nur sichtbare Listen)
  3. externalID und sourceSystem werden NIE geloescht — nur `isCompleted=true`
- **Analyse:** `docs/artifacts/bug-60-attribute-loss/analysis.md` (5 Agenten parallel, 5 Hypothesen)
- **Tests:** 6 Unit Tests (Bug60AttributeRecoveryTests) + 18 verwandte Sync-Tests alle GREEN.
- **Cleanup:** Dead-Code Safe-Setter (safeSetImportance etc.) und 6 zugehoerige Tests entfernt.

---

### Bug: Recurring Tasks nach Import sichtbar trotz Enrichment
**Status:** ERLEDIGT
**Prioritaet:** HOCH
**Komplexitaet:** S (~25k Tokens)

- **Problem:** Wiederkehrende Apple Reminders (Fahrradkette, Zehnagel, Klavier spielen, 1 Blink lesen) wurden importiert, aber `recurrencePattern` blieb "none" in der DB. Dadurch griff `isVisibleInBacklog`-Filter nicht — Tasks erschienen in "Alle Tasks" statt nur bei Faelligkeit.
- **Root Cause:** `RemindersImportService.importAll()` fetchte ALLE Tasks (inkl. 97 erledigte) fuer Duplikat-Erkennung. Erledigte recurring Tasks hatten korrektes `recurrencePattern` (vom RecurrenceService). `existingByTitle[title].first` fand die ERLEDIGTE zuerst → Enrichment-Bedingung `== "none"` war false → aktive Tasks wurden uebersprungen.
- **Diagnostik-Beweis:** `hasChanges=false, changed=0` VOR save() → SwiftData hat nie eine Aenderung registriert. `VERIFY: 1 with recurrencePattern != 'none'` statt 5.
- **Fix:** FetchDescriptor mit `#Predicate { !$0.isCompleted }` — nur incomplete Tasks fuer Duplikat-Detection + Enrichment.
- **Nach Fix:** `hasChanges=true, changed=3`, `VERIFY: 5 with recurrencePattern != 'none'`. "Wiederkehrend" Sidebar zeigt 3 (vorher 1).
- **Dateien:** `RemindersImportService.swift` (1 Zeile geaendert + Kommentar)
- **Tests:** 26/26 RemindersImportServiceTests GREEN
- **Learning:** Bei SwiftData-Fetches fuer Enrichment/Migration IMMER pruefen ob completed Tasks den Match verfaelschen.

---

### Bug: "Wiederkehrend"-Filter zeigt nur sichtbare Tasks statt ALLER recurring Tasks
**Status:** ERLEDIGT
**Prioritaet:** HOCH
**Komplexitaet:** S (~15k Tokens)

- **Problem:** Der "Wiederkehrend"-Filter in der Sidebar (iOS + macOS) zeigte nur recurring Tasks die `isVisibleInBacklog == true` waren. Future-dated Tasks (z.B. Fahrradkette am 15.03, Zehnagel am 01.03) wurden versteckt — obwohl User sie im Wiederkehrend-Filter sehen muessen um die Serie zu verwalten.
- **Root Cause:** macOS `recurringCount` + `filteredTasks` nutzten `visibleTasks` (filtert via `isVisibleInBacklog`). iOS `recurringTasks` nutzte `planItems` die bereits durch `LocalTaskSource.fetchIncompleteTasks()` → `isVisibleInBacklog` gefiltert waren.
- **Fix:**
  - macOS: `recurringCount`, `filteredTasks .recurring`, `regularFilteredTasks .recurring` nutzen jetzt `tasks.filter { !$0.isCompleted && ... }` statt `visibleTasks.filter`
  - iOS: Neue Methode `LocalTaskSource.fetchIncompleteRecurringTasks()` (ohne `isVisibleInBacklog`), `SyncEngine.syncRecurringTasks()`, `BacklogView.allRecurringItems` State Property
- **Dateien:** `LocalTaskSource.swift`, `SyncEngine.swift`, `BacklogView.swift`, `ContentView.swift`
- **Tests:** 2 neue Unit Tests (fetchIncompleteRecurringTasks) GREEN
- **Beide Plattformen:** iOS + macOS Build SUCCEEDED

---

### Feature: Settings UX - Build-Info dynamisch + Vorwarnungs-Labels klarer (iOS + macOS)
**Status:** OFFEN
**Prioritaet:** NIEDRIG
**Komplexitaet:** XS (~10-15k Tokens)

**2 Probleme in den Settings (macOS + iOS):**

1. **Version/Build statisch:** macOS Settings zeigen "Version 1.0 / Build 1" -- nutzlose statische Werte. Soll dynamisch Version + Git-Commit-Hash anzeigen, damit klar ist welcher Build laeuft.
   - `BuildInfo.swift` (Shared) als Helper
   - Build Phase Script injiziert Git-Hash in Info.plist
   - Anzeige: "Version 1.0 (abc1234)" auf **beiden Plattformen**

2. **Vorwarnungs-Labels unklar:** Picker zeigt "Knapp / Standard / Frueh" -- nicht intuitiv verstaendlich.
   - "Knapp" → **"Kurz vorher"** (10% vor Block-Ende)
   - "Standard" bleibt
   - "Frueh" → **"Weit vorher"** (30% vor Block-Ende)
   - Aenderung nur in `WarningTiming.swift` (Shared Enum) -- wirkt automatisch auf iOS + macOS

**Betroffene Dateien:** `WarningTiming.swift`, `BuildInfo.swift` (neu), `MacSettingsView.swift`, `SettingsView.swift`, beide Info.plist
**Scope:** ~30 LoC, 3-4 Dateien (+1 Build Script)

---

### Feature: Einheitliche Symbole Tab-Bar/Sidebar (iOS + macOS)
**Status:** OFFEN
**Prioritaet:** NIEDRIG
**Komplexitaet:** XS (~10-15k Tokens)

**Problem:** iOS Tab-Bar und macOS Sidebar nutzen unterschiedliche SF Symbols fuer die gleichen Bereiche.
**Gewuenschtes Verhalten:** Beide Plattformen sollen die gleichen SF Symbols verwenden - neue einheitliche Auswahl.
**Scope:** ~20 LoC, 2-3 Dateien (ContentView iOS + macOS)

---

### Feature: Push Notifications bei ablaufender Frist (iOS + macOS)
**Status:** ERLEDIGT
**Prioritaet:** HOCH
**Komplexitaet:** M (~60-80k Tokens)

**Problem:** Tasks mit Due Date haben keine Erinnerung. Der User vergisst, sie in einen Sprint zu packen.
**Loesung implementiert:**
- **Morgen-Erinnerung** (default AN): Am Faelligkeitstag um konfigurierbare Uhrzeit (default 09:00)
- **Vorab-Erinnerung** (default AUS): 15min/30min/1h/2h/1Tag vor Frist
- Beide unabhaengig ein/ausschaltbar in Settings (iOS + macOS)
- Hybrid-Scheduling: Einzeln bei Create/Edit/Delete + Batch bei App-Foreground
- 7/7 Unit Tests GREEN, 2/2 UI Tests GREEN
- **Nachfix (2026-02-18):** NotificationService.swift fehlte im macOS-Target (Build-Fehler)
**Dateien:** NotificationService, AppSettings, SettingsView, MacSettingsView, FocusBloxApp, FocusBloxMacApp, CreateTaskView, TaskFormSheet, BacklogView

---

### Feature: iOS NextUp Long Press Vorschau
**Status:** OFFEN
**Prioritaet:** NIEDRIG
**Komplexitaet:** XS (~15-20k Tokens)

**Problem:** In der NextUp-Liste kann man keine Task-Details sehen ohne den Task zu oeffnen.
**Gewuenschtes Verhalten:** Long Press auf einen NextUp-Task zeigt eine **reine Vorschau** mit allen Details (Kategorie, Dauer, Beschreibung, Tags, Frist). Keine Aktionen im Preview.
**Scope:** ~30 LoC, 1-2 Dateien

---

### Feature: iOS NextUp Wischgesten (Edit + Delete)
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** XS (~15-20k Tokens)

**Problem:** NextUp-Tasks koennen nicht per Swipe bearbeitet oder geloescht werden - nur im Backlog.
**Gewuenschtes Verhalten:** Gleiche Wischgesten wie im Backlog:
- **Trailing (rechts-wisch):** Loeschen (rot, destructive) + Bearbeiten (blau)
- **KEIN Leading-Swipe** (kein "Next Up" Toggle noetig, da bereits in NextUp)
**Scope:** ~20 LoC, 1 Datei

---

### Feature: Kalender-App Deep Link zu FocusBlox (iOS + macOS)
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** M (~40-50k Tokens)

**Problem:** FocusBlocks erscheinen als Kalender-Events, aber es gibt keinen direkten Weg zurueck zur App.
**Gewuenschtes Verhalten:**
- FocusBlock-Events im Kalender enthalten einen **Deep Link** (URL in den Notizen)
- Tippen auf den Link oeffnet FocusBlox und zeigt:
  - **Block-Detail** wenn der Block inaktiv ist
  - **FokusMode** wenn der Block gerade aktiv ist
- URL-Schema: `focusblox://block/{eventID}`
- **Beide Plattformen** (iOS + macOS) - identisches URL-Schema
**Hinweis:** Link ist ein Text-Link in den Event-Notizen, kein nativer Button.
**Scope:** ~80-100 LoC, 3-4 Dateien (URL-Schema, EventKitRepository, App-Routing)

---

### Feature: Emotionales Aufladen - Erfolge visuell feiern im Report
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** L (~80-100k Tokens)

**Problem:** Als Knowledge Worker sieht man sein "Werk" nicht wie ein Handwerker. Der Tagesreport listet Zahlen, feiert aber nicht die Leistung.
**Gewuenschtes Verhalten:**
- **Fokus auf das Erledigte** - nicht auf das was noch kommt
- **Visuelle Highlights** im Tagesreport:
  - Animierte Ringe die sich schliessen
  - Goldene Akzente/Sterne bei Bestleistung (persoenlicher Rekord)
  - Konfetti-Animation bei 100% Completion
  - Hervorhebung der Anzahl wichtiger erledigter Aufgaben
- **Wochen-Rueckblick** mit Vergleich zur Vorwoche
- Abschaltbar in Settings
**Kerngedanke:** "Schau was du heute alles geschafft hast!" statt "Das liegt noch vor dir."
**Scope:** ~150-200 LoC, 3-4 Dateien (DailyReviewView, MacReviewView, Animationen)

---

### Feature: Batch-Enrichment fuer bestehende Tasks
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** XS (~10-15k Tokens)
**Abhaengigkeit:** ITB-B (Smart Priority)

**Problem:** Bestehende Tasks (vor Smart Priority erstellt) haben leere Felder (importance, urgency, taskType). Dadurch Score = 0 im Eisenhower-Anteil, Sortierung nutzlos.
**Gewuenschtes Verhalten:**
- Beim App-Start (oder wenn Setting aktiviert wird) alle Tasks mit leeren Attributen finden
- `SmartTaskEnrichmentService.enrichTask()` auf jeden davon ausfuehren
- Nur einmal pro Task (Flag oder Check auf bereits gefuellte Felder reicht)
- Nur wenn Apple Intelligence verfuegbar UND Setting aktiviert
**Scope:** ~20-30 LoC, 1-2 Dateien (FocusBloxApp/FocusBloxMacApp + ggf. SmartTaskEnrichmentService)

---

### Feature: Generische Suche (iOS + macOS)
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** S (~15-20k Tokens)

**Problem:** Kein Suchfeld fuer Tasks. Bei vielen Tasks muss man manuell scrollen.
**Gewuenschtes Verhalten:** Suchfeld im Backlog (iOS + macOS) filtert Tasks nach Titel, Tags, Kategorie.
**Scope:** ~25 LoC, 2-3 Dateien

---

### Feature: Wiederkehrende Tasks Phase 1B/2
**Status:** ERLEDIGT (2026-02-17)
**Commits:** `2c4f92b` (Ticket 1), `cd46645` (Ticket 2), `9fb5e21` (Ticket 3)

Umgesetzt: recurrenceGroupID + Sichtbarkeitsfilter, Delete-Dialog "Nur diese/Ganze Serie",
Edit-Dialog "Nur diese/Ganze Serie", macOS Integration (Badge, Completion, Dialoge),
Backlog-Filter "Wiederkehrend". iOS + macOS.

**Verbleibende Folge-Tickets (separater Scope):**
- Dedup-Logik: Gleichzeitiges Completion auf 2 Geraeten kann doppelte Instanzen erzeugen
- ~~Quick-Edit Recurrence-Params: Quick-Edit-Funktionen uebergeben recurrence-Params nicht (Bug 48 Restwirkung)~~ ERLEDIGT (recurrence params in updateRecurringSeries + call sites gefixt)

---

### MAC-020: Drag & Drop Planung (macOS)
**Status:** OFFEN
**Prioritaet:** P2
**Komplexitaet:** XL (~100-150k Tokens)
**Spec:** `docs/specs/macos/BACKLOG.md`
**Scope:** ~250 LoC, 3-4 Dateien

---

### MAC-022: Spotlight Integration (macOS)
**Status:** OFFEN
**Prioritaet:** P2
**Komplexitaet:** S (~15-25k Tokens)
**Spec:** `docs/specs/macos/BACKLOG.md`
**Scope:** ~30 LoC, 1-2 Dateien

---

### MAC-026: Enhanced Quick Capture (macOS)
**Status:** OFFEN
**Prioritaet:** P2
**Komplexitaet:** L (~80-120k Tokens)
**Spec:** `docs/specs/macos/MAC-026-quick-capture-enhanced.md`
**Scope:** ~200 LoC, 4 Dateien

---

### MAC-030: Shortcuts.app Integration (macOS)
**Status:** OFFEN
**Prioritaet:** P3
**Komplexitaet:** L (~60-80k Tokens)
**Spec:** `docs/specs/macos/BACKLOG.md`
**Scope:** ~150 LoC, 2-3 Dateien

---

### MAC-031: Focus Mode Integration (macOS)
**Status:** OFFEN
**Prioritaet:** P3
**Komplexitaet:** M (~50-70k Tokens)
**Spec:** `docs/specs/macos/BACKLOG.md`
**Scope:** ~100 LoC, 2-3 Dateien

---

### MAC-032: Notification Center Widget (macOS)
**Status:** OFFEN
**Prioritaet:** P3
**Komplexitaet:** XL (~80-120k Tokens)
**Spec:** `docs/specs/macos/BACKLOG.md`
**Scope:** ~200 LoC, neues Target

---

### ITB-A: FocusBlockEntity (AppEntity fuer Blocks)
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** S (~30-40k Tokens)
**Abhaengigkeiten:** Keine (baut auf bestehendem TaskEntity-Pattern auf)

**Problem:** FocusBlocks sind nicht als AppEntity exponiert - kein Zugriff fuer Shortcuts, Siri oder Spotlight.
**Gewuenschtes Verhalten:**
- FocusBlock als `AppEntity` mit `EntityQuery`
- Spotlight-Indexierung fuer Blocks
- Grundlage fuer alle weiteren Intent-basierten Features
**Bestehendes Pattern:** TaskEntity + 5 App Intents in `Sources/Intents/`
**Scope:** ~60 LoC, 2 Dateien (neue Entity + FocusBloxShortcuts Erweiterung)

---

### ITB-B: Smart Priority — AI-Enrichment + Hybrid-Scoring
**Status:** ERLEDIGT (2026-02-19, Refactoring von AI Task Scoring)
**Prioritaet:** MITTEL
**Komplexitaet:** L (~80-120k Tokens)
**Abhaengigkeiten:** Keine (Graceful Degradation implementiert)

**Implementiert (2-Schicht-System):**
- **Schicht 1: SmartTaskEnrichmentService** — Ersetzt opakes AI-Scoring durch strukturiertes Enrichment
  - `@Generable TaskEnrichment` (suggestedImportance, suggestedUrgent, suggestedTaskType, suggestedEnergyLevel)
  - Fuellt nur nil/leere Felder — User-Werte werden NIEMALS ueberschrieben
  - Nutzt `contentTagging`-Adapter statt generischem LLM-Prompt
- **Schicht 2: TaskPriorityScoringService** — Deterministischer 0-100 Score (on-the-fly)
  - Formel: eisenhower(50) + deadline(25) + neglect(15) + completeness(5) + nextUp(5)
  - Gleiche Daten = gleiches Ergebnis, aendert sich wenn Deadline naeher rueckt
- **UI:** ViewMode "Prioritaet" (statt "KI-Empfehlung"), chart.bar.fill Icon, IMMER sichtbar (nicht AI-gated)
  - Tier-Sektionen: Sofort erledigen (rot, 60-100), Bald einplanen (orange, 35-59), Bei Gelegenheit (gelb, 10-34), Irgendwann (grau, 0-9)
  - Farbiges Prioritaets-Badge mit Score-Zahl in BacklogRow (statt lila AI-Badge)
- **Settings:** "KI Task-Enrichment" Toggle (nur sichtbar mit Apple Intelligence)
- **Cross-Platform:** iOS + macOS gleichwertig implementiert
**Dateien:** `SmartTaskEnrichmentService.swift` (neu), `TaskPriorityScoringService.swift` (neu), `PlanItem.swift`, `BacklogView.swift`, `BacklogRow.swift`, `CreateTaskView.swift`, `SettingsView.swift`, `MacSettingsView.swift`, `SidebarView.swift`, `MacBacklogRow.swift`, `ContentView.swift` (macOS)
**Tests:** 10 Unit Tests + 3 UI Tests GREEN

---

### ITB-C: OrganizeMyDay Intent
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** XL (~100-150k Tokens)
**Abhaengigkeiten:** ITB-A + ITB-B (braucht FocusBlockEntity + AI Scoring)

**Problem:** Tagesplanung erfordert manuelles Durchgehen aller Tasks und Erstellen von Blocks.
**Gewuenschtes Verhalten:**
- Siri Intent: "Organisiere meinen Tag"
- Ruft faellige Tasks ab, sortiert via AI-Scoring
- Schlaegt optimale FocusBlock-Reihenfolge vor
- Beruecksichtigt bestehende Kalender-Events
- User bestaetigt/passt an vor Erstellung
**Scope:** ~250 LoC, 4-5 Dateien (Intent, Query, Block-Erstellung, Kalender-Integration)

---

### ITB-D: Enhanced Liquid Glass fuer aktive Blocks
**Status:** OFFEN
**Prioritaet:** NIEDRIG
**Komplexitaet:** S (~20-30k Tokens)
**Abhaengigkeiten:** Keine

**Problem:** Aktive FocusBlock-Sessions sehen statisch aus - kein visueller Unterschied zwischen Idle und Flow.
**Gewuenschtes Verhalten:**
- Erweiterte Liquid Glass Effekte waehrend aktiver Sessions
- Subtile Animationen die den Focus-Zustand widerspiegeln
- Konsistent auf iOS (FocusLiveView) und macOS (MacFocusView)
**Bestehendes Pattern:** `.glassCard()`, `.ultraThinMaterial` im DesignSystem
**Scope:** ~40 LoC, 2 Dateien (DesignSystem Erweiterung + FocusView Anpassungen)

---

### ITB-E: Share Extension / Transferable-Erweiterung
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** L (~80-120k Tokens)
**Abhaengigkeiten:** Keine

**Problem:** Tasks koennen nur direkt in der App erstellt werden. Inhalte aus Safari, Mail etc. muessen manuell abgetippt werden.
**Gewuenschtes Verhalten:**
- Neues Share Extension Target
- Daten aus Safari, Mail und anderen Apps empfangen
- Automatische Task-Erstellung aus geteilten Inhalten (URL, Text, Titel)
**Bestehendes Pattern:** Transferable (`PlanItemTransfer`, `CalendarEventTransfer`, `MacTaskTransfer`)
**Scope:** ~200 LoC, 3-4 Dateien + neues Target

---

### ITB-F: CaptureContextIntent — Siri On-Screen Awareness
**Status:** WARTEND (Developer-APIs verfuegbar, Siri-Seite noch nicht ausgeliefert)
**Prioritaet:** MITTEL
**Komplexitaet:** M (~40-60k Tokens)
**Abhaengigkeiten:** ITB-A (FocusBlockEntity), Siri On-Screen Awareness (iOS 26.5 oder 27)

**Research-Ergebnis (2026-02-17):**

API-Verifizierung abgeschlossen. Ergebnisse:
- `IntentParameter(requestValue: .context)` — **gibt es NICHT** in dieser Form
- `ForegroundContinuableIntent` — existiert (seit iOS 17), bringt App nur in Vordergrund, kein Screen-Zugriff
- `NSUserActivity` + `appEntityIdentifier` + SwiftUI `.userActivity(_:element:_:)` — **verfuegbar seit iOS 18.2**
- `AssistantSchema` erweitert in iOS 26, aber kein Produktivitaets/Task-Domain

**Realisierter Ansatz (statt eigenem Screen-Reader):**
Siri liest den Screen-Inhalt anderer Apps (wenn diese ihn exponieren). User sagt "Erstelle Task daraus in FocusBlox". Siri ruft FocusBlox-Intent mit Kontext auf.

**FocusBlox-seitige Vorbereitung (jetzt umsetzbar):**
1. `TaskEntity` via `NSUserActivity` + `appEntityIdentifier` exponieren
2. `CreateTaskFromContextIntent` mit optionalem Kontext-Parameter
3. FocusBlox-Views mit `.userActivity()` Modifier ausstatten

**Wartet auf Apple:**
- Siri On-Screen Awareness war fuer iOS 26.4 geplant
- Laut Bloomberg (Feb 2026) verschoben auf iOS 26.5 (Mai) oder iOS 27 (September)
- Apple bestaetigte am 12.02.2026: "still coming in 2026"

**Context-Dokument:** `docs/context/ITB-F-CaptureContextIntent.md`
**Scope:** ~80 LoC, 3-4 Dateien (TaskEntity-Erweiterung, neuer Intent, NSUserActivity-Integration)

---

### ITB-G: Proaktive System-Vorschlaege - RESEARCH
**Status:** OFFEN (RESEARCH - API-Verifizierung noetig)
**Prioritaet:** RESEARCH
**Komplexitaet:** XL (unbekannt)
**Abhaengigkeiten:** ITB-B + ITB-F + API-Verifizierung

**Zu verifizieren BEVOR Planung beginnt:**
- `AssistantSchema.Actions.Create` - existiert diese API?
- Proaktive Intent-Vorschlaege - wie funktioniert das System?
**Wenn API existiert:**
- System erkennt "Task-aehnliche" Inhalte in anderen Apps
- Schlaegt FocusBlox-Task-Erstellung proaktiv vor
- Integration mit Siri Suggestions
**Status:** Keine Implementierung ohne API-Verifizierung. Zuerst Research.

---

---

## ✅ Kuerzlich erledigt

### Fix: Watch App Icon fehlte in Companion App
**Status:** ERLEDIGT (2026-02-18)
**Dateien:** `FocusBloxWatch Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (neu), `Contents.json`
**Loesung:** iOS App-Icon (1024x1024) in Watch-Assets kopiert und Contents.json referenziert.

---

### Feature: Watch Voice Capture — Button → Spracheingabe → Task im Backlog
**Status:** ERLEDIGT (2026-02-17)
**Dateien:** `WatchLocalTask.swift`, `WatchTaskMetadata.swift` (neu), `FocusBloxWatchApp.swift`, `ContentView.swift` (Watch), `Entitlements`
**Spec:** `docs/specs/features/watch-voice-capture.md` (v2.0)
**Loesung:**
- WatchLocalTask Schema mit iOS synchronisiert (5 fehlende Felder + 3 Typ-/Default-Korrekturen)
- TaskMetadata-Kopie fuer CloudKit Schema-Paritaet
- ModelContainer mit App Group + CloudKit (resilient mit Fallback)
- ContentView: "Task hinzufuegen" Button → VoiceInputSheet → ConfirmationView → Task in Liste
- Entitlements: App Group `group.com.henning.focusblox` eingetragen
**Tests:** 9 Unit Tests (Schema-Paritaet, TBD-Defaults) + 2 UI Tests (Button, Sheet) GREEN

---

### ITB-B: Smart Priority — AI-Enrichment + Hybrid-Scoring
**Status:** ERLEDIGT (2026-02-19, Refactoring)
**Dateien:** `SmartTaskEnrichmentService.swift` (neu), `TaskPriorityScoringService.swift` (neu), `PlanItem.swift`, `BacklogView.swift`, `BacklogRow.swift`, `CreateTaskView.swift`, `SettingsView.swift`, `MacSettingsView.swift`, `SidebarView.swift`, `MacBacklogRow.swift`, `ContentView.swift` (macOS)
**Loesung:** Opakes AI-Scoring durch 2-Schicht-System ersetzt: (1) SmartTaskEnrichmentService fuellt fehlende Attribute via FoundationModels, (2) TaskPriorityScoringService berechnet deterministischen 0-100 Score. ViewMode "Prioritaet" immer sichtbar (nicht AI-gated), Tier-Sektionen (Sofort/Bald/Gelegenheit/Irgendwann). iOS + macOS gleichwertig.

---

### Bug 57: Apple Reminders - Erweiterte Attribute gehen verloren bei macOS+iOS Parallelbetrieb
**Status:** ERLEDIGT (2026-02-17)
**Commit:** `1cbca2f`
**Dateien:** `Sources/Services/RemindersSyncService.swift`
**Loesung:** Attribut-Schutz bei Reminders-Sync — nur schreiben wenn Wert sich wirklich geaendert hat.

---

### Bug 56: Erweiterte Attribute via CloudKit ueberschrieben (Bug 48 Regression)
**Status:** ERLEDIGT (2026-02-17)
**Commit:** `f9eda30`
**Dateien:** `EditTaskSheet` geloescht, `TaskFormSheet` fuer Edits eingefuehrt
**Loesung:** EditTaskSheet durch TaskFormSheet ersetzt, das optionale Attribute korrekt handhabt (nil bleibt nil).

---

### Bug 58: MenuBarExtra Icon erscheint nicht in macOS Menuleiste
**Status:** ERLEDIGT (2026-02-17)
**Dateien:** `FocusBloxMac/FocusBloxMacApp.swift`
**Root Cause:** Hidden Bar (und aehnliche Menu-Bar-Manager) platzieren neue NSStatusItems in eine unsichtbare "always hidden"-Tier. SwiftUI MenuBarExtra bietet keine Kontrolle ueber `autosaveName` oder Position-Persistenz, daher landet das Icon immer hinter allen Separatoren.
**Loesung:** SwiftUI `MenuBarExtra` durch manuellen `MenuBarController` (NSStatusItem + NSPopover) ersetzt. `autosaveName` fuer Position-Persistenz + Pre-set der Preferred Position auf 300 (sichtbarer Bereich) beim ersten Start. `setActivationPolicy(.regular)` in init() beibehalten (kritisch fuer Keyboard/Mouse-Events).

---

### Feature: Report zeigt Tasks ausserhalb von Sprints (iOS + macOS)
**Status:** ERLEDIGT (2026-02-16)
**Commit:** `6cecc26`
**Dateien:** `DailyReviewView.swift`, `MacReviewView.swift`, `FocusBloxApp.swift`
**Spec:** `docs/specs/features/report-all-completed-tasks.md`
**Loesung:** Stats zaehlen jetzt ALLE Tasks mit completedAt=heute. Neue Sektion "Ohne Sprint erledigt". loadData() Bug gefixt: SwiftData-Tasks laden unabhaengig von Calendar-Zugriff.

---

### Feature: QuickAdd "Next Up" Checkbox (iOS + macOS)
**Status:** ERLEDIGT (2026-02-16)
**Commit:** `5426f6a`
**Dateien:** `QuickCaptureView.swift`, `QuickCapturePanel.swift`, `MenuBarView.swift`
**Loesung:** Toggle-Button in allen 3 Quick-Add-Flows (iOS + 2x macOS). ~30 LoC netto.

---

### Feature: Wiederkehrende Tasks Phase 1A
**Status:** ERLEDIGT (2026-02-16)
**Commit:** `2767a92`
**Dateien:** `RecurrenceService.swift`, `SyncEngine.swift`, `FocusBlockActionService.swift`, `BacklogRow.swift`
**Loesung:** RecurrenceService (nextDueDate + createNextInstance), Integration in SyncEngine/FocusBlockActionService, Purple Recurrence Badge. 10 Unit Tests GREEN.

---

### Feature: MenuBar FocusBlock Status (macOS)
**Status:** ERLEDIGT (2026-02-16)
**Commit:** `5c71089`
**Dateien:** `MenuBarView.swift`, `FocusBloxMacApp.swift`
**Loesung:** Menu Bar Label zeigt Restzeit (mm:ss), Popover mit Focus Section, Complete/Skip Buttons.

---

### Bug 55: FocusBlox-Session zeigt falsche Timer, Notifications und Sprint Review
**Status:** ERLEDIGT (2026-02-15)
**Commit:** `0de32f1`
**5 Sub-Bugs:** Timer-Overflow, Notification 0/0, Sprint Review 0m, doppelte Live Activities.

---

### Bug 54: Wiederkehrende iCloud Termine - Kategorie-Zuordnung
**Status:** ERLEDIGT (2026-02-15)
**Loesung:** `.futureEvents` statt `.thisEvent` fuer wiederkehrende Events.

---

### Bug 51: Backlog-Sortierung iOS vs macOS
**Status:** ERLEDIGT (2026-02-15)
**Commit:** `4d61fef`
**Loesung:** iOS-Sortierung auf `createdAt` absteigend umgestellt (wie macOS).

---

### Bug 50: Kalender-Events mit Gaesten funktionieren nicht
**Status:** ERLEDIGT (2026-02-16)
**Loesung:** `hasAttendees`/`isReadOnly` Erweiterung, Drag & Drop nur fuer editierbare Events, Schloss-Icon.

---

### Bug 49: Matrix View - Swipe-Gesten + Layout zu breit
**Status:** ERLEDIGT (2026-02-16)
**Commit:** `6e02b93`
**Loesung:** `.contextMenu` statt `.swipeActions` in Matrix, `.fixedSize()` von Badges entfernt.

---

### Bug 48: Erweiterte Attribute werden wiederholt geloescht
**Status:** ERLEDIGT (2026-02-14)
**Commits:** `27522e8`, `16749b7`
**Loesung:** SyncEngine if-let Guards, Int? statt TaskPriority, macOS Quick Capture auf LocalTaskSource umgestellt.

---

### Bug 52: Tasks verschwinden aus iOS Backlog nach Entfernen aus Next Up
**Status:** ERLEDIGT (2026-02-14)
**Loesung:** `assignedFocusBlockID = nil` an 4 Stellen + einmalige Datenbereinigung.

---

### Bug 38: Cross-Platform Sync (4 Fixes)
**Status:** ERLEDIGT (2026-02-14)
**Commits:** `49f5f9c`, `165a2b1`, `5946410`
**Loesung:** Alle Kalender laden, SyncedSettings, CloudKitSyncMonitor, Race Condition Fix (save vor Fetch).

---

### BACKLOG-001 bis BACKLOG-012: Code-Duplikate bereinigt
**Status:** ERLEDIGT (2026-02-13)
**Highlights:**
- BACKLOG-001: FocusBlockActionService extrahiert (Complete/Skip Logik)
- BACKLOG-002: EventKitRepository Injection auf macOS
- BACKLOG-003 bis BACKLOG-011: Timer, Date-Formatter, Color, Review-Komponenten, Category-Switches, Importance/Urgency, Due Date, Settings-Komponenten dedupliziert
- BACKLOG-012: WON'T FIX (Settings Load/Save nicht echt dupliziert)

---

### Weitere erledigte Bugs (2026-02-10 bis 2026-02-12)

| Bug | Beschreibung | Datum |
|-----|--------------|-------|
| Bug 47 | Vorwarnung-Settings ohne Auswirkung (macOS) | 2026-02-12 |
| Bug 41 | LiveActivity Timer Fixes | 2026-02-12 |
| Bug 40 | Review Tab zeigt erledigte Tasks nicht | 2026-02-12 |
| Bug 39 | FocusBlock Lifecycle (4 Fixes) | 2026-02-12 |
| Bug 35 | Quick Capture - Spotlight + CC Button | 2026-02-12 |
| Bug 34 | Duplikate nach CloudKit-Aktivierung | 2026-02-11 |
| Bug 33 | Cross-Platform Sync (CloudKit + App Group) | 2026-02-11 |
| Bug 32 | Importance/Urgency Race Condition | 2026-02-10 |
| Bug 31 | Focus Block Startzeit/Endzeit Sync | 2026-02-10 |
| Bug 30 | Kategorie-Bezeichnungen inkonsistent | 2026-02-10 |
| Bug 29 | Duration-Werte korrigiert | 2026-02-10 |
| Bug 26 | macOS Zuweisen Drag&Drop | 2026-02-10 |
| Bug 25 | macOS Planen echte Kalender-Daten | 2026-02-10 |
| Bug 21 | Tags-Eingabe ohne Autocomplete | 2026-02-10 |
| Bug 18 | Reminders Dringlichkeit/Wichtigkeit | 2026-02-10 |
| Bug 17 | BacklogRow Badges als Chips | 2026-02-10 |
| Feature | Kalender-Events in Review-Statistiken | 2026-02-11 |
| MAC-021 | Review Dashboard (macOS) | 2026-02-16 |

---

## ✅ Aeltere erledigte Bugs (Archiv)

| Bug | Beschreibung | Status |
|-----|--------------|--------|
| Bug 24 | iOS App keine Tasks (Info.plist) | ERLEDIGT (2026-02-02) |
| Bug 23 | macOS Kalender-Zugriff (Info.plist) | ERLEDIGT (2026-02-02) |
| Bug 22 | Edit-Button in Backlog Toolbar | ENTFERNT (Button wird geloescht) |
| Bug 20 | QuickCapture Tastatur verdeckt | ERLEDIGT (2026-02-02) |
| Bug 19 | Wiederkehrende Aufgaben | ERLEDIGT (bereits implementiert) |
| Bug 16 | Focus Tab keine weiteren Tasks | ERLEDIGT (bereits im Code) |
| Bug 15 | Ueberspringen Endlosschleife | ERLEDIGT (2026-01-30) |
| Bug 14 | Assign Tab Next Up nicht sichtbar | ERLEDIGT (bereits im Code) |
| Bug 13 | Blox Tab keine Block-Details | ERLEDIGT (2026-01-29) |
| Bug 12 | Kategorie-System inkonsistent | ERLEDIGT (2026-01-26) |
| Bug 11 | Pull-to-Refresh nur Backlog | ERLEDIGT (2026-01-26) |
| Bug 9 | Vergangene Zeitslots | ERLEDIGT (2026-01-24) |
| Bug 8 | Kalender-Berechtigung | ERLEDIGT (2026-01-24) |
| Bug 7 | Focus Block Scrolling | ERLEDIGT |

### Themengruppen (alle abgeschlossen)

| Gruppe | Thema | Status |
|--------|-------|--------|
| A | Next Up Layout (Horizontal zu Vertikal) | Alle 3 Stellen |
| B | Next Up State Management | Alle Bugs |
| C | Drag & Drop Sortierung | Next Up + Focus Block |
| D | Quick Task Capture | Control Center, Widget, Siri |
| E | Focus Block Ausfuehrung | Live Activity, Timer, Notifications |
| F | Sprint Review | Zeit-Tracking + UI |
| G | BacklogRow Redesign | Glass Cards, Chips, Swipe-Actions |

---

## Tooling

### Test-Qualitaet: Erst verstehen, dann testen
**Status:** ERLEDIGT (2026-02-19)
**Dateien:** `.claude/commands/04-tdd-red.md`, `.claude/commands/10-bug.md`
**Aenderung:** `/tdd-red` um Kernfrage erweitert: "Welche Zeile bricht diesen Test?" Kein Test ohne Antwort. Unit Tests PFLICHT bei Business-Logik. Kein Buerokratie-Overhead — Verstaendnis statt Formulare.

---

### Pre-Commit Gate: ACTIVE-todos.md Pflicht
**Status:** ERLEDIGT (2026-02-17)
**Datei:** `.claude/hooks/pre_commit_gate.py`
**Regel:** Jeder `git commit` wird blockiert wenn `docs/ACTIVE-todos.md` nicht in den staged files ist. Laeuft immer, unabhaengig vom Test-Gate.

---

### Workflow-System: Parallele Workflows
**Status:** ERLEDIGT (2026-02-11)
**Fix:** Dateibasierte Workflow-Aufloesung in `workflow_gate.py`
