# Bug-Analyse: Kategorie-Aenderung nicht sofort sichtbar (iOS)

## Symptom
Wenn die Kategorie einer Aufgabe im Quick-Edit (CategoryPicker) geaendert wird, zeigt die BacklogRow weiterhin die alte Kategorie an. Erst wenn die Aufgabe verschoben (drag) wird, erscheint die neue Kategorie.

## Plattform
iOS only. macOS ist NICHT betroffen (nutzt @Query + direkte Mutation).

---

## Agenten-Ergebnisse (5 parallele Investigationen)

### Agent 1: Wiederholungs-Check
- Kein bisheriger Fix fuer genau dieses Problem
- Verwandte Bugs: Bug 38 (SwiftData Refresh Timing), Bug 70d (Task-Jumping bei Property-Changes), Bug 79-80 (Category Labels)
- Keiner davon hat updateCategory() angefasst

### Agent 2: Datenfluss-Trace
- CategoryPicker → onSelect → BacklogView.updateCategory() → SyncEngine.updateTask() → modelContext.save()
- Datenbank wird korrekt aktualisiert
- planItems-Array wird NICHT aktualisiert → BacklogRow zeigt alten Wert

### Agent 3: Alle Schreiber
- Alle Category-Write-Sites haben korrekte save()-Aufrufe
- Kein fehlender Save, kein Threading-Problem

### Agent 4: Szenarien
- 95% Wahrscheinlichkeit: Fehlende planItems-Aktualisierung
- Andere Szenarien (ModelContext-Trennung, @Query-Refresh, Animation-Batching) ausgeschlossen

### Agent 5: Blast Radius
- NUR iOS betroffen (macOS nutzt @Query + direkte Mutation)
- Duration-Updates koennten dasselbe Problem haben (gleicher SyncEngine-Pfad)
- Keine abhaengigen Features betroffen (Filtering, Stats, Scoring arbeiten auf DB-Daten)

---

## Hypothesen

### H1: Fehlende planItems-Array-Aktualisierung (HOCH - 95%)

**Beweis DAFUER:**
- `updateImportance()` (Zeile 533-550): Fetch → Modify → Save → **planItems[index] = PlanItem(localTask: task)** → UI aktualisiert sofort
- `updateUrgency()` (Zeile 552-569): Identisches Muster → funktioniert
- `updateCategory()` (Zeile 571-581): SyncEngine.updateTask → Save → **KEIN planItems-Update** → UI zeigt alten Wert

**Beweis DAGEGEN:**
- Keiner. Der Code-Unterschied ist eindeutig.

**Warum Drag das Problem "loest":**
- Drag aendert sortOrder → DeferredSortController ruft `refreshLocalTasks()` auf → planItems wird komplett aus DB neu geladen → neue Kategorie erscheint

### H2: SyncEngine erstellt separaten ModelContext (NIEDRIG - 5%)

**Beweis DAFUER:**
- updateCategory erstellt neue LocalTaskSource + SyncEngine Instanzen
- Theoretisch koennte ein separater Context die Aenderung isolieren

**Beweis DAGEGEN:**
- SyncEngine bekommt denselben modelContext uebergeben (Zeile 574)
- save() auf demselben Context → Aenderung ist persistent
- Andere Funktionen (updateDuration) nutzen auch SyncEngine und funktionieren MIT planItems-Update

### H3: SwiftData @Model Change-Detection fehlt fuer Category (SEHR NIEDRIG - <1%)

**Beweis DAGEGEN:**
- iOS nutzt KEIN @Query fuer die BacklogView — es nutzt @State planItems (manuell verwaltet)
- SwiftData Change-Detection ist irrelevant wenn planItems manuell verwaltet wird

---

## Wahrscheinlichste Ursache: H1

`updateCategory()` fehlt die Zeile die planItems aktualisiert. Das ist ein Copy-Paste-Fehler: Die Funktion nutzt SyncEngine statt direktem Fetch+Modify wie die anderen Update-Funktionen, und dabei wurde vergessen das planItems-Array zu aktualisieren.

## Beweisplan (falls Henning Debugging will)

**Bestaetigung:** Logging in updateCategory nach SyncEngine-Aufruf: `print("planItems[\(item.id)].taskType = \(planItems.first { $0.id == item.id }?.taskType)")` — wuerde alten Wert zeigen.
**Widerlegung:** Wenn der Log den NEUEN Wert zeigt, ist H1 falsch und H2 waere zu pruefen.

## Blast Radius
- iOS BacklogView: Nur Category betroffen
- macOS: NICHT betroffen (anderes Update-Pattern)
- Duration-Updates: Moeglicherweise gleicher Bug (nutzt auch SyncEngine-Pfad ohne planItems-Update) — muss geprueft werden

## Fix-Vorschlag (5 LoC)

`updateCategory()` analog zu `updateImportance()` umschreiben:
1. LocalTask per FetchDescriptor holen
2. task.taskType setzen
3. modelContext.save()
4. **planItems[index] = PlanItem(localTask: task)** ← die fehlende Zeile
5. freezeSortOrder + scheduleDeferredResort

Call-Site: `updateCategory()` wird aufgerufen in BacklogView.swift Zeile 210 (CategoryPicker onSelect-Callback).
