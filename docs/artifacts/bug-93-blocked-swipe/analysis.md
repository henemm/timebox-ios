# Bug 93: Swipe-Gesten bei eingerueckten Tasks — Analyse

## Agenten-Ergebnisse Zusammenfassung

### Agent 1: Wiederholungs-Check
- Fehlende Swipe-Actions war **bewusste Design-Entscheidung** in Phase 2 (Kommentar: "no swipe actions, dimmed + indented")
- BUG-DEP-6 fixte ein Modifier-Placement-Problem das ALLE Swipe-Actions brach — nicht spezifisch blocked rows
- Die Design-Entscheidung war falsch: Blocked Tasks sind dadurch "gefangen"

### Agent 2: iOS blockedRow Rendering-Trace
- `blockedRow()` (BacklogView.swift:958-968) hat: KEINE `.swipeActions`, KEIN `.contextMenu`
- Normale Rows haben: Leading Swipe (Next Up), Trailing Swipe (Bearbeiten + Loeschen), Context Menu (Verschieben)
- `onEditTap` wird an BacklogRow uebergeben aber **nie aufgerufen** — Dead Code (BacklogRow.swift:12)
- Inline Title-Edit per Doppel-Tap funktioniert, aber oeffnet NICHT die TaskFormSheet

### Agent 3: macOS Blocked Task Interaction
- macOS: Blocked Tasks KOENNEN per Klick selektiert werden → Inspector oeffnet → Blocker entfernbar via BlockerPickerSheet
- macOS Context Menu auf blocked rows: FEHLT (kein Rechtsklick-Menue)
- **macOS ist WENIGER betroffen** — Inspector bietet einen Workaround

### Agent 4: Dependency-Entfernung Szenarien
- **iOS:** KEIN direkter Weg die Abhaengigkeit zu entfernen (Edit-Form unerreichbar)
- **macOS:** Inspector funktioniert als Workaround
- **Beide:** Blocker erledigen/loeschen befreit Dependents automatisch (freeDependents)
- `onEditTap` Callback ist Dead Code — wird definiert aber nie getriggert

### Agent 5: Blast Radius
- `blockedRow()` wird von EINER Stelle aufgerufen: `backlogRowWithSwipe()` (Zeile 952-954)
- Gilt fuer ALLE View-Modes: Priority, Recent, Overdue
- **Single Point of Change:** Aenderung an `blockedRow()` wirkt automatisch ueberall
- macOS analog: `taskRowWithSwipe()` — ebenfalls 1 Stelle

---

## Hypothesen

### Hypothese 1: Fehlende swipeActions auf blockedRow() (SICHER — BEWIESENE ROOT CAUSE)

**Beweis DAFUER:**
- `blockedRow()` hat weder `.swipeActions()` noch `.contextMenu()` (BacklogView.swift:958-968)
- Kommentar sagt explizit "no swipe actions" — bewusst so implementiert
- Normale Rows haben 3 Swipe-Actions + Context Menu (BacklogView.swift:925-950)
- `onEditTap` in BacklogRow ist Dead Code — wird nie aufgerufen (BacklogRow.swift:12, kein Trigger)

**Beweis DAGEGEN:** Keiner. Code ist eindeutig.

**Wahrscheinlichkeit:** 100% — direkt im Code sichtbar

### Hypothese 2: Padding/Indent blockiert Swipe-Gesture-Erkennung

**Beweis DAGEGEN:**
- Irrelevant — es gibt gar keine `.swipeActions()` Modifier die blockiert werden koennten
- `.padding(.leading, 24)` in BacklogRow wuerde Swipe-Gesten auch nicht blockieren (SwiftUI List-Level)

**Wahrscheinlichkeit:** 0% — falscher Ansatz, Swipe-Actions existieren gar nicht

### Hypothese 3: BUG-DEP-6 Regression — Modifier-Placement brach Swipe erneut

**Beweis DAGEGEN:**
- BUG-DEP-6 ist gefixt (Commit f8490f7)
- Betraf nur normale Rows, nicht blocked rows
- Blocked rows hatten NIE swipeActions — kein Regression moeglich

**Wahrscheinlichkeit:** 0%

---

## Root Cause

**blockedRow() wurde bewusst ohne Interaktions-Moeglichkeiten implementiert.** Das war eine falsche Design-Entscheidung: Der User hat keinen Weg eine Abhaengigkeit zu entfernen ohne den Blocker zu erledigen/loeschen.

**Plattform-Unterschied:**
- **iOS:** Task komplett gefangen — kein Edit, kein Delete, kein Dependency-Remove
- **macOS:** Inspector bietet Workaround (Klick auf Row → Inspector → BlockerPickerSheet)

---

## Debugging-Plan

Nicht noetig — Root Cause ist durch Code-Analyse bewiesen. Es fehlen Modifier, kein Laufzeit-Problem.

---

## Fix-Vorschlag

### iOS (BacklogView.swift — blockedRow())
Swipe-Actions hinzufuegen:
1. **Trailing: "Bearbeiten"** (blau) → `handleEditTap(item)` → oeffnet TaskFormSheet mit Blocker-Picker
2. **Trailing: "Loeschen"** (rot) → `deleteTask(item)` → loescht den blockierten Task
3. **Leading: "Freigeben"** (orange) → neue Aktion: setzt `blockerTaskID = nil` direkt

KEIN "Next Up" Swipe — blockierte Tasks sollen nicht in Next Up.

### macOS (ContentView.swift — taskRowWithSwipe())
Context-Menu-Eintrag hinzufuegen:
- "Abhaengigkeit entfernen" wenn `blockerTaskID != nil`
(Inspector funktioniert bereits als Hauptpfad)

### Dateien (geschaetzt)
1. `Sources/Views/BacklogView.swift` — swipeActions auf blockedRow + freigeben-Logik (~20 LoC)
2. `FocusBloxMac/ContentView.swift` — Context-Menu-Eintrag (~5 LoC)

**KORREKTUR (nach Challenge):** `onEditTap` ist KEIN Dead Code — es ist ein Callback der bei normalen Rows via Swipe-Button getriggert wird. Bei blocked rows fehlt nur der Trigger (der Swipe-Button). Der Fix NUTZT den bestehenden onEditTap-Callback, statt ihn zu entfernen.

**TaskFormSheet blockerTaskID-Save:** Speichert direkt via modelContext (Zeile 540-541), unabhaengig vom onSave-Callback. Funktioniert korrekt.

---

## Blast Radius

- **iOS:** Fix wirkt automatisch in Priority, Recent, Overdue Views (Single Point of Change)
- **macOS:** Context-Menu-Eintrag wirkt fuer alle selektierten blocked tasks
- **Watch:** Nicht betroffen (zeigt keine Dependencies an)
- **Kein Risiko:** Bestehende freeDependents-Logik bleibt unveraendert
