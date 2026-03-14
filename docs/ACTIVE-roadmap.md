# ACTIVE Roadmap

> Zentraler Einstiegspunkt fuer alle geplanten Features.
> Features werden hier zuerst eingetragen, bevor eine OpenSpec erstellt wird.

---

### Monster Coach Phase 3a — Intention-basierter Backlog-Filter

**Status:** Geplant
**Prioritaet:** Hoch
**Kategorie:** Support Feature
**Aufwand:** Mittel

**Kurzbeschreibung:**
Nach der Morgen-Intention-Auswahl wechselt die App automatisch zum Backlog-Tab und zeigt aktive Filter-Chips passend zur gewaehlten Intention. Der User sieht sofort die relevanten Tasks und kann diese als NextUp markieren. Die Filter sind einzeln abschaltbar.

**Betroffene Systeme:**
- `Sources/Models/DailyIntention.swift` (neue `backlogFilter(for:)` Logik)
- `Sources/Views/MorningIntentionView.swift` (Tab-Wechsel nach Intention-Setzen)
- `Sources/Views/BacklogView.swift` (IntentionFilter-Chips + gefilterte Task-Listen)
- `Sources/FocusBloxApp.swift` (AppStorage-Key fuer aktive Intention-Filter)

**Filter-Mapping:**
| Intention | Filter-Verhalten |
|-----------|-----------------|
| Survival | Kein Filter — alle Tasks sichtbar |
| Fokus | Nur NextUp-Tasks |
| BHAG | importance == 3 ODER rescheduleCount >= 2 |
| Balance | Alle Tasks, gruppiert nach Kategorie |
| Growth | taskType == "learning" |
| Connection | taskType == "giving_back" |

**Multi-Select-Regeln:**
- Survival ueberstimmt alles — kein Filter wenn Survival dabei
- Mehrere andere: Vereinigung (ODER-Logik, Task reicht in einer Gruppe zu stecken)

**OpenSpec:** `openspec/changes/monster-coach-phase3a/`

---

### Monster Coach Phase 3b — Smart Notifications (Tagesbegleitung)

**Status:** Geplant
**Prioritaet:** Hoch
**Kategorie:** Support Feature
**Aufwand:** Mittel

**Kurzbeschreibung:**
Notifications feuern NUR wenn die Morgen-Intention nicht gelebt wird (Luecke zwischen Absicht und Handlung). Survival = absolute Ruhe. Sobald Intention erfuellt → alle Nudges gecancelt (Stille-Regel). Settings: An/Aus, Max pro Tag (1/2/3), Zeitfenster Von/Bis.

**Betroffene Systeme:**
- `Sources/Services/IntentionEvaluationService.swift` (NEU — prueft ob Intention erfuellt, erkennt Gap)
- `Sources/Services/NotificationService.swift` (neuer MARK-Block Coach Daily Nudges)
- `Sources/Models/AppSettings.swift` (4 neue Properties: nudgesEnabled, maxCount, windowStart, windowEnd)
- `Sources/Views/SettingsView.swift` (neue Controls in Monster Coach Section)
- `Sources/Views/MorningIntentionView.swift` (Nudge-Scheduling nach Intention-Setzen)
- `Sources/FocusBloxApp.swift` (Foreground-Check → cancel wenn erfuellt)

**Luecken-Logik:**

| Intention | Notification wenn... |
|-----------|---------------------|
| Survival | Niemals — absolute Ruhe |
| BHAG | Kein Block mit BHAG-Task ODER nachmittags BHAG noch unerledigt |
| Fokus | Kein Focus Block geplant ODER Tasks ausserhalb von Blocks erledigt |
| Balance | Nur 1-2 Kategorien aktiv (nachmittags) |
| Growth | Kein "Lernen"-Task erledigt |
| Connection | Kein "Geben"-Task erledigt |

**Stille-Regel:** App-Foreground prueft Erfuellung → wenn ja, alle Nudges canceln.

**OpenSpec:** `openspec/changes/monster-coach-phase3b/`

---

### Monster Coach Phase 4e — Monster in Push-Notifications

**Status:** Geplant
**Prioritaet:** Niedrig
**Kategorie:** Support Feature
**Aufwand:** Klein

**Kurzbeschreibung:**
Die drei Coach-Notification-Typen (Morgen-Erinnerung, Abend-Erinnerung, Tages-Nudges) erhalten das passende Monster-Bild als Rich Notification Attachment. Welches Monster erscheint haengt von der gesetzten Morgen-Intention ab (via bestehendes `IntentionOption.monsterDiscipline`-Mapping).

**Betroffene Systeme:**
- `Sources/Services/NotificationService.swift` (neue Hilfsfunktion `buildMonsterAttachment` + Erweiterung von 3 Buildern)
- `Sources/Views/MorningIntentionView.swift` (Intention an `scheduleIntentionReminder` uebergeben)
- `Sources/FocusBloxApp.swift` (Intention an `scheduleEveningReminder` uebergeben)

**OpenSpec:** `openspec/changes/monster-coach-phase4e/`

---

### Sub-Tasks

**Status:** Geplant
**Prioritaet:** Mittel
**Kategorie:** Primary Feature
**Aufwand:** Gross (2 Phasen)

**Kurzbeschreibung:**
Tasks koennen Sub-Tasks bekommen. Parent-Tasks werden durch Sub-Tasks hoeher gerankt. Sub-Tasks erscheinen eingerueckt unterhalb des uebergeordneten Tasks im Backlog.

**Betroffene Systeme:**
- `Sources/Models/LocalTask.swift` (neue Property `parentTaskID`)
- `Sources/Models/PlanItem.swift` (Property-Uebernahme)
- `Sources/Services/TaskPriorityScoringService.swift` (Scoring-Bonus fuer Parents)
- `Sources/Views/BacklogView.swift` (Grouping-Logik iOS)
- `Sources/Views/BacklogRow.swift` (visuelles Indent iOS)
- `FocusBloxMac/ContentView.swift` (Grouping-Logik macOS) — Phase 2
- `FocusBloxMac/MacBacklogRow.swift` (visuelles Indent macOS) — Phase 2

**OpenSpec:** `openspec/changes/sub-tasks/` (ausstehend)

**Offene Fragen:**
- Wie erstellt der User einen Sub-Task? (Swipe-Action / Long-Press / Bearbeitungs-Dialog)
- Maximale Tiefe: 1 Ebene oder mehr?
- Was passiert wenn Parent erledigt wird?
- Was passiert wenn Sub-Task zu Next Up hinzugefuegt wird?

---
