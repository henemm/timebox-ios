# Proposal: Monster Coach Phase 3a — Intention-basierter Backlog-Filter

> Erstellt: 2026-03-12
> Status: Zur Freigabe
> Bezug: User Story `docs/project/stories/monster-coach.md`

---

## Was und Warum

### Das Problem

Nach dem Setzen der Morgen-Intention passiert nichts. Der User tippt "Intention setzen" und landet wieder im Review-Tab — ohne Bruecke zum eigentlichen Arbeiten. Der Tagesbogen reisst genau an der wichtigsten Stelle ab: Intention → Backlog.

### Was diese Phase loest

Phase 3a schliesst den Loop: Intention setzen → App springt in den Backlog → der Backlog ist bereits auf die Intention gefiltert. Der User sieht sofort welche Tasks heute relevant sind und kann diese als NextUp markieren.

Das entspricht exakt dem Tagesbogen aus der User Story:
> "Die App wechselt zum Backlog, gefiltert auf Tasks mit Wichtigkeit 3 und lang verschobene Tasks. Anna sieht die Steuererklärung ganz oben. Sie markiert sie als NextUp."

---

## Scope: Was gebaut wird

### 1. DailyIntention — Filter-Mapping

In `DailyIntention.swift` wird eine neue computed property `intentionFilter` fuer `IntentionOption` ergaenzt.

Jede `IntentionOption` weiß damit selbst, wie sie Tasks filtert:

| IntentionOption | Filter-Kriterium auf PlanItem |
|-----------------|-------------------------------|
| `.survival` | Sonderstatus: ueberschreibt alles, kein Filter |
| `.fokus` | `item.isNextUp == true` |
| `.bhag` | `item.importance == 3` ODER `item.rescheduleCount >= 2` |
| `.balance` | kein Task-Filter, aber spezielle Gruppierung nach Kategorie |
| `.growth` | `item.taskType == "learning"` |
| `.connection` | `item.taskType == "giving_back"` |

### 2. MorningIntentionView — Tab-Wechsel nach Setzen

Beim Tippen auf "Intention setzen" wird zusaetzlich:
1. Die aktiven Intentions-Filter in `@AppStorage("intentionFilterOptions")` gespeichert (JSON-kodiert, Array der rawValues)
2. Die `selectedTab`-Binding auf `.backlog` gewechselt

Dafuer braucht `MorningIntentionView` einen neuen Parameter:
```
var onIntentionSet: () -> Void
```
Dieser Callback wird in `DailyReviewView` uebergeben und navigiert den Tab.

**Alternativ ueber AppStorage:** `MorningIntentionView` setzt einen `@AppStorage`-Key. `MainTabView` oder `FocusBloxApp` beobachtet diesen Key und wechselt den Tab. Dieser Ansatz vermeidet das Durchreichen von Bindings ueber mehrere View-Ebenen.

**Entscheidung: AppStorage-Ansatz.**

Neuer Key: `"intentionJustSet"` (Bool, wird nach Tab-Wechsel sofort auf `false` zurueckgesetzt).
Filter-Key: `"intentionFilterOptions"` (String, kommagetrennte rawValues).

### 3. BacklogView — Intention-Filter-Chips + gefilterte Tasks

Am oberen Rand des Backlogs erscheint, wenn Intention-Filter aktiv sind, eine horizontale Chip-Leiste. Jeder Chip zeigt Icon + Label der Intention und hat ein X zum Abschalten. Wenn alle Chips abgeschaltet werden, verschwindet die Leiste.

**Filter-Logik:**

```
Wenn "survival" in aktiven Filtern: alle Tasks zeigen (kein Filter)
Sonst: Task ist sichtbar wenn er EINEN der aktiven Filter erfuellt
  - fokus: item.isNextUp
  - bhag: item.importance == 3 || item.rescheduleCount >= 2
  - balance: kein Kriterium — zeigt alle Tasks aber gruppiert nach Kategorie
  - growth: item.taskType == "learning"
  - connection: item.taskType == "giving_back"
```

**Besonderheit "balance":** Wenn nur `.balance` (ohne `.survival`) aktiv ist, zeigt der Backlog alle Tasks — aber in der bestehenden `.priority` ViewMode werden die Tier-Sections durch Kategorie-Sections ersetzt. Diese Logik ist ein spezieller Zweig in `priorityView`.

**Die Filter-Chips erscheinen ueber der SearchBar / am Anfang der Liste.** Sie ersetzen NICHT den bestehenden ViewMode-Switcher — der bleibt unberuehrt.

**State:** `@AppStorage("intentionFilterOptions")` liest aktive Filter. Wenn leer oder nil: kein Intention-Filter aktiv.

### 4. FocusBloxApp — Tab-Wechsel Observer

`FocusBloxApp` liest `@AppStorage("intentionJustSet")`. Wenn `true`:
- `selectedTab = .backlog` setzen
- `intentionJustSet` auf `false` zuruecksetzen

Dies geschieht per `.onChange(of: intentionJustSet)`.

---

## Architektur-Entscheidungen

### Warum AppStorage statt Binding-Durchreichung?

`MorningIntentionView` ist tief in `DailyReviewView` eingebettet. Um eine `selectedTab`-Binding hindurchzureichen, muesste sie durch `DailyReviewView` und `MainTabView` gefuehrt werden — das sind mindestens 3 Ebenen. AppStorage ist hier sauberer und bestaetigt sich als bestehendes Muster im Projekt (`coachModeEnabled`, `backlogViewMode`).

### Warum kein neuer ViewMode?

Die bestehenden ViewModes (`.priority`, `.recent`, `.overdue`, `.recurring`, `.completed`) beschreiben WIE Tasks sortiert/gruppiert werden. Der Intention-Filter beschreibt WELCHE Tasks zu sehen sind — eine orthogonale Dimension. Filter-Chips ueber dem bestehenden Modus-Switcher ist das richtige Modell (wie iOS Mail/Notizen es machen).

### Balance-Sonderfall

`.balance` ist der einzige Intentions-Filter der keine Task-Zeilen ausblendet, sondern nur die Gruppierung aendert. Wenn `.balance` aktiv ist (und kein `.survival`), werden im `.priority` ViewMode die Tier-Sections durch Kategorie-Sections ersetzt. Die anderen ViewModes (recent, overdue etc.) bleiben unveraendert.

---

## Dateien und Scoping

| Datei | Aenderung | Schaetzung |
|-------|-----------|-----------|
| `Sources/Models/DailyIntention.swift` | `intentionFilter` computed property auf `IntentionOption` | +25 LoC |
| `Sources/Views/MorningIntentionView.swift` | AppStorage-Write nach Intention-Setzen | +10 LoC |
| `Sources/Views/BacklogView.swift` | Filter-Chips UI + gefilterte Task-Computed-Props + Balance-Gruppierung | +90 LoC |
| `Sources/FocusBloxApp.swift` | `.onChange(of: intentionJustSet)` fuer Tab-Wechsel | +12 LoC |

**Gesamt: 4 Dateien, ca. +137 LoC — im Scope.**

---

## Was NICHT in Phase 3a enthalten ist

- Monster-Reaktion auf Intention (Phase 3b)
- Tages-Notification "Du wolltest das grosse Ding..." (spaetere Phase)
- Abend-Review der Intention-Erfullung (spaetere Phase)
- macOS — der Intention-Flow ist iOS-only (MorningIntentionView existiert nur im iOS-Target)
