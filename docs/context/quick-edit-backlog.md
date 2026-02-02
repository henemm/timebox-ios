# Context: Quick Edit Tasks im Backlog

> Workflow: quick-edit-backlog
> Phase: Analysis
> Erstellt: 2026-01-27

## User Story

Siehe: `docs/project/stories/quick-edit-backlog.md`

**Kern:** Nutzer will im Backlog schnell Metadaten (Kategorie, Prioritaet, Wichtigkeit, Dauer) aendern - ohne den umstaendlichen 3-Schritt-Flow (Tap -> Detail-Sheet -> Bearbeiten-Button).

## Analysis

### Aktueller Flow (Problem)

```
BacklogView
  └─ Tap auf Task → $taskToEdit gesetzt
     └─ TaskDetailSheet oeffnet (read-only, halbes Sheet)
        └─ "Bearbeiten" Button in Toolbar
           └─ TaskFormSheet oeffnet (volles Edit-Formular)
              └─ onSave → zurueck zu BacklogView.updateTask()
```

**3 Interaktionen** bis zum Editieren + Kontextverlust im Backlog.

### Betroffene Dateien

| Datei | Aenderungstyp | Beschreibung |
|-------|---------------|--------------|
| `Sources/Views/BacklogView.swift` | MODIFY | Long-Press Context Menu + Inline-Popup Bindings hinzufuegen |
| `Sources/Views/BacklogRow.swift` | MODIFY | Context Menu + tappable Metadaten-Badges |
| `Sources/Views/InlinePickerPopup.swift` | CREATE | Wiederverwendbare Inline-Picker fuer Kategorie/Prioritaet/Urgency |
| `FocusBloxUITests/QuickEditBacklogUITests.swift` | CREATE | UI Tests |
| `FocusBloxTests/QuickEditBacklogTests.swift` | CREATE | Unit Tests |

### Scope Assessment

- **Dateien:** 3 Modify + 2 Create = 5 Dateien
- **Geschaetzter LoC:** +180 / -20
- **Risk Level:** LOW (keine Aenderung am Datenmodell, nur UI-Interaktion)

### Bestehende Patterns die wir nutzen koennen

1. **DurationPicker** (`Sources/Views/DurationPicker.swift`)
   - Bereits ein Inline-Popup-Pattern mit `.sheet()` + `.presentationDetents([.height(180)])`
   - Schnell-Auswahl-Buttons
   - Wird von BacklogRow ueber `onDurationTap` Callback ausgeloest
   - **Dieses Pattern fuer alle Inline-Picker uebernehmen**

2. **QuickPriorityButton** (in `TaskFormSheet.swift:108-117`)
   - 3 Buttons fuer Low/Medium/High
   - Farbcodiert
   - Kann als Vorlage fuer Inline-Prioritaet-Picker dienen

3. **TaskType Kategorien** (5 Lebensarbeit-Kategorien)
   - income, maintenance, recharge, learning, giving_back
   - Mit Icons und Labels

### Technischer Ansatz

**Zwei Interaktionswege:**

#### A) Long-Press Context Menu
- `.contextMenu` auf BacklogRow
- Schnellzugriff auf: Bearbeiten, Kategorie aendern, Prioritaet aendern, Loeschen
- SwiftUI-native, kein Custom-Code noetig
- Oeffnet direkt TaskFormSheet (ueberspringt TaskDetailSheet)

#### B) Inline-Editing Popups (Tappable Badges)
- Kategorie-Badge, Prioritaet-Badge, Dauer-Badge in der BacklogRow
- Tap auf Badge → kleines Sheet/Popup mit Auswahl
- Gleiches Pattern wie bestehender DurationPicker
- Nutzer bleibt visuell im Backlog

**Empfohlener Ansatz:** Beides implementieren.
- Long-Press fuer "alles bearbeiten" (oeffnet TaskFormSheet direkt)
- Inline-Taps fuer einzelne Eigenschaften (kleine Popups)

### Editierbare Properties

| Property | Typ | Moegliche Werte | Popup-Typ |
|----------|-----|-----------------|-----------|
| `importance` | Int? | 1 (Low), 2 (Medium), 3 (High) | 3-Button-Auswahl |
| `urgency` | String? | "not_urgent", "urgent" | 2-Button-Toggle |
| `taskType` | String | 5 Kategorien mit Icons | 5-Button-Auswahl |
| `estimatedDuration` | Int? | 5, 15, 30, 60 min | Bestehendes DurationPicker |

### Bestehende Infrastruktur

- `BacklogRow` hat bereits Callbacks: `onDurationTap`, `onAddToNextUp`, `onTap`
- `BacklogView.updateTask()` (L342-354) kann alle Properties speichern
- `SyncEngine` handled Persistenz
- `PlanItem` ist der Adapter zwischen View und Model

### Risiken

- **Gering:** Keine Aenderung am Datenmodell
- **Gering:** Context Menu ist SwiftUI-Standard
- **Beachten:** Inline-Popups muessen sich nicht gegenseitig ueberlappen (nur ein Popup gleichzeitig)

### Open Questions

Keine - Scope ist klar definiert.

---
*Analyse abgeschlossen am 2026-01-27*
