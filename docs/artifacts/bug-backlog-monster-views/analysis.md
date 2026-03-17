# Bug-Analyse: macOS Coach-Backlog ("Monster") — Fehlende funktionale Views

## Bug-Beschreibung

Bei der vorherigen Analyse von "normal" (non-coach) vs. "monster" (coach-mode) Backlog-Views wurde übersehen, dass die Monster-Variante auf macOS nur EINE View-Datei hat (`MacCoachBacklogView.swift`), während funktional notwendige Features fehlen, die in der normalen Version vorhanden sind.

---

## 1. Agenten-Ergebnisse — Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- 65+ Commits zum Backlog-System in den letzten Wochen
- FEATURE_003 (Quick-Add) gerade fertig, 9 weitere macOS-Features offen
- **FEATURE_013** (Serien-Bearbeitung, Low Prio) steht bereits in ACTIVE-todos.md
- FEATURE_001 (iOS Recurring-Dialoge) wurde als eigenes Ticket implementiert (`cd4e961`)
- BUG_108 (Zehnagel-Zombie): Gerade gefixt — betraf fehlende Recurring-Guards beim Löschen

### Agent 2 (Architektur-Trace)
Vollständige View-Inventur:

| Datei | Plattform | LoC | Zweck |
|-------|-----------|-----|-------|
| `BacklogView.swift` | iOS (Sources/) | 1.380 | Standard-Backlog (non-coach) |
| `CoachBacklogView.swift` | iOS (Sources/) | 896 | Coach/Monster-Backlog |
| `BacklogRow.swift` | iOS (Sources/) | 286 | Shared Row-Komponente |
| `MacCoachBacklogView.swift` | macOS (FocusBloxMac/) | 575 | Coach/Monster-Backlog |
| `MacBacklogRow.swift` | macOS (FocusBloxMac/) | 308 | macOS Row-Komponente |
| `ContentView.swift` (Zeilen 374–653) | macOS (FocusBloxMac/) | ~280 | Standard-Backlog **INLINE** |

### Agent 3 (Alle Views)
- 9 eigenständige View-Structs, 5 Badge-Komponenten, 2 Picker
- macOS Coach-Backlog hat keine eigenen Sub-Views — alles in einer Datei

### Agent 4 (Fehlende Szenarien)
Funktionalitäts-Vergleich ergab erhebliche Lücken (siehe Abschnitt 3)

### Agent 5 (Blast Radius)
- BacklogRow vs MacBacklogRow: ~80% Duplikation
- ViewMode Enum: exakt dupliziert (BacklogView.ViewMode vs CoachViewMode)
- Code-Sharing-Prinzip aus CLAUDE.md wird mehrfach verletzt

---

## 2. Überlappungen der Ergebnisse

Alle 5 Agenten bestätigen dasselbe Kernproblem:

**Die macOS Coach-Backlog ("Monster") hat als einzige View `MacCoachBacklogView.swift` (575 LoC). Die macOS NON-Coach Backlog (in ContentView inline, Zeilen 374–653) hat aber Features, die der Monster-View FEHLEN:**

| Feature | macOS Normal (ContentView) | macOS Monster (MacCoachBacklogView) | Status |
|---------|--------------------------|-------------------------------------|--------|
| Recurring Delete Dialog | Zeilen 583–606 | FEHLT | **DATENVERLUST-RISIKO** |
| Recurring Edit Dialog | Zeilen 607–632 | FEHLT | Geplant: FEATURE_013 |
| End Series Dialog | Zeilen 633–652 | FEHLT | Geplant: FEATURE_013 |
| Search | (nicht implementiert) | FEHLT | Geplant: FEATURE_004 |
| Deferred Sort Feedback | (nicht implementiert) | FEHLT | Geplant: FEATURE_009 |
| Undo (Cmd+Z) | (nicht implementiert) | FEHLT | Geplant: FEATURE_011 |

---

## 2a. Bug vs. Feature Abgrenzung

### Klar ein BUG (unbeabsichtigt, Datenverlust-Risiko):
- **Recurring Delete ohne Dialog:** `MacCoachBacklogView.swift` Zeile 558–563 macht `task.modelContext?.delete(task)` OHNE Prüfung auf `recurrencePattern` oder `recurrenceGroupID`. Das ist exakt dasselbe Pattern wie BUG_108 (Zehnagel-Zombie) — die Vorlage überlebt, generiert weiter Instanzen.

### Geplante Features (bewusst Low-Prio in ACTIVE-todos.md):
- FEATURE_004 (Search), FEATURE_009 (Deferred Sort), FEATURE_011 (Undo), FEATURE_013 (Serien-Bearbeitung/Edit-Dialoge)

**Konsequenz:** Der Delete-Bug ist DRINGEND (Datenverlust). Die Edit/EndSeries-Dialoge sind Feature-Backlog.

---

## 3. ALLE möglichen Ursachen

### Hypothese A: Delete ohne Recurring-Guard → Datenverlust (HOCH)

**Beschreibung:** `MacCoachBacklogView.swift` Zeile 558–563 löscht Tasks direkt ohne zu prüfen ob sie wiederkehrend sind. Die Vorlage (Template) wird nicht gelöscht und generiert weiter neue Instanzen.

**Beweis DAFÜR:**
- `MacCoachBacklogView.swift:558`: `task.modelContext?.delete(task)` — kein Guard
- `ContentView.swift:935-940`: `deleteSingleTask()` macht dasselbe — aber wird NUR über Dialog aufgerufen
- `ContentView.swift:583-606`: Der Dialog fragt "Nur diese" vs "Alle der Serie" BEVOR gelöscht wird
- BUG_108 hatte exakt dasselbe Problem (Zehnagel-Zombie)
- `MacBacklogRow.swift:127-128`: `RecurrenceBadge` zeigt recurring Tasks sichtbar an — User SEHEN sie und können sie löschen

**Beweis DAGEGEN:**
- Keiner gefunden

**Wahrscheinlichkeit:** HOCH — Code-Beweis eindeutig

### Hypothese B: Architektur-Divergenz durch separate Entwicklung (HOCH)

**Beschreibung:** Die macOS Coach-Backlog wurde als eigenständige View parallel zur iOS-Version entwickelt. Features die in iOS CoachBacklogView oder macOS Normal-Backlog existieren wurden nicht portiert.

**Beweis DAFÜR:**
- iOS CoachBacklogView nutzt `BacklogRow` (PlanItem-basiert)
- macOS nutzt eigenes `MacBacklogRow` (LocalTask-basiert) — 80% Code-Duplikation
- ViewMode Enum ist identisch aber doppelt definiert
- CLAUDE.md Code-Sharing-Regel wird verletzt
- FEATURE_001 (iOS Recurring-Dialoge) war ein eigenes Ticket — macOS-Pendant nie erstellt

**Beweis DAGEGEN:**
- Manche UI-Patterns sind tatsächlich plattformspezifisch (Swipe vs Context Menu)

**Wahrscheinlichkeit:** HOCH — strukturelles Problem

### Hypothese C: Feature-Backlog bewusst priorisiert (MITTEL für Features, NIEDRIG für Delete-Bug)

**Beschreibung:** Viele fehlende Features stehen bereits als ACTIVE-todos.md Einträge. FEATURE_013 deckt die Edit/EndSeries-Dialoge ab.

**Beweis DAFÜR:**
- FEATURE_013 steht in ACTIVE-todos.md als "Low" Priorität
- Es gibt eine klare Feature-Roadmap

**Beweis DAGEGEN:**
- Der **Delete-Bug** (Löschen ohne Recurring-Guard) ist in FEATURE_013 NICHT adressiert — FEATURE_013 beschreibt "Serien-Bearbeitung", nicht "sicheres Löschen"
- Henning hat explizit auf fehlende Views hingewiesen

**Wahrscheinlichkeit:** MITTEL — erklärt die Edit-Dialoge, NICHT den Delete-Bug

### Hypothese D (neu, vom Challenger): BUG_108-Muster wiederholt sich

**Beschreibung:** Der gerade gefixte BUG_108 (Zehnagel-Zombie) betraf fehlende Recurring-Guards beim Löschen. Genau dieses Pattern existiert in `MacCoachBacklogView.swift:558-563`.

**Beweis DAFÜR:**
- BUG_108 Commit `0738f35`: "Recurring Task überlebt Serien-Ende"
- `MacCoachBacklogView.swift:558`: Identisches Pattern — `delete(task)` ohne Guard
- Template überlebt → generiert neue Instanzen → "Zombie"

**Beweis DAGEGEN:**
- Keiner

**Wahrscheinlichkeit:** HOCH — dasselbe Pattern, andere Stelle

---

## 4. Wahrscheinlichste Ursache(n)

**Kombination aus Hypothese A + D (Delete-Bug) + B (Architektur-Divergenz):**

1. **SOFORT-Bug:** MacCoachBacklogView löscht Recurring Tasks ohne Guard → Zehnagel-Zombie Pattern (BUG_108 Wiederholung an anderer Stelle)
2. **Struktur-Problem:** Die Monster-View wurde als Monolith entwickelt, ohne die Recurring-Dialoge aus ContentView.backlogView zu portieren

### Warum die anderen weniger wahrscheinlich:
- Hypothese C erklärt nur die Edit/EndSeries-Dialoge (geplant), nicht den Delete-Bug (ungeplant, Datenverlust)

### Debugging-Plan

**Bestätigung Hypothese A+D:** Einen wiederkehrenden Task im macOS Coach-Backlog löschen → Task wird direkt gelöscht, KEIN Dialog erscheint → Template überlebt → neue Instanz wird generiert

**Widerlegung:** Wenn der Dialog doch erscheint oder die Template-Löschung automatisch passiert

**Plattform:** macOS (primär). iOS CoachBacklogView hat die Dialoge bereits (FEATURE_001).

---

## 5. Blast Radius

### Direkt betroffen
- `MacCoachBacklogView.swift` Zeile 558–563 — Delete-Button braucht Recurring-Guard + Dialog
- ContentView.swift hat die Dialoge bereits (Zeilen 583–652) — kann als Vorlage dienen

### Verbindung zu BUG_108
- BUG_108 (Zehnagel-Zombie) war exakt dasselbe Pattern: Löschen ohne Recurring-Guard
- Der Fix für BUG_108 (`0738f35`) sollte geprüft werden ob er nur iOS oder auch macOS adressiert

### ZWEITER Delete-Pfad: Inspector (vom Challenger gefunden)
- `TaskInspector.swift:241-257`: Hat "Task löschen?"-Bestätigungsdialog, aber KEINEN Recurring-Guard
- `ContentView.swift:699`: `onDelete` Callback macht `modelContext.delete(task)` ohne Recurring-Prüfung
- Inspector erscheint auch im Coach-Modus (ContentView:213: `if selectedSection == .backlog`)
- **Ergebnis: ZWEI ungeschützte Delete-Pfade im Coach-Backlog**
  1. Context Menu in MacCoachBacklogView:558 (kein Dialog)
  2. Inspector Delete-Button in TaskInspector:241 (generischer Dialog, nicht recurring-aware)

### Geplante Features (KEIN Bug, sondern Backlog):
- FEATURE_004 (Search), FEATURE_009 (Deferred Sort), FEATURE_011 (Undo), FEATURE_013 (Edit/EndSeries Dialoge)

---

## 6. Zusammenfassung für Henning

**Gefunden: 4 Hypothesen, davon 2 bestätigt**

1. **SOFORT-Bug (Datenverlust):** Im macOS Coach-Backlog werden Recurring Tasks beim Löschen direkt gelöscht, ohne "Nur diese" vs "Alle der Serie" Dialog. Die Vorlage überlebt → Zehnagel-Zombie Pattern (wie BUG_108). Code: `MacCoachBacklogView.swift:558-563`

2. **Struktur-Problem:** Die Monster-View (macOS Coach-Backlog) ist ein 575-Zeilen-Monolith ohne die Sub-Features die die Normal-Backlog (ContentView) hat. Die Edit/EndSeries Dialoge fehlen — sind aber als FEATURE_013 (Low Prio) geplant.

3. **Challenge-Verdict:** LÜCKEN → nach Einarbeitung der Challenger-Findings (Datenverlust-Risiko, BUG_108-Verbindung, FEATURE_013-Kontext) jetzt adressiert.

**Empfehlung:** Den Delete-Bug (Recurring-Guard) an BEIDEN Stellen fixen:
1. `MacCoachBacklogView.swift:558` — Recurring-Prüfung + Dialog hinzufügen
2. `ContentView.swift:699` (Inspector) — Recurring-Prüfung + Dialog hinzufügen
Die Edit/EndSeries Dialoge über FEATURE_013 priorisieren.

**Challenge-Verdict:** 2 Runden, final LÜCKEN (zweiter Delete-Pfad im Inspector nachträglich gefunden und eingearbeitet).
