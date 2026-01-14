# Feature Backlog - TimeBox

## Offene Features (Priorisiert)

### 1. Kalender auswählbar machen (Settings)
**Status:** Offen
**Bereich:** Settings, EventKitRepository

**Anforderung:**
- User soll auswählen können, welcher Kalender für Focus Blocks verwendet wird
- Settings-View hinzufügen oder erweitern
- Aktuell wird `defaultCalendarForNewEvents` verwendet

**Offene Fragen:**
- Nur ein Kalender oder mehrere?
- Soll der Kalender pro Focus Block wählbar sein oder global?

---

### 2. Kategorien in Backlog-View sichtbar machen
**Status:** Offen
**Bereich:** BacklogView, Erinnerungen-Integration

**Anforderung:**
- Kategorien/Listen aus Apple Erinnerungen anzeigen
- Visuelle Unterscheidung der Tasks nach Kategorie (Farbe?)

**Offene Fragen:**
- Wie werden Kategorien visuell dargestellt? (Farbige Chips, Sections, Icons?)
- Gruppieren oder nur als Label anzeigen?

---

### 3. Sortierung nach Kategorie oder Zeit
**Status:** Offen
**Bereich:** BacklogView

**Anforderung:**
- Sortier-Optionen für Backlog:
  - Nach Kategorie/Liste
  - Nach Zeit (Fälligkeit?)
  - (Zukünftig weitere Optionen)

**Offene Fragen:**
- UI: Dropdown, Segmented Control, oder Menu?
- Aufsteigend/Absteigend wählbar?
- Persistieren der Sortierung?

---

### 4. Details von Erinnerungen auf Klick anzeigen
**Status:** Offen
**Bereich:** BacklogView, Detail-Sheet

**Anforderung:**
- Tap auf Task öffnet Detail-Ansicht
- Zeigt weitere Reminder-Infos:
  - Notes/Beschreibung
  - Fälligkeitsdatum
  - Priorität
  - Kategorie/Liste
  - Subtasks?

**Offene Fragen:**
- Modal Sheet oder Navigation Push?
- Editierbar oder nur Anzeige?

---

### 5. Zuordnen-View: Backlog-Bereich vergrößern
**Status:** Offen
**Bereich:** TaskAssignmentView

**Anforderung:**
- Aktuelles Problem: Backlog-Bereich zu klein
- Neuer Flow:
  1. **Schritt 1:** Welcher Focus Block soll befüllt werden? (Block auswählen)
  2. **Schritt 2:** Verfügbare Tasks anzeigen (größer, prominenter)

**Offene Fragen:**
- Zweistufiger Flow oder Split-View?
- Full-Screen Task-Auswahl nach Block-Selection?

---

### 6. Reihenfolge im Focus Block veränderbar
**Status:** Offen (Recherche nötig)
**Bereich:** TaskAssignmentView, FocusLiveView

**Anforderung:**
- Tasks innerhalb eines Focus Blocks umsortierbar
- Drag & Drop innerhalb des Blocks

**Recherche-Frage:**
> Was ist ein sinnvoller Default für die Task-Reihenfolge?

Mögliche Ansätze:
- **Eat the Frog:** Schwierigste/wichtigste Task zuerst
- **Quick Wins:** Kurze Tasks zuerst (Momentum aufbauen)
- **Priorität:** Nach Reminder-Priorität
- **Fälligkeit:** Dringendste zuerst
- **Energie-Level:** Kognitive Last berücksichtigen (morgens schwer, nachmittags leicht)

---

## Workflow-Hinweis

Jedes Feature wird einzeln nach dem OpenSpec Workflow bearbeitet:

1. `/context` - Context sammeln
2. `/analyse` - Detailanalyse
3. `/write-spec` - Spezifikation schreiben
4. User: "approved" - Freigabe
5. `/tdd-red` - Tests schreiben (wenn applicable)
6. `/implement` - Implementierung
7. `/validate` - Validierung

---

## Nächste Schritte

Bei Start eines Features:
```
/context [feature-name]
```

Beispiel:
```
/context calendar-selection
```
