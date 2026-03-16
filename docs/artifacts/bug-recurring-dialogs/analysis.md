# FEATURE_001: Coach-Backlog Recurring-Serie-Dialoge — Analyse

## Bug-Beschreibung

Coach-Backlog iOS zeigt keine "Nur diese Aufgabe" / "Alle dieser Serie"-Dialoge beim Loeschen/Bearbeiten wiederkehrender Tasks. BacklogView hat diese Dialoge seit Feb 2026 (Commit cd46645), Coach-Backlog nie.

**Praezisierung "Datenverlust":** Beim Loeschen wird immer nur EINE Instanz geloescht (implizites "Nur diese Aufgabe"). Der User hat aber KEINE WAHL — kann nicht "Alle dieser Serie" waehlen. Das ist weniger "Datenverlust" als "fehlende Kontrolle". Beim Bearbeiten werden Recurrence-Aenderungen auf der einen Instanz gespeichert, aber nicht auf die Serie propagiert.

---

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- Recurring-Dialog-Infrastruktur existiert seit **17. Feb 2026** in BacklogView + macOS ContentView
- Bug 104 (Coach-Backlog-Paritaet, 16. Maerz) hat 12 Feature-Luecken geschlossen — Recurring-Dialoge aber **uebersprungen**
- Nie zuvor versucht, kein gescheiterter Fix

### Agent 2: Datenfluss-Trace
- **BacklogView:** `deleteTask()` prueft `recurrencePattern` + `recurrenceGroupID` → zeigt Dialog → ruft `deleteSingleTask()` ODER `deleteRecurringSeries()`
- **CoachBacklogView:** `deleteTask()` ruft direkt `SyncEngine.deleteTask(itemID:)` — kein Check, kein Dialog
- **Edit-Flow:** BacklogView hat `editSeriesMode` Flag → steuert ob `updateTask()` oder `updateRecurringSeries()` aufgerufen wird. CoachBacklogView ignoriert Recurrence-Parameter komplett.

### Agent 3: Alle Schreiber
- SyncEngine hat alle noetige Methoden: `deleteTask()`, `deleteRecurringSeries()`, `updateRecurringSeries()`, `deleteRecurringTemplate()`
- CoachBacklogView nutzt NUR `deleteTask()` und `updateTask()` — die Serien-Methoden werden nie aufgerufen
- macOS MacCoachBacklogView: Gleiches Problem — `task.modelContext?.delete(task)` ohne jeglichen Check

### Agent 4: Alle Szenarien
| # | Szenario | Risiko |
|---|----------|--------|
| 1 | Swipe-Delete auf recurring Task | **HIGH** — kein Dialog |
| 2 | Delete-Button im Edit Sheet | **HIGH** — kein Dialog |
| 3 | Edit Recurrence Pattern | **MEDIUM** — Aenderungen werden stillschweigend ignoriert |
| 4 | Edit Series (alle Instanzen) | Feature-Luecke — nicht moeglich |
| 5 | Complete recurring Task | LOW — SyncEngine generiert naechste Instanz korrekt |
| 6 | Postpone/Duration/Category | LOW — nur Einzel-Instanz betroffen |

### Agent 5: Blast Radius
- **macOS MacCoachBacklogView:** Gleiches Problem (FEATURE_013 teilweise)
- **Normale Backlogs:** iOS + macOS haben die Dialoge bereits
- **Andere Views:** NextUpSection delegiert an Parent (sicher), FocusBlockTasksSheet moeglicherweise betroffen (niedrigere Prio)
- **SyncEngine:** Alle Methoden existieren, keine Aenderung noetig
- **Scope:** ~150-200 LoC Additions, 2-3 Dateien

---

## Hypothesen

### Hypothese 1: Feature-Luecke durch uebersprungene Paritaet (HOCH)
**Beschreibung:** Coach-Backlog wurde separat entwickelt und hat die Recurring-Dialog-Logik aus BacklogView nie erhalten. Bug 104 hat viele Luecken geschlossen, aber Recurring-Dialoge bewusst oder versehentlich ausgelassen.

**Beweis DAFUER:**
- `CoachBacklogView.swift:559-568` — `deleteTask()` hat keinen Recurrence-Check
- `CoachBacklogView.swift:81-89` — TaskFormSheet-Callback ignoriert Recurrence-Params
- Kein `taskToDeleteRecurring` State, kein `editSeriesMode` Flag
- Alle 5 Agenten bestaetigen: Feature wurde NIE implementiert

**Beweis DAGEGEN:** Keiner. Alle Code-Stellen bestaetigen die Luecke.

**Wahrscheinlichkeit:** HOCH (100% — bewiesen durch Code-Analyse)

### Hypothese 2: SyncEngine-Bug (NIEDRIG)
**Beschreibung:** SyncEngine koennte Recurring-Serien falsch behandeln.

**Beweis DAGEGEN:** SyncEngine hat `deleteRecurringSeries()` und `updateRecurringSeries()` — beide funktionieren in BacklogView. Problem ist nicht die Service-Schicht, sondern die fehlende UI-Schicht.

**Wahrscheinlichkeit:** NIEDRIG

### Hypothese 3: TaskFormSheet gibt falsche Daten (NIEDRIG)
**Beschreibung:** TaskFormSheet koennte Recurrence-Parameter nicht zurueckgeben.

**Beweis DAGEGEN:** TaskFormSheet gibt `recPat, recWeek, recMonth, recInterval` zurueck — CoachBacklogView IGNORIERT sie im onSave-Callback (Zeile 85).

**Wahrscheinlichkeit:** NIEDRIG

---

## Root Cause

**Feature-Luecke (Hypothese 1):** CoachBacklogView fehlen 3 Dinge:

1. **State-Variablen** fuer Recurring-Dialoge (`taskToDeleteRecurring`, `taskToEditRecurring`, `editSeriesMode`)
2. **Confirmation-Dialoge** (.confirmationDialog fuer Delete + Edit)
3. **Recurring-Check** in `deleteTask()` und Edit-Flow

Die Service-Schicht (SyncEngine) ist vollstaendig — nur die View-Integration fehlt.

---

## Blast Radius

| Bereich | Betroffen? |
|---------|-----------|
| iOS CoachBacklogView | JA — Hauptfix |
| macOS MacCoachBacklogView | JA — gleiches Problem (FEATURE_013) |
| iOS BacklogView | NEIN — hat Dialoge |
| macOS ContentView | NEIN — hat Dialoge |
| SyncEngine | NEIN — Methoden existieren |
| Andere Views | NextUpSection sicher (Delegation), FocusBlockTasksSheet niedrige Prio |

---

## Challenger-Korrekturen (Devil's Advocate)

1. **"Datenverlust" praezisiert:** Kein Serien-Verlust — `deleteTask()` loescht immer nur EINE Instanz. Problem ist fehlende Wahlmoeglichkeit, nicht Datenverlust im engeren Sinne.
2. **macOS ist SCHLIMMER:** `MacCoachBacklogView` nutzt `modelContext.delete()` direkt — ohne SyncEngine, ohne `freeDependents()`, ohne Notification-Cleanup. Schwerer fehlerhaft als iOS.
3. **3 Dialoge noetig, nicht 2:** BacklogView hat Delete-Dialog, Edit-Dialog UND "Serie beenden"-Dialog (`taskToEndSeries`). Alle 3 muessen portiert werden.
4. **Separater Code-Pfad:** `onDelete` im TaskFormSheet (CoachBacklogView:87) ruft `deleteTask()` direkt auf — muss AUCH den Recurring-Check bekommen.

## Scope-Entscheidung

**FEATURE_001 = NUR iOS CoachBacklogView** (laut Ticket-Beschreibung).
**macOS MacCoachBacklogView = FEATURE_013** (separates Ticket).

**Scope iOS-Fix:** ~100-120 LoC, 1 Datei (CoachBacklogView.swift). Pattern aus BacklogView uebernehmen:
- 3 State-Variablen + 3 Confirmation-Dialoge + Recurring-Check in `deleteTask()` + Edit-Flow
- Methoden `deleteSingleTask()`, `deleteRecurringSeries()`, `updateRecurringSeries()` hinzufuegen (nutzen bestehende SyncEngine-Methoden)
