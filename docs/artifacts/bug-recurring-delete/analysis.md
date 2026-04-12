# Bug #209: Gelöschte Serienelemente erscheinen nach Neustart erneut

## Symptom
- User löscht ein fälliges Serienelement ("Nur diese Aufgabe")
- App hart beendet oder gewartet
- Das Element ist wieder da

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- **12 verwandte Bugs** in der Git-History gefunden
- BUG_108 ("Zehnagel-Zombie") ist der direkteste Vorläufer — gelöschte Serien erscheinen nach Neustart
- Mehrere Fixes implementiert (Commits b8af930, 0738f35), aber Problem besteht weiterhin
- Kernproblem: `repairOrphanedRecurringSeries()` kann gelöschte Instanzen wiederbeleben

### Agent 2 (Datenfluss-Trace)
- **Löschpfad:** BacklogView → deleteSingleTask() → SyncEngine.deleteTask() → modelContext.delete() + save()
- **Startup-Sequenz:** migrateToTemplateModel → deduplicateTemplates → deduplicateChildInstances → repairOrphanedRecurringSeries
- **Repair-Logik (RecurrenceService:426-473):** Wenn completed Tasks mit recurrencePattern existieren UND Template existiert UND keine offene Instanz → neue Instanz erzeugen

### Agent 3 (Alle Schreiber)
- 11 Code-Stellen schreiben/löschen/regenerieren Serien-Daten
- Kritischste: `repairOrphanedRecurringSeries()` (Zeile 466) erzeugt neue Instanzen
- `deleteRecurringSeries()` löscht OHNE freeDependents()
- FocusBlockActionService hat alternativen Completion-Pfad

### Agent 4 (Szenarien)
- **7 Trigger-Szenarien** identifiziert für Wiederkehr
- Höchste Priorität: App-Start Repair (Szenario 1)
- Zweite Priorität: Task-Completion erzeugt neue Instanz (Szenario 2)
- CloudKit-Sync könnte gelöschte Daten zurückbringen (Szenario 4)

### Agent 5 (Blast Radius)
- 6 Views zeigen Serien-Tasks an (iOS + macOS)
- macOS TaskInspector hat KEINEN Serien-Dialog
- deleteRecurringSeries() ruft freeDependents() NICHT auf
- Widget-Updates fehlen bei Serien-Löschung

---

## Hypothesen

### Hypothese 1: repairOrphanedRecurringSeries() regeneriert gelöschte Instanzen (HOCH)

**Beschreibung:** Wenn der User die letzte (oder einzige) offene Instanz einer Serie mit "Nur diese Aufgabe" löscht, hat die Serie:
- Kein offene Instanz mehr → `openGroupIDs` enthält die GroupID NICHT
- Ein Template existiert noch → `findTemplate()` findet es
- Completed Tasks mit `recurrencePattern != "none"` existieren → Repair-Quelle

→ Beim nächsten App-Start erzeugt `repairOrphanedRecurringSeries()` eine neue Instanz.

**Beweis DAFÜR:**
- Code in RecurrenceService.swift:455-468 — Logik passt exakt zum Symptom
- `deleteSingleTask()` löscht NUR die eine Instanz, berührt Template NICHT
- Template bleibt → Guard auf Zeile 464 wird NICHT getriggert
- Completed Tasks behalten `recurrencePattern` → Guard auf Zeile 433 wird NICHT getriggert

**Beweis DAGEGEN:**
- Der Guard `findTemplate() != nil` (Zeile 464) wurde als Fix für BUG_108 eingebaut
- Aber: BUG_108 war "Serie beenden" → Template wird gelöscht. Hier ist "Nur diese Aufgabe" → Template bleibt!
- Der Guard schützt nur gegen Wiederbeleben NACH Serienende, NICHT nach Einzellöschung

**Einschränkung:** Dieser Pfad greift NUR wenn bereits mindestens eine ABGESCHLOSSENE Instanz derselben Serie existiert. `repairOrphanedRecurringSeries()` iteriert über `recurringCompleted` — wenn der User die allererste Instanz einer neuen Serie löscht (noch nie eine abgeschlossen), findet Repair keine completed Tasks für diese GroupID und regeneriert NICHTS.

**Wahrscheinlichkeit: HOCH (90%) — sofern der User mindestens eine Instanz der Serie zuvor erledigt hat**

### Hypothese 2: CloudKit-Tombstone-Race (MITTEL)

**Beschreibung:** SwiftData mit CloudKit setzt bei `modelContext.delete()` intern einen Tombstone-Record. Wenn der Tombstone nicht korrekt zu iCloud synchronisiert wurde bevor die App beendet wird (Race zwischen `save()` und CloudKit-Upload), kann ein Neustart mit pending-Cloud-State die Task wiederherstellen. Das würde auch erklären warum der Bug intermittent auftritt und warum "warten" (nicht nur Neustart) als Trigger genannt wird.

**Beweis DAFÜR:**
- CloudKit-Sync ist asynchron — save() ist synchron lokal, aber Cloud-Upload kann verzögert sein
- Würde erklären warum normales (nicht-recurring) Löschen AUCH betroffen sein könnte, aber dort nicht bemerkt wird (keine Repair-Logik die es verschlimmert)
- `forceCloudKitFieldSync()` (FocusBloxApp.swift:341) touched alle Tasks beim Start → könnte gelöschte Tasks aus Cloud zurückholen

**Beweis DAGEGEN:**
- Bug ist reproduzierbar (laut Report), nicht intermittent → spricht gegen Race
- Normales Löschen funktioniert zuverlässig → CloudKit-Tombstones scheinen zu funktionieren

**Wahrscheinlichkeit: MITTEL (15%) — kann als sekundärer Verstärker wirken**

### Hypothese 3: deleteSingleTask() speichert nicht korrekt (SwiftData Race) (NIEDRIG)

**Beschreibung:** modelContext.save() nach delete könnte durch SwiftData-Autosave oder CloudKit-Sync überschrieben werden.

**Beweis DAFÜR:**
- SwiftData mit CloudKit hat bekannte Sync-Konflikte
- Expliziter save() könnte mit Cloud-Merge kollidieren

**Beweis DAGEGEN:**
- Normales (nicht-recurring) Löschen funktioniert zuverlässig
- save() wird synchron aufgerufen, direkt nach delete
- Kein Autosave konfiguriert

**Wahrscheinlichkeit: NIEDRIG (5%)**

### Hypothese 3: migrateToTemplateModel() erzeugt neues Template für orphaned Tasks (NIEDRIG)

**Beschreibung:** Beim App-Start könnte die Migration ein neues Template erstellen, wenn sie completed Tasks mit recurrencePattern findet.

**Beweis DAFÜR:**
- migrateToTemplateModel() sucht nach recurring Tasks ohne Template und erstellt Templates
- Läuft VOR repair → könnte ein neues Template für eine "beendete" Serie erzeugen

**Beweis DAGEGEN:**
- Migration sucht nur `!$0.isCompleted` Tasks (Zeile ~170)
- Completed Tasks werden NICHT als Template-Quelle verwendet
- Bei "Nur diese Aufgabe" existiert das Template ohnehin bereits

**Wahrscheinlichkeit: NIEDRIG (5%)**

---

## Wahrscheinlichste Ursache

**Hypothese 1: repairOrphanedRecurringSeries()** regeneriert die gelöschte Instanz beim nächsten App-Start.

**Warum die anderen weniger wahrscheinlich sind:**
- H2: Normales Löschen funktioniert → kein generelles SwiftData-Problem
- H3: Migration betrachtet nur offene Tasks, nicht completed

### Debugging-Plan (zur Verifizierung)

**BESTÄTIGUNG:** Logging in `repairOrphanedRecurringSeries()` einbauen:
```swift
// Zeile 466: Vor createNextInstance()
print("[REPAIR] Repairing series \(groupID) from completed task: \(task.title)")
```
→ Wenn im Log nach App-Neustart die gelöschte Serie erscheint = Hypothese bestätigt.

**WIDERLEGUNG:** Wenn KEIN Log-Eintrag erscheint, aber Element trotzdem da ist → CloudKit-Sync oder anderer Pfad.

**Plattform:** iOS (laut Bug-Report)

---

## Blast Radius

- **iOS BacklogView:** Hauptbetroffen — hier löscht der User
- **macOS ContentView:** Gleiche Repair-Logik beim Start → AUCH betroffen
- **Alle Views mit Serien-Anzeige:** PlanningView, CoachView (indirekt)
- **deleteRecurringSeries():** Hat kein freeDependents() → kann dangling Blocker erzeugen (separater Bug)
- **Widget:** Keine Aktualisierung bei Serien-Löschung (separater Bug)

## Fix-Ansatz (Vorschlag)

Das Problem: `repairOrphanedRecurringSeries()` unterscheidet nicht zwischen:
- "Serie hat keine offene Instanz weil User sie ERLEDIGT hat" → Repair korrekt
- "Serie hat keine offene Instanz weil User sie GELÖSCHT hat" → Repair FALSCH

**Mögliche Lösung:** Beim Löschen einer einzelnen Serien-Instanz prüfen ob es die letzte offene war. Falls ja:
- Option A: Template auch löschen (Serie effektiv beenden) — aber User wollte nur DIESE Aufgabe löschen, nicht die Serie
- Option B: "Überspringen"-Markierung setzen (z.B. skipDates oder deletedDates auf Template) → Repair prüft diese Liste
- Option C: Statt Hard-Delete ein Soft-Delete (`isSkipped = true`) → Instanz bleibt in DB, wird aber nicht angezeigt, und Repair sieht sie als "offen"

**Hinweis:** Option C erfordert ein neues Schema-Feld `isSkipped` auf LocalTask — das existiert noch NICHT und würde eine SwiftData-Migration + Anpassung aller Queries brauchen. Option B erfordert ein `skipDates: [Date]` Array auf dem Template — konzeptionell sauberer und näher am bestehenden Datenmodell.

Empfehlung: **Option B** — skipDates auf Template. Beim Löschen einer einzelnen Instanz wird deren dueDate in die skipDates-Liste des Templates eingetragen. `repairOrphanedRecurringSeries()` und `createNextInstance()` prüfen diese Liste bevor sie eine Instanz erzeugen.

### Hennings Antwort: Element kommt wahrscheinlich auch OHNE Neustart zurück (nach Zeit im Hintergrund)

**Befund:** Beim Return aus dem Hintergrund (scenePhase → .active) wird `repairOrphanedRecurringSeries()` NICHT aufgerufen. ABER:
- `syncMonitor.triggerSync()` → `context.save()` triggert CloudKit-Sync (FocusBloxApp.swift:425)
- BacklogView hat `onChange(of: cloudKitMonitor.remoteChangeCount)` → `refreshLocalTasks()` (BacklogView.swift:357-366)
- Wenn CloudKit die Löschung nicht korrekt synchronisiert hat, kann ein Sync-Event die Task zurückbringen

**Zusammenfassung der zwei Trigger-Pfade:**
1. **Cold-Start:** `repairOrphanedRecurringSeries()` erzeugt neue Instanz (Hypothese 1, 90%)
2. **Background-Return:** CloudKit-Sync könnte gelöschte Task zurückholen (Hypothese 2, 15%)

Beide Pfade können unabhängig voneinander auftreten.

### Challenge-Verdict: LÜCKEN → eingearbeitet
