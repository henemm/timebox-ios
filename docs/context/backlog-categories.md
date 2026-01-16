# Context: Backlog Categories & Grouping

## Feature Request

Kategorien aus Apple Reminders in der Backlog-View sichtbar machen mit Gruppierungs- und Sortieroptionen.

## Analysis

### Current Data Flow
```
EKReminder → ReminderData → PlanItem → BacklogRow
```

**Problem:** Kategorie-Information (`EKReminder.calendar`) wird nicht durchgereicht.

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `ReminderData.swift` | MODIFY | + calendarTitle, calendarColor, dueDate |
| `EventKitRepository.swift` | MODIFY | Mapping um Calendar-Info erweitern |
| `PlanItem.swift` | MODIFY | + calendarTitle, calendarColor, dueDate |
| `BacklogRow.swift` | MODIFY | + Kategorie-Chip Darstellung |
| `BacklogView.swift` | MODIFY | + Gruppierung, Sortier-Menu |
| `BacklogGroupMode.swift` | CREATE | Enum fuer Gruppierungsmodus |

### Scope Assessment
- Files: 6
- Estimated LoC: +120/-10
- Risk Level: LOW (UI-Erweiterung, keine kritische Logik)

### Technical Approach

**1. Daten-Erweiterung:**
- `EKReminder.calendar.title` → Listenname
- `EKReminder.calendar.cgColor` → Farbe (als Color)
- `EKReminder.dueDateComponents` → Faelligkeit

**2. Gruppierungsmodi:**
- `none` - Flache Liste mit Kategorie-Chips
- `byCategory` - Sections nach Reminder-Liste
- `byDuration` - Sections: Kurz (<15min), Mittel (15-30min), Lang (>30min)
- `byDueDate` - Sections: Ueberfaellig, Heute, Diese Woche, Spaeter, Ohne Datum

**3. UI:**
- Menu/Picker in Toolbar fuer Gruppierungsmodus
- Persistierung via UserDefaults
- Kategorie-Chip: Farbiger Punkt + Text (wenn nicht gruppiert)

### Open Questions
- [x] Visuelle Darstellung? → Chips + Gruppierung
- [x] Scope? → Features 2+3 zusammen

### User Decisions
- Gruppierung nach Kategorie als Hauptmodus
- Chips-Darstellung wenn nicht gruppiert
- Switch fuer verschiedene Gruppierungsoptionen
