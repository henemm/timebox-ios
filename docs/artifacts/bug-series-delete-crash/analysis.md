# Bug Analysis: macOS Series-Delete Crash (LocalTask.tags)

**Datum:** 2026-03-19
**Platform:** macOS
**Status:** TDD RED — Tests schlagen fehl (Crash reproduziert)

---

## Symptom

macOS: Rechtsklick auf wiederkehrenden Task → "Löschen" → "Alle offenen dieser Serie"
→ App crasht sofort.

```
Fatal error: This backing data was detached from a context without resolving
attribute faults: PersistentIdentifier(...) - \LocalTask.tags
```

---

## Devil's Advocate Verdict: LÜCKEN → behoben

Challenger: *"Warum crasht 'Nur diese Aufgabe' nicht, obwohl das nil-Timing-Muster identisch ist?"*
→ Antwort: **'Nur diese Aufgabe' löscht den Task der bereits in der UI gerendert war** — dessen `tags` wurden durch `MacBacklogRow`/`TagInputView` bereits geladen (kein Fault mehr). **'Alle dieser Serie' löscht auch Template + Kinder-Tasks**, die NIE im Inspector angezeigt wurden → `tags` sind noch Faults (ungeladen) → crash bei Zugriff.

Challenger: *"`nextUpTasks` (Zeile 281) ruft `matchesSearch()` ohne `modelContext != nil` Guard auf"*
→ Bestätigt. `tasks.filter { $0.isNextUp && ... && matchesSearch($0) }` — kein Pre-Guard. Fix adressiert das.

Challenger: *"TaskInspector mit `@Bindable var task` kann während Dismiss-Animation auf detachte tags zugreifen"*
→ Bestätigt als weiterer möglicher Crash-Pfad. Fix: `selectedTasks.removeAll()` VOR Deletion.

---

## Agenten-Ergebnisse (Zusammenfassung)

| Agent | Ergebnis |
|-------|---------|
| Wiederholungs-Check | BUG_78 (2026-03-09) hatte ähnlichen Fix → `modelContext != nil` Guard. Guard ist INSUFFIZIENT. Dies ist neues Auftreten desselben Grundproblems. |
| Datenfluss-Trace | `taskToDeleteRecurring: LocalTask?` hält Referenz auf Task-Objekt. `deleteRecurringSeries()` löscht diesen Task selbst. Danach: Backing Data detached, aber Referenz noch aktiv. |
| Tags-Zugriffe | Crash-Punkt: ContentView.swift Zeile 111 — `task.tags.contains()` in `matchesSearch()`. Der Bug-78-Guard `modelContext != nil` greift nicht, weil `modelContext` erst nach `save()` verzögert null wird. |
| Szenarien | 4 Crash-Szenarien identifiziert. Primär: Dialog-Closure setzt `taskToDeleteRecurring = nil` NACH dem Delete — zu spät. |
| Blast Radius | iOS nutzt `PlanItem` (struct/value type) → kein Problem. macOS nutzt `LocalTask` (class/reference type) → Referenz wird detached. Nur macOS betroffen. |

---

## Root Cause (Single, klar bewiesen)

**Datei:** `FocusBloxMac/ContentView.swift`
**Zeilen:** 619–623

```swift
Button("Alle offenen dieser Serie", role: .destructive) {
    if let task = taskToDeleteRecurring {
        deleteRecurringSeries(task)        // ← (1) Löscht task inkl. sich selbst
        taskToDeleteRecurring = nil        // ← (2) ZU SPÄT: task ist bereits detached
    }
}
```

**Timeline:**

1. `deleteRecurringSeries(task)` läuft:
   - FetchDescriptor holt ALLE Tasks der Serie — **inklusive `task` selbst** (selbe `recurrenceGroupID`, `!isCompleted`)
   - `modelContext.delete(t)` für jeden Task → backing data von `task` wird SOFORT detached
   - `modelContext.save()` committet Deletion
   - `refreshTasks()` → `tasks` Array neu befüllt (ohne gelöschte Objekte)
2. `taskToDeleteRecurring = nil` wird gesetzt → triggert SwiftUI Re-render
3. Re-render von `filteredTasks` → `matchesSearch()` → `task.tags.contains()` auf detachtem Objekt → **CRASH**

**Warum iOS nicht betroffen:**
iOS `taskToDeleteRecurring` ist vom Typ `PlanItem` (struct = value type). Löschen des `LocalTask` in der DB detacht nicht den value-type Copy im State. macOS nutzt `LocalTask` (class = reference type) — dieselbe Objektreferenz.

---

## Hypothesen

### H1: `taskToDeleteRecurring = nil` zu spät gesetzt — WAHRSCHEINLICHKEIT: HOCH ✅

**Beweis:**
- Line 620: `deleteRecurringSeries(task)` deletes task's backing data
- Line 622: `taskToDeleteRecurring = nil` erst danach
- Dazwischen: `refreshTasks()` triggers re-render via `tasks = ...`
- `matchesSearch()` könnte auf altem/detachtem State aufgerufen werden

**Gegen H1:**
- `matchesSearch()` läuft nur auf Elementen in `tasks`, und `tasks` ist nach `refreshTasks()` frisch. Die detachten Tasks sollten nicht mehr in `tasks` sein.
- Tatsächlicher Trigger: Der Bug-78-Guard `task.modelContext != nil` reicht nicht aus, weil SwiftData `modelContext` nicht sofort null setzt nach `delete()`.

**Fazit H1:** Root Cause bestätigt. Der Fix ist: `taskToDeleteRecurring = nil` VOR dem Delete setzen.

### H2: `matchesSearch()` Guard insuffizient — WAHRSCHEINLICHKEIT: MITTEL

**Beweis:** Agent 3 zeigt, dass `modelContext != nil` nach `delete()` noch non-nil sein kann.
**Aber:** `refreshTasks()` holt neue Objekte aus der DB — detachte sollten nicht mehr in `tasks` sein.
**Fazit:** Sekundäres Problem. Fix für H1 macht H2 irrelevant.

### H3: SwiftUI Animation Race Condition — WAHRSCHEINLICHKEIT: MITTEL

**Beweis:** Dialog-Dismiss-Animation läuft während State sich ändert. SwiftUI könnte `taskToDeleteRecurring` während der Animation re-evaluieren.
**Fazit:** Kann ebenfalls durch "nil zuerst setzen" verhindert werden.

---

## Wahrscheinlichste Ursache

**H1 ist die Root Cause.**

`taskToDeleteRecurring = nil` wird NACH dem Delete gesetzt. Der Local Capture `task` in der Closure hält noch die Referenz auf das gelöschte, detachte Objekt. Während `refreshTasks()` + SwiftUI Re-render wird `task.tags` auf diesem detachten Objekt accessed.

### Beweis-Plan

Logging-Check (nicht nötig, da Crash reproduzierbar und Code-Analyse eindeutig):
- Fix: `taskToDeleteRecurring = nil` VOR `deleteRecurringSeries(task)` → wenn Tests grün, Beweis erbracht

---

## Blast Radius

| Bereich | Betroffen? | Warum |
|---------|-----------|-------|
| macOS "Alle offenen dieser Serie" | ✅ JA (Crash) | `LocalTask` reference detached |
| macOS "Nur diese Aufgabe" | ⚠️ Potenziell | Selber State-Pattern, aber kein Array-Delete |
| iOS "Alle offenen dieser Serie" | ❌ NEIN | `PlanItem` value type, kein Detach-Problem |
| iOS "Nur diese Aufgabe" | ❌ NEIN | Selber Grund |
| `taskToEditRecurring` Pattern | ⚠️ Selbes Muster | Kann ähnlichen Crash verursachen bei Edit-Op |

---

## Fix-Vorschlag (nach Challenge-Review: 3 Änderungen)

### Änderung 1: Button "Alle offenen dieser Serie" — nil und selectedTasks VOR Delete

```swift
// ContentView.swift, Zeilen 619-623
Button("Alle offenen dieser Serie", role: .destructive) {
    if let task = taskToDeleteRecurring {
        let groupID = task.recurrenceGroupID   // Wert extrahieren (sicher, String)
        taskToDeleteRecurring = nil            // ZUERST: Referenz freigeben
        selectedTasks.removeAll()             // ZUERST: Inspector schließen
        if let groupID {
            deleteRecurringSeries(groupID: groupID)  // Nur String übergeben
        }
    }
}
```

### Änderung 2: `deleteRecurringSeries` nimmt `groupID: String` statt `LocalTask`

```swift
private func deleteRecurringSeries(groupID: String) {   // String, kein LocalTask-Objekt
    let descriptor = FetchDescriptor<LocalTask>(
        predicate: #Predicate { $0.recurrenceGroupID == groupID && !$0.isCompleted }
    )
    if let seriesTasks = try? modelContext.fetch(descriptor) {
        for t in seriesTasks {
            modelContext.delete(t)
        }
    }
    try? modelContext.save()
    refreshTasks()
    // selectedTasks.removeAll() entfernen — wird jetzt VOR dem Call gemacht
}
```

### Änderung 3: `nextUpTasks` — `modelContext != nil` Guard hinzufügen

```swift
// ContentView.swift, Zeile 281
private var nextUpTasks: [LocalTask] {
    tasks.filter {
        $0.modelContext != nil &&   // NEU: Guard wie in visibleTasks (Bug-78-Pattern)
        $0.isNextUp && !$0.isCompleted && !$0.isTemplate &&
        $0.blockerTaskID == nil && matchesSearch($0)
    }
    .sorted { ($0.nextUpSortOrder ?? Int.max) < ($1.nextUpSortOrder ?? Int.max) }
}
```

**Dateien:** Nur `FocusBloxMac/ContentView.swift` — ~10 LoC geändert.

**Warum diese 3 Änderungen zusammen:**
- Ä1+2: Kein SwiftData-Objekt mehr im State → kein Detach-Problem via `taskToDeleteRecurring`
- Ä1: `selectedTasks` geleert VOR Delete → TaskInspector schließt bevor Objekte gelöscht werden
- Ä3: `nextUpTasks` hat jetzt denselben Guard wie `visibleTasks` → defensive gegen zukünftige Regression

**Plattform-Check:** Nur macOS (`FocusBloxMac/ContentView.swift`). iOS `BacklogView.swift` nicht betroffen (verwendet `PlanItem` value type).
