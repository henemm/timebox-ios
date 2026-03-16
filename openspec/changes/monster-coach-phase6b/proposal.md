# Proposal: Monster Coach Phase 6b — MacCoachBacklogView

**Erstellt:** 2026-03-14
**Feature:** Monster Coach Phase 6b
**Modus:** NEU (neue macOS View)
**Status:** Geplant

---

## Was und Warum

### Problem

macOS hat aktuell keinen Coach-Modus im Backlog. Wenn `coachModeEnabled == true` ist, zeigt ContentView.swift weiterhin das normale Backlog (Priority-Tiers, Overdue-Sektionen, SidebarFilter). Der Monster-Header, die Disziplin-Kreise und die Schwerpunkt/Weitere-Sektionen existieren nur auf iOS.

### Loesung

Neue `MacCoachBacklogView` in `FocusBloxMac/`, die bei aktiviertem Coach-Modus den normalen `backlogView` in `ContentView` ersetzt. Analog zum iOS-Pattern: ContentView prueft `coachModeEnabled` und zeigt entweder die normale Backlog-View oder die Coach-Variante.

---

## Aktueller Zustand (macOS)

**Layout:** `NavigationSplitView` mit 3 Spalten:
- **Sidebar** (`SidebarView`): Filter-Links (Prioritaet, Zuletzt, Ueberfaellig, Wiederkehrend, Erledigt)
- **Content** (`backlogView`): Quick-Add Bar + Task-Liste mit Priority-Tiers und Sections
- **Detail** (`inspectorView`): Task-Inspector fuer die ausgewaehlte Task

**Wo der Backlog gerendert wird:** `ContentView.mainContentView` -> `case .backlog: backlogView`. Die `backlogView` ist ein `@ViewBuilder` in ContentView.swift selbst (Zeilen 341–484).

**Coach-Modus in macOS:** Bisher KEIN Einfluss auf das Layout. Nur MacSettingsView.swift liest `coachModeEnabled` fuer den Settings-Tab (Phase 6a).

---

## Was sich aendern soll (Delta)

| Aspect | Vorher | Nachher |
|--------|--------|---------|
| Backlog bei coachModeEnabled | Normales Backlog (Priority-Tiers) | MacCoachBacklogView (Monster + Schwerpunkt/Weitere) |
| Sidebar bei coachModeEnabled | SidebarView mit Filtern | Vereinfachte Sidebar (nur "Coach" Eintrag, kein Filter) |
| Monster-Header | Nicht vorhanden | Oben in der Content-Spalte |
| Disziplin-Kreise | Nicht vorhanden | An jeder Task-Zeile in der Coach-View |
| Task-Sektionen | Priority-Tiers (DoNow/PlanSoon/...) | Schwerpunkt + Weitere Tasks |

---

## Architektur-Entscheidung

### Separate View vs. In ContentView einbetten

**Empfehlung: Neue Datei `FocusBloxMac/MacCoachBacklogView.swift`**

Begruendung:
- ContentView.swift ist bereits sehr gross (700+ LoC). Weitere Logik einbetten wuerde es unhandhabbar machen.
- Passt zum iOS-Pattern: dort ist CoachBacklogView.swift eine eigenstaendige View.
- ContentView.swift braucht nur eine einzige bedingte Zeile mehr im `mainContentView` Switch.

### Daten-Handling

macOS verwendet `LocalTask` (SwiftData `@Model`), iOS verwendet `PlanItem` (via SyncEngine). Die Konversion ist bekannt: `MacCoachBacklogView` folgt dem macOS-Pattern und arbeitet direkt mit `LocalTask`.

Das bedeutet: Die iOS `CoachBacklogView` kann NICHT direkt wiederverwendet werden. Die Logik wird portiert, aber mit macOS-spezifischen Typen.

### Was direkt wiederverwendet wird (shared Code in `Sources/`)

- `Discipline.classifyOpen(rescheduleCount:importance:)` — bereits in Sources/Models/Discipline.swift
- `DailyIntention.load()` — shared Model
- `IntentionOption.matchesFilter()` — fuer die Ranking-Logik
- `IntentionOption.monsterDiscipline` — fuer Monster-Header
- Monster-Assets (`monsterFokus`, etc.) — in Assets.xcassets

### Was macOS-spezifisch ist

- Arbeitet mit `LocalTask` statt `PlanItem`
- `MacBacklogRow` statt iOS `BacklogRow` fuer Task-Zeilen — aber `MacBacklogRow` hat aktuell KEIN `disciplineColor` Parameter (muss hinzugefuegt werden)
- Kein SwipeActions in macOS (kein `.swipeActions` modifier) — stattdessen Context-Menu (analog zu ContentView)
- Sidebar: Bei Coach-Modus vereinfacht — keine Filter-Optionen noetig (Intention bestimmt den "Filter")

---

## Betroffene Dateien

| Datei | Aktion | Geschaetzte LoC |
|-------|--------|-----------------|
| `FocusBloxMac/MacCoachBacklogView.swift` | NEU | ~150 LoC |
| `FocusBloxMac/ContentView.swift` | AENDERN: coachModeEnabled check in mainContentView + sidebar | ~15 LoC |
| `FocusBloxMac/MacBacklogRow.swift` | AENDERN: disciplineColor Parameter ergaenzen (wie iOS BacklogRow) | ~10 LoC |
| `FocusBloxMac/SidebarView.swift` | AENDERN: Coach-Modus Sidebar-Variante (oder Sidebar verstecken) | ~15 LoC |

**Gesamt: 4 Dateien, ~190 LoC**

---

## Sidebar-Verhalten im Coach-Modus

Wenn `coachModeEnabled == true` und `selectedSection == .backlog`:
- Die normale SidebarView mit 5 Filter-Optionen macht keinen Sinn mehr (Coach hat nur eine Ansicht)
- Empfehlung: Sidebar zeigt nur einen einzigen Eintrag "Backlog" (oder wird implizit ausgeblendet/vereinfacht)
- Alternative: Sidebar komplett ausblenden bei Coach-Modus (`columnVisibility = .detailOnly`)

Entscheidung offen fuer PO — ich empfehle den Eintrag zu vereinfachen (einen Label "Backlog" im Coach-Stil), damit die Drei-Spalten-Struktur erhalten bleibt.

---

## Test-Plan

### Unit Tests (keine neuen noetig)
- `Discipline.classifyOpen()` ist bereits durch bestehende iOS-Tests abgedeckt (6 Unit Tests gruen)

### UI Tests (neu, in MacCoachBacklogUITests.swift)
1. Coach-Modus AN + Backlog-Section → Monster-Header sichtbar (`coachMonsterHeader`)
2. Coach-Modus AUS + Backlog-Section → kein Monster-Header
3. Intention gesetzt → "Dein Schwerpunkt" Sektion vorhanden
4. Intention NICHT gesetzt → Hinweis-Text sichtbar

**Anzahl:** 4 UI Tests
**Simulator:** ID `1EC79950-6704-47D0-BDF8-2C55236B4B40` (macOS nutzt jedoch xcodebuild ohne Simulator)

---

## Abhaengigkeiten

| Entity | Status | Anmerkung |
|--------|--------|-----------|
| Discipline.classifyOpen() | Existiert | Sources/Models/Discipline.swift |
| DailyIntention.load() | Existiert | Sources/Models/DailyIntention.swift |
| IntentionOption.matchesFilter() | Existiert | Sources/Models/DailyIntention.swift |
| Monster-Assets | Existiert | Assets.xcassets |
| MacBacklogRow.disciplineColor | FEHLT | Muss analog zu iOS BacklogRow.disciplineColor ergaenzt werden |

---

## Nicht in diesem Scope

- Phase 6c (MorningIntentionView in macOS) — separates Ticket
- Phase 6d (EveningReflectionCard in macOS) — separates Ticket
- Bug 99 (Next-Up Swipe in iOS CoachBacklogView) — iOS-only Bug, anderes Ticket
