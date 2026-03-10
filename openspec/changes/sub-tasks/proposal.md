# Proposal: Task-Abhängigkeiten (Blocker)

**Status:** Spec fertig — wartet auf Approval
**Datum:** 2026-03-10
**Modus:** NEU

---

## Was

Tasks koennen eine Abhaengigkeit von einem anderen Task bekommen ("blockiert durch").
Der blockierende Task (Blocker) muss zuerst erledigt werden, bevor abhaengige Tasks
bearbeitet werden koennen. Blocker-Tasks erhalten einen Ranking-Bonus, weil sie andere
Tasks freischalten.

**Wichtig:** Es geht NICHT um Sub-Tasks/Hierarchie, sondern um Finish-to-Start-Abhaengigkeiten.

## Warum

Manche Tasks setzen die Erledigung anderer Tasks voraus. Beispiel:
- "API implementieren" haengt ab von "API Design"
- "Wohnung einrichten" haengt ab von "Umzug"

Ohne Abhaengigkeiten liegen beide Tasks gleichberechtigt im Backlog.
Mit Abhaengigkeiten wird der Blocker priorisiert und die abhaengigen Tasks
visuell als "noch nicht dran" markiert.

---

## Verhalten

### Darstellung
- Abhaengige Tasks erscheinen **eingerueckt + dimmed** unter ihrem Blocker
- Einrueckung zeigt: "gehoert zu diesem Blocker"
- Dimming zeigt: "noch nicht bearbeitbar"

### Interaktion
- Abhaengige Tasks koennen **NICHT** abgehakt werden (Checkbox deaktiviert)
- Abhaengige Tasks koennen **NICHT** zu Next Up hinzugefuegt werden
- Abhaengige Tasks koennen **NICHT** einem FocusBlock zugeordnet werden
- Abhaengige Tasks **koennen** bearbeitet werden (Edit-Dialog)
- Abhaengigkeit kann im Edit-Dialog entfernt werden

### Blocker erledigt
- Wenn Blocker abgehakt wird: abhaengige Tasks ruecken auf **Top-Level** hoch
- Sie werden sofort bearbeitbar (nicht mehr dimmed)
- Sie koennen ab jetzt zu Next Up, FocusBlocks etc.

### Blocker geloescht
- Wenn Blocker geloescht wird: abhaengige Tasks werden automatisch frei (Top-Level)

### Ranking
- Blocker-Tasks bekommen einen Score-Bonus im `TaskPriorityScoringService`
- Bonus: **+3 pro abhaengigem Task**, max **+9** (3 Tasks)
- Grund: Sie schalten andere Arbeit frei, sind daher wichtiger

---

## Regeln

| Regel | Detail |
|-------|--------|
| Max 1 Blocker pro Task | Ein Task kann nur von EINEM anderen abhaengen |
| Max 1 Ebene | Ein blockierter Task kann nicht selbst Blocker sein |
| Keine Zirkel | Durch 1-Ebene-Regel automatisch verhindert |
| Recurring Tasks | Koennen Blocker sein (aktuelle Instanz) |
| Erstellung | Im Bearbeitungs-Dialog (TaskFormSheet): "Abhaengig von..." |

---

## Scope

### Phase 1 — Daten-Layer + iOS (5 Dateien, ~120 LoC)

| Datei | Aenderung |
|-------|-----------|
| `Sources/Models/LocalTask.swift` | +`blockerTaskID: String?` Property |
| `Sources/Models/PlanItem.swift` | +`blockerTaskID: String?`, Init-Uebernahme, +`isBlocked` computed |
| `Sources/Services/TaskPriorityScoringService.swift` | +`dependentTaskCount` Parameter, +Blocker-Bonus |
| `Sources/Views/BacklogView.swift` | Grouping: blockierte Tasks unter Blocker anzeigen, dimmed |
| `Sources/Views/BacklogRow.swift` | +`isBlocked: Bool` Parameter → Einrueckung + Opacity |

### Phase 2 — macOS (2 Dateien, ~60 LoC)

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/ContentView.swift` | Grouping analog zu iOS |
| `FocusBloxMac/MacBacklogRow.swift` | +`isBlocked: Bool` → Einrueckung + Opacity |

### Phase 3 — Erstellungs-UI (1-2 Dateien, ~50 LoC)

| Datei | Aenderung |
|-------|-----------|
| `Sources/Views/TaskFormSheet.swift` | "Abhaengig von..." Picker |

---

## Technische Entscheidungen

**`blockerTaskID: String?` statt SwiftData @Relationship:**
- Einfache optionale String-Property auf `LocalTask`
- CloudKit-kompatibel (optionale Felder = automatische Migration)
- Vermeidet SwiftData-Relationship-Bugs
- String-basiert weil `LocalTask.id` = UUID-String

**Scoring-Bonus fuer Blocker-Tasks:**
- Neuer Parameter `dependentTaskCount: Int` in `calculateScore()`
- Bonus: +3 pro abhaengigem Task, max +9
- Passt ins bestehende 0-100 Score-System

**Grouping in BacklogView:**
- Blockierte Tasks aus der normalen Liste filtern
- Nach jedem Blocker-Task: seine blockierten Tasks eingerueckt einfuegen
- Blockierte Tasks: 24pt Leading-Padding + 0.5 Opacity
- Checkbox deaktiviert (`.disabled(true)`)

**1-Ebene-Enforcement:**
- Im TaskFormSheet: "Abhaengig von..." Picker zeigt NUR Tasks die selbst keinen Blocker haben
- Und NUR Tasks die NICHT bereits blockiert sind durch den aktuellen Task
- → Zirkel und Multi-Level automatisch verhindert

---

## Edge Cases

| Situation | Verhalten |
|-----------|-----------|
| User versucht blockierten Task zu Next Up hinzuzufuegen | Swipe-Action nicht vorhanden / deaktiviert |
| User versucht blockierten Task abzuhaken | Checkbox disabled |
| Blocker wird geloescht | Abhaengige Tasks werden frei |
| Blocker wird selbst blockiert (Multi-Level-Versuch) | Im Picker nicht auswaehlbar |
| Filter aktiv (Kategorie/Ueberfaellig) | Blockierte Tasks werden mitgefiltert |
| Suche aktiv | Blockierte Tasks erscheinen nur wenn Blocker oder sie selbst matchen |

---

## Was explizit NICHT im MVP

- Mehrere Blocker pro Task
- Multi-Level-Abhaengigkeiten (Ketten)
- Abhaengigkeiten in Focus/Planning/Review Views
- Fortschritts-Badge auf Blocker-Tasks
- Blockierte Tasks kollabieren/ausblenden
- Gantt-artige Visualisierung
