# macOS Spec Backlog

> Erstellt: 2026-01-31
> Basis: `docs/project/stories/timebox-macos.md`
> Status: In Progress
> Letzte Aktualisierung: 2026-01-31

## Übersicht

Dieses Backlog enthält alle Specs für die macOS App, abgeleitet aus der User Story.

**Architektur-Entscheidung:** Native SwiftUI macOS App mit Shared Core (Models, Services).

## Priorisierung

| Priorität | Bedeutung |
|-----------|-----------|
| P0 | Fundament - ohne das geht nichts |
| P1 | Must Have - Kern-Features |
| P2 | Should Have - wichtige Erweiterungen |
| P3 | Could Have - Nice-to-have |

---

## P0: Fundament

### MAC-001: macOS App Foundation
**Status:** ✅ Done (2026-01-31)
**Beschreibung:** Grundgerüst der macOS App mit Shared Core Integration.

**Scope:**
- Neues macOS Target in Xcode
- Shared Core einbinden (Models, Services, SwiftData)
- App Lifecycle (AppDelegate/App)
- Basis-Navigation (Sidebar + Content)
- iCloud Sync Verifizierung

**Abhängigkeiten:** Keine
**Geschätzte Komplexität:** L

---

### MAC-002: Cross-Platform Sync
**Status:** Pending (App Group configured, needs real-device verification)
**Beschreibung:** Sicherstellen, dass Änderungen sofort zwischen iOS und macOS synchen.

**Scope:**
- SwiftData CloudKit Integration testen
- Conflict Resolution Strategy
- Sync Status Indicator
- Offline-Handling

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** M

---

## P1: Must Have

### MAC-010: Menu Bar Widget
**Status:** ✅ Done (2026-01-31)
**Beschreibung:** Persistentes Menü-Bar Icon mit Timer und aktueller Aufgabe.

**Scope:**
- MenuBarExtra mit SwiftUI
- Timer-Anzeige (Countdown oder Fortschritt)
- Aktuelle Aufgabe anzeigen
- Click → Popover mit Quick Actions
- Option-Click → Haupt-App öffnen

**Akzeptanzkriterien:**
- [ ] Icon zeigt Timer-Status (idle/running)
- [ ] Popover zeigt aktuelle Aufgabe + Zeit
- [ ] Start/Pause/Stop direkt im Popover
- [ ] Nächste Aufgabe sichtbar

**Abhängigkeiten:** MAC-001, MAC-002
**Geschätzte Komplexität:** M

---

### MAC-011: Globaler Quick Capture
**Status:** ✅ Done (2026-01-31)
**Beschreibung:** Systemweiter Hotkey öffnet schnelles Eingabefeld.

**Scope:**
- Globaler Keyboard Shortcut (z.B. ⌘⇧Space)
- Floating Panel (wie Spotlight)
- Aufgabe tippen → Enter → Panel schließt
- Optional: Kategorie/Dauer direkt setzen

**Akzeptanzkriterien:**
- [ ] Hotkey funktioniert aus jeder App
- [ ] Panel erscheint zentriert
- [ ] Enter speichert und schließt
- [ ] Escape schließt ohne Speichern
- [ ] Aufgabe erscheint sofort im Backlog

**Abhängigkeiten:** MAC-001, MAC-002
**Geschätzte Komplexität:** M

---

### MAC-012: Keyboard Navigation
**Status:** ✅ Done (2026-01-31)
**Beschreibung:** Komplette App-Bedienung ohne Maus möglich.

**Scope:**
- Focus Ring für alle interaktiven Elemente
- Tab-Navigation durch Listen
- Shortcuts für häufige Aktionen:
  - ⌘N: Neue Aufgabe
  - ⌘D: Aufgabe erledigen
  - ⌘E: Aufgabe bearbeiten
  - Space: Timer starten/pausieren
  - ⌘1-5: Sidebar-Navigation
- Shortcut-Übersicht (⌘?)

**Akzeptanzkriterien:**
- [ ] Alle Aktionen per Keyboard erreichbar
- [ ] Sichtbarer Focus-Indicator
- [ ] Shortcuts in Menü dokumentiert
- [ ] ⌘? zeigt Shortcut-Übersicht

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** M

---

### MAC-013: Main Window - Backlog View
**Status:** ✅ Done (2026-01-31)
**Beschreibung:** Backlog-Ansicht optimiert für großen Bildschirm.

**Scope:**
- Sidebar mit Kategorien-Filter
- Hauptbereich: Aufgabenliste
- Detail-Panel (Inspector) rechts
- Sortierung/Filterung
- Multi-Selection

**Akzeptanzkriterien:**
- [ ] Drei-Spalten-Layout
- [ ] Kategorien in Sidebar filterbar
- [ ] Multi-Select mit ⌘-Click
- [ ] Bulk-Aktionen (Kategorie setzen, löschen)

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** M

---

### MAC-014: Main Window - Planning View
**Status:** ✅ Done (2026-01-31)
**Beschreibung:** Tagesplanung mit Kalender-Integration.

**Scope:**
- Kalender-Ansicht mit Terminen (readonly)
- Freie Blöcke hervorgehoben
- Aufgaben-Liste daneben
- Drag & Drop: Aufgabe → Block

**Akzeptanzkriterien:**
- [ ] Kalender zeigt heutige Termine
- [ ] Freie Blöcke visuell erkennbar
- [ ] Drag & Drop funktioniert
- [ ] Aufgabe in Block → Focus Block erstellt

**Abhängigkeiten:** MAC-001, MAC-013
**Geschätzte Komplexität:** L

---

## P2: Should Have

### MAC-020: Drag & Drop Planung
**Status:** Not Started
**Beschreibung:** Intuitive Drag & Drop Interaktion für Planung.

**Scope:**
- Aufgaben aus Backlog in Kalender ziehen
- Aufgaben zwischen Blöcken verschieben
- Aufgaben-Reihenfolge in Blöcken ändern
- Visual Feedback während Drag

**Abhängigkeiten:** MAC-014
**Geschätzte Komplexität:** M

---

### MAC-021: Review Dashboard
**Status:** Not Started
**Beschreibung:** Statistik-Übersicht für Tages-/Wochen-Review.

**Scope:**
- Tagesansicht: erledigte Aufgaben, Fokuszeit
- Wochenansicht: Trends, Kategorien-Verteilung
- Charts (SwiftUI Charts)
- Export-Option (optional)

**Akzeptanzkriterien:**
- [ ] Tages-Summary mit Metriken
- [ ] Wochen-Chart zeigt Fokuszeit pro Tag
- [ ] Kategorien-Pie-Chart
- [ ] Vergleich zur Vorwoche

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** L

---

### MAC-022: Spotlight Integration
**Status:** Not Started
**Beschreibung:** Aufgaben über macOS Spotlight erfassen.

**Scope:**
- Core Spotlight Integration
- Intents für Shortcuts
- "Add Task" Intent

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** S

---

## P3: Could Have

### MAC-030: Shortcuts.app Integration
**Status:** Not Started
**Beschreibung:** App Intents für Automationen.

**Scope:**
- "Start Focus Block" Intent
- "Add Task" Intent
- "Get Current Task" Intent
- "Complete Current Task" Intent

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** M

---

### MAC-031: Focus Mode Integration
**Status:** Not Started
**Beschreibung:** Timer startet automatisch Focus Mode.

**Scope:**
- FocusFilter Integration
- Bei Block-Start → Focus Mode aktivieren
- Bei Block-Ende → Focus Mode deaktivieren
- Konfigurierbar pro Kategorie

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** M

---

### MAC-032: Notification Center Widget
**Status:** Not Started
**Beschreibung:** Widget im Notification Center.

**Scope:**
- WidgetKit für macOS
- Kleine Ansicht: Timer + Aufgabe
- Medium: + nächste Aufgaben

**Abhängigkeiten:** MAC-001
**Geschätzte Komplexität:** S

---

## Implementierungs-Reihenfolge (Empfehlung)

```
Phase 1: Fundament
├── MAC-001: App Foundation
└── MAC-002: Cross-Platform Sync

Phase 2: Kern-Interaktion
├── MAC-010: Menu Bar Widget
├── MAC-011: Globaler Quick Capture
└── MAC-012: Keyboard Navigation

Phase 3: Hauptfenster
├── MAC-013: Backlog View
└── MAC-014: Planning View

Phase 4: Erweiterungen
├── MAC-020: Drag & Drop
├── MAC-021: Review Dashboard
└── MAC-022: Spotlight Integration

Phase 5: Nice-to-have
├── MAC-030: Shortcuts.app
├── MAC-031: Focus Mode
└── MAC-032: NC Widget
```

---

## Shared Code (bereits vorhanden)

Diese Komponenten aus iOS können 1:1 wiederverwendet werden:

| Komponente | Pfad | Anpassung nötig |
|------------|------|-----------------|
| LocalTask Model | `Sources/Models/LocalTask.swift` | Nein |
| PlanItem Model | `Sources/Models/PlanItem.swift` | Nein |
| FocusBlock Model | `Sources/Models/FocusBlock.swift` | Nein |
| SyncEngine | `Sources/Services/SyncEngine.swift` | Nein |
| LocalTaskSource | `Sources/Services/TaskSources/` | Nein |
| RemindersSyncService | `Sources/Services/RemindersSyncService.swift` | Nein |
| Kategorien | `Sources/Models/Category.swift` | Nein |

---

*Generiert aus User Story am 2026-01-31*
