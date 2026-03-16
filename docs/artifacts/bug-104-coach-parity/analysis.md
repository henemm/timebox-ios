# Bug 104: Coach-Backlog Feature-Paritaet — Analyse

## Zusammenfassung

Coach-Backlog-Views (iOS: 298 LoC, macOS: 158 LoC) wurden als Minimal-Varianten gebaut. Die normale BacklogView hat 1380 LoC (iOS) bzw. ContentView 1164 LoC (macOS) — Coach-Views haben ~78% weniger Features.

**Das ist KEIN Regressions-Bug** — die Features wurden nie implementiert. Phase 5a (14.03.2026) baute bewusst minimale Coach-Views. Seitdem wurde nur Bug 103 (NextUp-Section) nachgeliefert.

---

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- 5 Commits am Coach-Backlog seit Einfuehrung (14.03.2026)
- Nur Bug 103 (NextUp) war ein Feature-Paritaets-Fix
- Andere Commits: Discipline-Override, leere Tasks macOS, Phase 6b Port
- Feature-Paritaet war NIE systematisch adressiert

### Agent 2: Feature-Map
- **iOS fehlen 9 Feature-Gruppen** (Badge-Interactions, Postpone, View-Modes, CloudKit, Undo, Recurrence, Deferred Feedback, Blocked Tasks, korrektes Edit-Sheet)
- **macOS fehlen 10 Feature-Gruppen** (Swipe, Quick-Add, Toolbar, Inspector, Multi-Selection, Badges, Drag-Reorder, Auto-Scroll, Postpone, Recurrence)
- Alle mit exakten Datei+Zeile verifiziert

### Agent 3: Coach-View Aufbau
- iOS CoachBacklogView: 3 Sections, BacklogRow mit nur 5 von 11 Callbacks verdrahtet
- macOS MacCoachBacklogView: 3 Sections, MacBacklogRow mit 2 von 11 Callbacks verdrahtet
- Shared CoachBacklogViewModel (46 LoC) ist solide — nur View-Layer fehlt
- BacklogRow/MacBacklogRow UNTERSTUETZEN bereits alle Features — Callbacks sind nur nicht verdrahtet

### Agent 4: Priorisierung
- 8 Arbeitspakete identifiziert, jedes innerhalb Scoping-Limits
- Empfohlene Reihenfolge: iOS Badge+Postpone+Sheet → iOS Sync+Undo → macOS Menu+Badges → iOS ViewModes → macOS QuickAdd+Toolbar → iOS Blocked+Recurrence → macOS Inspector → macOS Polish

### Agent 5: Blast Radius
- **Approach B empfohlen:** Features direkt in Coach-Views verdrahten (Callbacks existieren, nur nicht angeschlossen)
- Kein Refactoring der BacklogView noetig — Coach-Views bekommen die gleichen Callback-Muster
- Risiko: NIEDRIG (isolierte Aenderungen pro View)
- BacklogView und andere Views werden NICHT angefasst

---

## Hypothesen

### Hypothese 1: Feature-Gap ist rein ein Verdrahtungs-Problem (HOCH)
**Beweis DAFUER:**
- BacklogRow hat 11 Callback-Parameter, CoachBacklogView nutzt nur 5
- MacBacklogRow hat 11 Callback-Parameter, MacCoachBacklogView nutzt nur 2
- Alle Features existieren in den Row-Komponenten — sie sind nur nicht angeschlossen

**Beweis DAGEGEN:**
- Einige Features (View-Mode-Switching, Inspector, Toolbar) sind NICHT nur Callbacks sondern eigene UI-Strukturen
- Diese brauchen neuen Code, nicht nur Verdrahtung

**Fazit:** Stimmt fuer ~60% der Features (Badges, Postpone, Blocked, Deferred Feedback). Die restlichen ~40% brauchen neuen UI-Code.

### Hypothese 2: Architektur-Entscheidung "separate Views" war falsch (NIEDRIG)
**Beweis DAFUER:**
- Code-Duplikation ist hoch (gleiche Patterns in 2 Views)
- BacklogView koennte theoretisch einen Coach-Mode-Parameter bekommen

**Beweis DAGEGEN:**
- Coach-Views haben fundamental anderes Layout (Monster-Header, 3 Coach-Sections statt View-Modes)
- CLAUDE.md sagt explizit: "Coach-Modus = eigene Views statt Modifikationen an bestehenden Views"
- Architektur ist korrekt, nur Implementation unvollstaendig

**Fazit:** Architektur ist richtig. Separate Views mit shared Callbacks + ViewModel.

### Hypothese 3: Scoping-Problem — zu viel fuer einen Bug (HOCH)
**Beweis DAFUER:**
- 19 fehlende Feature-Gruppen auf 2 Plattformen
- Geschaetzter Gesamtaufwand: ~850 LoC ueber 8 Pakete
- Weit ueber Scoping-Limit (250 LoC / 5 Dateien)

**Beweis DAGEGEN:**
- Jedes einzelne Paket ist innerhalb der Limits
- Arbeitspakete sind unabhaengig voneinander

**Fazit:** Bug 104 muss in Arbeitspakete aufgeteilt werden.

---

## Empfohlene Aufteilung in Arbeitspakete

| Paket | Inhalt | Plattform | LoC | Dateien | Prio |
|-------|--------|-----------|-----|---------|------|
| **104a** | Badge-Interactions + Postpone + Edit-Sheet-Fix | iOS | ~90 | 1 | P1 |
| **104b** | **COMPLETION FIX** + Context-Menus + Badge-Interactions + Postpone | macOS | ~130 | 2 | **P0** |
| **104c** | CloudKit-Sync + Deferred Feedback + Shake-Undo | iOS | ~50 | 1 | P2 |
| **104d** | Quick-Add + Toolbar (Sync, Import, Count) | macOS | ~150 | 1 | P2 |
| **104e** | View-Mode Switching | iOS | ~100 | 1 | P3 |
| **104f** | Blocked-Tasks + Recurrence-Serie | iOS | ~80 | 1 | P3 |
| **104g** | Inspector + Multi-Selection + Drag-Reorder | macOS | ~200 | 2 | P3 |
| **104h** | Auto-Scroll + Recurrence (macOS) | macOS | ~60 | 1 | P4 |

**Paket 104a (iOS P1) im Detail:**
- 4 Badge-Callbacks verdrahten (onDurationTap, onImportanceCycle, onUrgencyToggle, onCategoryTap)
- State-Variablen fuer Duration-/Category-Selector hinzufuegen
- Postpone-ContextMenu + postponeTask() Funktion
- TaskDetailSheet → TaskFormSheet ersetzen (1-Zeilen-Fix)
- **1 Datei:** CoachBacklogView.swift
- **~90 LoC**

**Paket 104b (macOS P1) im Detail:**
- Context-Menu erweitern: Delete, Edit, Postpone (Morgen/Naechste Woche)
- Badge-Callbacks verdrahten (onImportanceCycle, onUrgencyToggle, onCategorySelect, onDurationSelect)
- **2 Dateien:** MacCoachBacklogView.swift, ggf. MacBacklogRow.swift
- **~120 LoC**

---

## Blast Radius

- **BacklogView (iOS):** NICHT betroffen — keine Aenderungen
- **ContentView (macOS):** NICHT betroffen — keine Aenderungen
- **BacklogRow / MacBacklogRow:** NICHT betroffen — Callbacks existieren bereits
- **CoachBacklogViewModel:** NICHT betroffen — Filtering-Logik bleibt
- **Andere Coach-Views (MeinTag, MorningIntention):** NICHT betroffen

---

## KRITISCHER FUND: macOS Completion broken

**MacBacklogRow.onToggleComplete ist NICHT verdrahtet in MacCoachBacklogView!**

MacCoachBacklogView.swift Zeile 114-117 uebergibt nur `disciplineColor` an MacBacklogRow.
`onToggleComplete` ist optional (`(() -> Void)?`) — der Button ruft `onToggleComplete?()` auf,
was bei nil NICHTS tut. **User klickt Checkbox → nichts passiert.**

Das ist kein Paritaets-Problem, sondern ein funktionaler Defekt der SOFORT gefixt werden muss.

→ **Paket 104b (macOS) muss P0 werden, nicht P1.**

## Revert-Erklaerung

Commit 9529d30 ("Kategorie-Schnellzugriff per Context Menu") wurde am 14.03.2026 durch c888990 revertiert.
Kontext: Am selben Tag wurde das Discipline-Override-Feature implementiert, das einen eigenen
Context Menu mit 4 Disziplin-Optionen brachte. Der Kategorie-Schnellzugriff wurde obsolet weil
Discipline-Override denselben UX-Slot (Context Menu) besetzt. Kein technisches Scheitern,
sondern bewusste Design-Entscheidung: Discipline statt Category im Coach-Kontext.

## Offene PO-Frage: Welche Features gehoeren in den Coach-Modus?

Der Coach-Modus ist bewusst als reduzierte, fokussierte Ansicht konzipiert.
Nicht alle BacklogView-Features sind im Coach-Kontext sinnvoll:

| Feature | Im Coach sinnvoll? | Begruendung |
|---------|-------------------|-------------|
| Badge-Interactions | JA | One-Touch Workflows sind Kernfunktion |
| Postpone | JA | Tasks verschieben ist taeglicher Workflow |
| View-Mode Switching | FRAGLICH | Coach hat eigene 3-Section-Struktur — braucht er 5 View-Modes? |
| Blocked Tasks | FRAGLICH | Coach filtert nach Actionable Tasks — blockierte passen nicht ins Konzept |
| Inspector (macOS) | FRAGLICH | Coach ist minimalistisch — braucht er eine Detailspalte? |
| Recurrence-Serie | JA (aber niedrig) | Edge Case, aber wichtig wenn relevant |
| CloudKit Remote-Sync | JA | Basis-Funktionalitaet |
| Shake-Undo | JA | Fehlerkorrektur ist immer sinnvoll |
| Deferred Feedback | JA | Visuelles Feedback ist UX-Qualitaet |
| Multi-Selection | FRAGLICH | Coach-Ansicht zeigt weniger Tasks — Bulk-Actions weniger relevant |

→ Henning muss entscheiden welche "FRAGLICH"-Features gewuenscht sind.

---

## Debugging-Plan (falls noetig)

Fuer Paket 104a:
- **Bestaetigung:** Badge-Tap in CoachBacklogView loest Callback aus → Sheet oeffnet sich
- **Widerlegung:** Badge-Tap tut nichts → Callback nicht korrekt verdrahtet oder BacklogRow ignoriert Parameter

Fuer Paket 104b:
- **Bestaetigung:** Right-Click zeigt Postpone + Delete + Edit im Context-Menu
- **Widerlegung:** Context-Menu zeigt nur Discipline → Callbacks nicht angeschlossen
