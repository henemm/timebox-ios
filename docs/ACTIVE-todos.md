# Active Todos

> Zentraler Einstiegspunkt fuer alle aktiven Bugs und Tasks.
>
> **Regel:** Nach JEDEM Fix hier aktualisieren!
> **Archiv:** Erledigte Items → `docs/ARCHIVE-todos.md`

---

## Bugs (offen)

### Bug 94: macOS — Neuer Task ueber Eingabeschlitz bekommt keinen Fokus
- **Status:** OFFEN
- **Plattform:** macOS
- **Symptom:** Wenn man ueber den Eingabeschlitz einen neuen Task anlegt ("+"-Button), liegt der Fokus anschliessend NICHT auf dem neu erstellten Task. Man muss ihn manuell in der Liste suchen.
- **Erwartetes Verhalten:** Nach dem Erstellen soll der neue Task automatisch fokussiert/sichtbar sein (Scroll + Selection).
- **Hinweis:** War bereits einmal "gefixt" worden — der Fix war wirkungslos, wurde aber nicht durch Tests aufgedeckt. Diesmal muessen die Tests den tatsaechlichen Scroll/Fokus-Zustand verifizieren, nicht nur die Existenz des Tasks.

### Bug 95: Neue Tasks bekommen immer Faelligkeitsdatum "heute"
- **Status:** ERLEDIGT
- **Plattform:** iOS + macOS
- **Symptom:** Alle neu erstellten Tasks erhalten automatisch das Faelligkeitsdatum "heute", unabhaengig vom Inhalt oder Kontext.
- **Root Cause:** TaskTitleEngine AI-Enrichment setzte dueDate auf "heute" fuer generische Titel, weil der System-Prompt kein Nil-Beispiel hatte. Die AI halluzinierte Datum-Keywords.
- **Fix:** (1) Deterministische Keyword-Pruefung `titleContainsDateKeyword()` als Guard vor AI-dueDate-Akzeptanz, (2) Nil-Beispiel im AI-Prompt, (3) RecurrenceService Date()-Fallback entfernt.
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

### Phase 3d: Foundation Models Abend-Text (Must)
- On-Device AI generiert persoenlichen Text der konkrete Tasks beim Namen nennt
- Fallback auf handgeschriebene Template-Sprueche
- **Abhaengigkeit:** Phase 3c

### Phase 3e: Abend Push-Notification (Should)
- Optional, konfigurierbar (Default: 20:00 Uhr)
- Nur wenn `coachModeEnabled == true` UND heutige Intention gesetzt

### Phase 3f: Siri Integration / App Intents (Should)
- "Hey Siri, wie war mein Tag?" → liest Abend-Spiegel Auswertung vor
- "Setz meine Intention auf Fokus" → setzt DailyIntention
- **Abhaengigkeit:** Phase 3c

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
