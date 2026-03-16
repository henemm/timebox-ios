# Bug-Analyse: Doppelte Eintraege im Coach-Backlog + Zehnagel-Zombie

**Datum:** 2026-03-16
**Backlog-IDs:** BUG_107 (Duplikate), BUG_108 (Zehnagel)
**Status:** Analyse abgeschlossen, Fix ausstehend

---

## BUG_107: Doppelte Eintraege im Coach-Backlog

### Symptom

Im Coach-Backlog (iOS + macOS) erscheinen Tasks doppelt:
- Einmal ausgegraut mit Lock-Icon (blocked Dependent)
- Einmal aktiv mit Checkbox (eigenstaendiger Tier-Eintrag)

Betroffene Tasks im Screenshot: "Hoch-/Fruehbeet bauen", "Kompost umsetzen", "Haenger leihen/Kompost holen" — alle mit identischen Scores (23) und Metadaten.

### Root Cause (BESTAETIGT)

`CoachBacklogViewModel` (`Sources/ViewModels/CoachBacklogViewModel.swift`) filtert NIRGENDWO nach `blockerTaskID`.

**Vergleich:**
- iOS `BacklogView.backlogTasks` (Zeile 117): `allBacklogTasks.topLevelTasks` → filtert `blockerTaskID == nil` ✓
- macOS `ContentView.regularFilteredTasks` (Zeile 303): `$0.blockerTaskID == nil` ✓
- `CoachBacklogViewModel.remainingTasks()` (Zeile 60): **KEIN** Filter auf blockerTaskID ✗
- `CoachBacklogViewModel.nextUpTasks()` (Zeile 20): **KEIN** Filter auf isBlocked ✗

**Mechanismus:**
1. Task B hat `blockerTaskID = A.id` (ist blocked by A)
2. `remainingTasks()` laesst B durch → B erscheint in Tier-Section als normaler Task (Checkbox)
3. Unter Task A rendert `blockedTasks(for: A.id)` auch B als Dependent (Lock-Icon, grau)
4. Ergebnis: B erscheint zweimal

### Fix-Ansatz

**Datei:** `Sources/ViewModels/CoachBacklogViewModel.swift`

**Aenderungen (4 Stellen):**

1. `remainingTasks()` Zeile 60 — zusaetzlich `&& $0.blockerTaskID == nil`:
```swift
return tasks.filter {
    !$0.isCompleted && !$0.isTemplate &&
    !nextUpIDs.contains($0.id) && !boostIDs.contains($0.id) &&
    $0.blockerTaskID == nil  // NEU
}
```

2. `nextUpTasks()` Zeile 20 — zusaetzlich `&& !$0.isBlocked`:
```swift
tasks.filter { $0.isNextUp && !$0.isCompleted && !$0.isTemplate && !$0.isBlocked }
```

3. `recentTasks()` Zeile 88 — zusaetzlich `&& $0.blockerTaskID == nil`:
```swift
tasks.filter { !$0.isCompleted && !$0.isTemplate && $0.blockerTaskID == nil }
```

4. `overdueTasks()` Zeile 69 — zusaetzlich `&& $0.blockerTaskID == nil`:
```swift
tasks.filter { !$0.isCompleted && !$0.isTemplate && $0.blockerTaskID == nil }
```

**Call-Sites (NICHT Dead Code):**
- iOS: `CoachBacklogView.swift` Zeile 39-52
- macOS: `MacCoachBacklogView.swift` Zeile 52-73

**Blast Radius:**
- Betroffen: Coach-Views auf BEIDEN Plattformen
- NICHT betroffen: Normaler Backlog (hat eigene korrekte Filterung)
- Blocked Tasks verschwinden NICHT — sie werden weiterhin als Dependencies unter ihrem Blocker angezeigt

### Aufwand: S (1 Datei, ~4 Zeilen)

---

## BUG_108: Zehnagel-Zombie — Recurring Task ueberlebt Serien-Ende

### Symptom

User beendet die Zehnagel-Serie wiederholt ("Serie beenden" Dialog). Task verschwindet kurz, taucht aber nach App-Neustart wieder auf.

### Root Cause (HYPOTHESE — hohe Wahrscheinlichkeit)

**Alte GroupID-Fragmente ueberleben die Dedup/Serie-beenden-Kette.**

Historisch hatte "Zehnagel" 4 verschiedene `recurrenceGroupID`-Werte (dokumentiert in `TemplateDedupTests.swift` Zeile 26-32). Entstanden durch 3 unabhaengige Code-Pfade die jeweils neue GroupIDs erzeugten:

| Pfad | Datei | Trigger |
|------|-------|---------|
| Lazy Migration | RecurrenceService:98 | Completion ohne GroupID |
| Repair Fallback | RecurrenceService:410 | `task.recurrenceGroupID ?? task.id` |
| Template Migration | RecurrenceService:201 | App-Start fuer Tasks ohne GroupID |

**Zombie-Mechanismus:**
1. `deduplicateTemplates()` konsolidiert Templates nach Titel → 4 Templates → 1 Survivor
2. Completed Tasks mit ALTEN GroupIDs werden reassigned (Zeile in dedup)
3. User beendet Serie → loescht Survivor-Template + offene Tasks
4. **ABER:** Wenn ein completed Task mit einer GroupID existiert die NICHT reassigned wurde (z.B. `task.id` als Fallback-GroupID), dann:
   - `repairOrphanedRecurringSeries()` findet diesen completed Task
   - Sucht Template fuer diese spezifische GroupID
   - Wenn `migrateToTemplateModel()` vorher ein Template dafuer erstellt hat → Repair erzeugt neue Instanz
   - Zehnagel ist zurueck

**Kritische Stelle — Repair-Fallback (Zeile 410):**
```swift
let groupID = task.recurrenceGroupID ?? task.id
```
Wenn `recurrenceGroupID == nil` → nutzt `task.id` als GroupID. Diese ID wird NIRGENDS von der Dedup erfasst (dedup gruppiert nach Titel, nicht nach ID).

### Fix-Ansatz

**Option A (minimal):** `repairOrphanedRecurringSeries()` soll VOR dem Repair pruefen ob IRGENDEIN Template fuer denselben TITEL existiert — nicht nur fuer die spezifische GroupID.

**Option B (gruendlich):** Beim "Serie beenden" ALLE completed Tasks derselben Serie (`title + recurrencePattern`) markieren (z.B. `recurrencePattern = "none"` setzen), damit Repair sie nie wieder aufgreift.

**Option C (defensiv):** Kombination — Repair checkt Titel UND Serie-beenden neutralisiert alte Completed Tasks.

**Empfehlung:** Option C — adressiert sowohl das Symptom (Repair) als auch die Ursache (orphaned completed Tasks).

### Aufwand: S-M (2-3 Dateien, RecurrenceService + SyncEngine)

### Debugging zur Bestaetigung

Falls gewuenscht, vor dem Fix:
- Logging in `repairOrphanedRecurringSeries()`: "Repairing series [groupID] from completed task [title]"
- App starten → wenn Log "Repairing... Zehnagel" zeigt → Hypothese bestaetigt

---

## Blast Radius (beide Bugs)

| Bereich | BUG_107 (Duplikate) | BUG_108 (Zehnagel) |
|---------|--------------------|--------------------|
| iOS Coach-Backlog | ✅ Betroffen | ✅ Betroffen |
| macOS Coach-Backlog | ✅ Betroffen | ✅ Betroffen |
| iOS normaler Backlog | ❌ Hat eigenen Filter | ✅ Betroffen |
| macOS normaler Backlog | ❌ Hat eigenen Filter | ✅ Betroffen |
| Andere recurring Tasks | ❌ | ✅ ALLE Serien betroffen |

---

## Referenzen

- Zehnagel-Zombie alte Analyse: `docs/artifacts/bug-zehnagel-resurrection/analysis.md`
- Template-Dedup alte Analyse: `docs/artifacts/bug-wiederkehrend-duplicates/analysis.md`
- Zehnagel-Fix Commit: `b8af930` (Template-Check in Repair)
- Template-Dedup Fix: `5c4c0c2` (Titel-basierte Konsolidierung)
