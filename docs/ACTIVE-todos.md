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
| 8 | Push Notifications bei Frist | HOCH | M | ~60-80k | 4-5 | ~200 |
| 9 | MAC-031 Focus Mode Integration | P3 | M | ~50-70k | 2-3 | ~100 |
| 10 | MAC-030 Shortcuts.app | P3 | L | ~60-80k | 2-3 | ~150 |
| 11 | Emotionales Aufladen (Report) | MITTEL | L | ~80-100k | 3-4 | ~200 |
| 12 | MAC-026 Enhanced Quick Capture | P2 | L | ~80-120k | 4 | ~200 |
| 13 | MAC-020 Drag & Drop Planung | P2 | XL | ~100-150k | 3-4 | ~250 |
| 14 | MAC-032 NC Widget | P3 | XL | ~80-120k | neues Target | ~200 |
| 15 | ITB-A: FocusBlockEntity (AppEntity) | MITTEL | S | ~30-40k | 2 | ~60 |
| 16 | ITB-B: AI Task Scoring (Foundation Models) | MITTEL | L | ~80-120k | 3-4 | ~200 |
| 17 | ITB-C: OrganizeMyDay Intent | MITTEL | XL | ~100-150k | 4-5 | ~250 |
| 18 | ITB-D: Enhanced Liquid Glass (aktive Blocks) | NIEDRIG | S | ~20-30k | 2 | ~40 |
| 19 | ITB-E: Share Extension / Transferable | MITTEL | L | ~80-120k | 3-4 + Target | ~200 |
| 20 | ITB-F: CaptureContextIntent | RESEARCH | XL | unbekannt | unbekannt | unbekannt |
| 21 | ITB-G: Proaktive System-Vorschlaege | RESEARCH | XL | unbekannt | unbekannt | unbekannt |

**Komplexitaet:** XS = halbe Stunde | S = 1 Session | M = 2-3 Sessions | L = halber Tag | XL = ganzer Tag+

**Guenstigste Quick Wins:** #1 Symbole (~10k), #2 Wischgesten (~15k), #3 Long Press (~15k)
**Teuerste Items:** #17 OrganizeMyDay (~150k), #13 Drag & Drop (~150k), #14 NC Widget (~120k)
**RESEARCH Items:** #20 ITB-F und #21 ITB-G - API-Verifizierung noetig vor Planung

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
- Dedup-Logik (gleichzeitiges Completion auf 2 Geraeten)
- Quick-Edit Recurrence-Params Fix

### Bundle G: Intelligent Task Blox (Apple Intelligence + System-Integration)
**Empfohlene Reihenfolge:**
1. ITB-D (Liquid Glass) - Quick Win, unabhaengig
2. ITB-A (FocusBlockEntity) - Grundlage fuer Intents
3. ITB-E (Share Extension) - unabhaengig von AI
4. ITB-B (AI Scoring) - Kern-Feature, Graceful Degradation
5. ITB-C (OrganizeMyDay) - braucht A+B
6. ITB-F (Context Capture) - RESEARCH: API-Verifizierung zuerst
7. ITB-G (Proaktive Vorschlaege) - RESEARCH: API-Verifizierung zuerst

**Prinzip:** AI ergaenzt manuelles Scoring - schlaegt vor, User bestaetigt/ueberschreibt. Features unsichtbar auf Nicht-AI-Geraeten (Graceful Degradation).

---

## 🔴 OFFEN

### Bug 57: Apple Reminders - Erweiterte Attribute gehen verloren bei macOS+iOS Parallelbetrieb
**Status:** IN ARBEIT
**Prioritaet:** KRITISCH (Datenverlust)
**Entdeckt:** 2026-02-17
**Spec:** `docs/specs/bugfixes/bug-57-reminders-attribute-loss.md`

- **Location:** `Sources/Services/RemindersSyncService.swift` - `updateTask(_:from:)` Zeile 116-133
- **Symptom:** User setzt Attribute (Urgency, Importance, Duration, Category) auf iOS. Nach einiger Zeit sind alle Attribute wieder "?" (TBD). Betrifft Tasks aus Apple Reminders.
- **Root Cause (3 Probleme):**
  1. **macOS Sync ueberschreibt via CloudKit:** macOS `updateTask(_:from:)` schreibt title/dueDate/etc. bedingungslos auf LocalTask. SwiftData markiert gesamtes Objekt als dirty. CloudKit synct ALLE Felder (inkl. nil-Werte fuer urgency/importance/duration) zurueck zu iOS → Attribute ueberschrieben.
  2. **Instabile Reminder-IDs:** `ReminderData.swift:14` nutzt `calendarItemIdentifier` (Apple: "not guaranteed stable across syncs"). Bei ID-Aenderung: alter Task geloescht, neuer ohne Attribute erstellt.
  3. **Aggressives handleDeletedReminders:** `RemindersSyncService.swift:158-170` loescht Tasks sofort wenn Reminder-ID nicht im Fetch. Kein Soft-Delete, kein Grace Period.
- **Expected:** Einmal gesetzte erweiterte Attribute bleiben dauerhaft erhalten, unabhaengig davon welches Geraet den Reminders-Sync ausfuehrt.
- **Fix:** (A) Nur schreiben wenn Wert sich wirklich geaendert hat, (B) `calendarItemExternalIdentifier` nutzen, (C) handleDeletedReminders weniger aggressiv.
- **Test:** Attribute auf iOS setzen → macOS Sync ausloesen → Attribute muessen auf iOS erhalten bleiben.

---

### Bug 56: Erweiterte Attribute (Wichtigkeit/Dringlichkeit) via CloudKit ueberschrieben (Bug 48 Regression)
**Status:** OFFEN
**Prioritaet:** KRITISCH (Datenverlust)
**Entdeckt:** 2026-02-17

- **Location:** `Sources/FocusBloxApp.swift` - `forceCloudKitFieldSync()` V1, Commit `165a2b1`
- **Problem:** `forceCloudKitFieldSync` V1 setzt ALLE Felder bedingungslos (`task.importance = task.importance`). Bei Tasks mit nil-Feldern gibt dies nil einen frischen CloudKit-Timestamp. CloudKit last-writer-wins ueberschreibt dann echte Werte anderer Geraete mit nil.
- **Expected:** Nur Felder mit echten Werten bekommen frische Timestamps. Nil-Felder bleiben unveraendert (kein Update, kein neuer Timestamp).
- **Root Cause:** Commit `165a2b1` einfuehrte V1 von `forceCloudKitFieldSync()` mit unbedingten Feldzuweisungen. V2 (Commit `5946410`) korrigierte das fuer NEUE Geraete - aber auf Geraeten wo V1 bereits gelaufen ist, kann der Schaden schon eingetreten sein.
- **Sekundaerer Befund:** `EditTaskSheet.swift` hat `@State private var priority: TaskPriority` (NON-optional). TBD-Tasks (importance=nil) werden in `.low` (1) umgewandelt wenn EditTaskSheet gespeichert wird. Dies ist eine unvollstaendige Bug-48-RC2-Behebung - jedoch pre-existing und durch den aktuellen Report moeglicherweise nicht ausgeloest.
- **Test:** Task mit Wichtigkeit=Hoch auf Geraet A erstellen. App auf Geraet B mit frischen Daten starten. Pruefen ob Wichtigkeit nach CloudKit-Sync noch Hoch ist.

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
**Status:** OFFEN
**Prioritaet:** HOCH
**Komplexitaet:** M (~60-80k Tokens)

**Problem:** Tasks mit Due Date haben keine Erinnerung. Der User vergisst, sie in einen Sprint zu packen.
**Gewuenschtes Verhalten:**
- **Konfigurierbare Morgen-Erinnerung** (optional): Am Faelligkeitstag morgens "Heute faellig: Task X - pack ihn in einen Sprint"
- **Konfigurierbare Vorab-Erinnerung** (optional): XX Minuten/Stunden vor Frist
- Beide unabhaengig ein/ausschaltbar in Settings
- Uhrzeit der Morgen-Erinnerung konfigurierbar
- Auf **beiden Plattformen** (iOS + macOS)
**Scope:** ~150-200 LoC, 4-5 Dateien (NotificationService, AppSettings, SettingsView iOS+macOS)

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
- Quick-Edit Recurrence-Params: Quick-Edit-Funktionen uebergeben recurrence-Params nicht (Bug 48 Restwirkung)

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

### ITB-B: AI Task Scoring (Foundation Models)
**Status:** OFFEN
**Prioritaet:** MITTEL
**Komplexitaet:** L (~80-120k Tokens)
**Abhaengigkeiten:** Keine (aber Graceful Degradation PFLICHT)

**Problem:** Task-Priorisierung ist rein manuell. Nutzer muessen Wichtigkeit/Dringlichkeit selbst bewerten.
**Gewuenschtes Verhalten:**
- `AITaskScoringService` mit `LanguageModelSession` (Apple Intelligence)
- `InstructionsBuilder` als "Produktivitaets-Coach" Persona
- Kognitives Scoring: High/Low Energy Bewertung pro Task
- Deadline-Bewertung und Priorisierungs-Vorschlaege
- **AI schlaegt Werte VOR, manuell hat Vorrang**
- **Feature komplett unsichtbar ohne Apple Intelligence** (Graceful Degradation)
- Settings Toggle zum Aktivieren/Deaktivieren
**Scope:** ~200 LoC, 3-4 Dateien (Service, UI-Integration, Settings Toggle)

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

### ITB-F: CaptureContextIntent - RESEARCH
**Status:** OFFEN (RESEARCH - API-Verifizierung noetig)
**Prioritaet:** RESEARCH
**Komplexitaet:** XL (unbekannt)
**Abhaengigkeiten:** ITB-B + API-Verifizierung

**Zu verifizieren BEVOR Planung beginnt:**
- `IntentParameter(requestValue: .context)` - existiert diese API?
- `ForegroundContinuableIntent` - verfuegbar in iOS 26?
**Wenn API existiert:**
- Context-Extraktion via Apple Intelligence
- Automatische Task-Erstellung aus aktuellem Bildschirminhalt
- "Erstelle Task aus dem was ich gerade sehe"
**Status:** Keine Implementierung ohne API-Verifizierung. Zuerst Research.

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

### Workflow-System: Parallele Workflows
**Status:** ERLEDIGT (2026-02-11)
**Fix:** Dateibasierte Workflow-Aufloesung in `workflow_gate.py`
