---
entity_id: bug-57-reminders-attribute-loss
type: bugfix
created: 2026-02-17
updated: 2026-02-17
status: draft
version: "1.0"
tags: [bugfix, datenverlust, sync, cloudkit, reminders, cross-platform]
---

# Bug 57: Erweiterte Attribute gehen verloren bei macOS+iOS Parallelbetrieb

## Approval

- [ ] Approved

## Purpose

Wenn beide Plattformen (macOS + iOS) parallel genutzt werden, gehen manuell gesetzte erweiterte Attribute (Urgency, Importance, Duration, Category) von Reminder-basierten Tasks verloren. Der macOS Reminders-Sync ueberschreibt die Werte via CloudKit.

## Symptom

- User setzt Attribute (z.B. Urgency=urgent, Category=Essentials) auf iOS
- Nach einiger Zeit zeigen die Tasks wieder "?" fuer alle erweiterten Attribute
- Betrifft nur Tasks mit `sourceSystem="reminders"`, nicht lokal erstellte Tasks
- Die ersten 1-2 Tasks behalten ihre Attribute (vermutlich kein Reminder-Sync fuer diese)

## Root Causes

### RC1: macOS updateTask() macht gesamtes SwiftData-Objekt dirty
**Datei:** `Sources/Services/RemindersSyncService.swift:116-133`

```swift
private func updateTask(_ task: LocalTask, from reminder: ReminderData) {
    task.title = reminder.title           // ← schreibt IMMER, auch wenn gleich
    task.isCompleted = reminder.isCompleted // ← schreibt IMMER
    task.dueDate = reminder.dueDate        // ← schreibt IMMER
    task.taskDescription = reminder.notes   // ← schreibt IMMER
}
```

Jede Zuweisung markiert das SwiftData-Objekt als dirty, auch wenn der Wert identisch ist. SwiftData synct dann ALLE Felder via CloudKit - einschliesslich `urgency=nil`, `estimatedDuration=nil`, `taskType=""`. Wenn macOS die aelteren nil-Werte hat (weil der iOS-Sync noch nicht angekommen war), ueberschreibt CloudKit die iOS-Werte mit nil.

**Reihenfolge:**
1. iOS: User setzt urgency="urgent" → CloudKit Upload
2. macOS: syncWithReminders() laeuft → title wird geschrieben (identischer Wert) → Objekt dirty
3. macOS: SwiftData synct ALLE Felder → urgency=nil geht zu CloudKit
4. CloudKit: last-writer-wins → macOS nil ueberschreibt iOS "urgent"
5. iOS: Empfaengt nil → Attribut verloren

### RC2: Instabile calendarItemIdentifier
**Datei:** `Sources/Models/ReminderData.swift:14`

```swift
self.id = reminder.calendarItemIdentifier  // ← INSTABIL
```

Apple-Dokumentation: "This identifier is not guaranteed to remain stable across syncs."

`calendarItemExternalIdentifier` ist die stabile Alternative fuer geraeteuebergreifende Referenzen.

**Auswirkung:** Wenn sich die ID aendert:
1. `findTask(byExternalID:)` findet den bestehenden Task NICHT
2. `createTask(from:)` erstellt einen NEUEN Task (ohne erweiterte Attribute)
3. `handleDeletedReminders()` loescht den alten Task (mit Attributen)

### RC3: Aggressives handleDeletedReminders
**Datei:** `Sources/Services/RemindersSyncService.swift:158-170`

```swift
if !currentReminderIDs.contains(externalID) {
    modelContext.delete(task)  // ← Sofort geloescht, kein Soft-Delete
}
```

Hard-Delete bei fehlendem Reminder-Match. Kein Grace Period, kein Soft-Delete.

## Fix-Strategie

### Fix A: Bedingte Schreibzugriffe (HAUPTFIX)
**Datei:** `Sources/Services/RemindersSyncService.swift`

Nur schreiben wenn der Wert sich tatsaechlich geaendert hat:

```swift
private func updateTask(_ task: LocalTask, from reminder: ReminderData) {
    if task.title != reminder.title { task.title = reminder.title }
    if task.isCompleted != reminder.isCompleted { task.isCompleted = reminder.isCompleted }
    if task.dueDate != reminder.dueDate { task.dueDate = reminder.dueDate }
    if task.taskDescription != reminder.notes { task.taskDescription = reminder.notes }

    let appleImportance = mapReminderPriority(reminder.priority)
    if task.importance == nil {
        task.importance = appleImportance
    }
}
```

**Effekt:** Wenn sich nur Apple-Felder nicht aendern, wird das Objekt NICHT als dirty markiert → kein CloudKit-Sync → keine Ueberschreibung der erweiterten Attribute.

### Fix B: Stabile Reminder-IDs
**Datei:** `Sources/Models/ReminderData.swift`

```swift
// Vorher:
self.id = reminder.calendarItemIdentifier
// Nachher:
self.id = reminder.calendarItemExternalIdentifier
```

**Migration:** Bestehende Tasks mit `calendarItemIdentifier` muessen auf `calendarItemExternalIdentifier` migriert werden, sonst werden sie als "neu" behandelt.

**Achtung:** `calendarItemExternalIdentifier` kann initial leer sein fuer neue Reminders die noch nicht mit iCloud gesynct wurden. Fallback auf `calendarItemIdentifier` noetig.

### Fix C: Soft-Delete statt Hard-Delete
**Datei:** `Sources/Services/RemindersSyncService.swift`

Statt `modelContext.delete(task)`:

```swift
if !currentReminderIDs.contains(externalID) {
    // Soft-Delete: Von Reminders entkoppeln statt loeschen
    task.sourceSystem = "local"
    task.externalID = nil
}
```

**Effekt:** Task wird von Reminders "entkoppelt" aber nicht geloescht. Attribute bleiben erhalten. Wenn der Reminder wieder auftaucht, wird er als neuer Task importiert.

### Fix D: Safety Net - Attribut-Schutz auf Model-Ebene
**Datei:** `Sources/Models/LocalTask.swift`

Defensiver Guard der JEDEN nil-Overwrite auf gesetzte erweiterte Attribute verhindert, egal woher:

```swift
/// Setzt erweiterte Attribute NUR wenn der neue Wert nicht nil ist
/// oder der bestehende Wert bereits nil war.
/// Verhindert versehentliches Loeschen durch Sync/CloudKit/Bugs.
func safeSetImportance(_ value: Int?) {
    guard value != nil || importance == nil else { return }
    importance = value
}

func safeSetUrgency(_ value: String?) {
    guard value != nil || urgency == nil else { return }
    urgency = value
}

func safeSetDuration(_ value: Int?) {
    guard value != nil || estimatedDuration == nil else { return }
    estimatedDuration = value
}

func safeSetTaskType(_ value: String) {
    guard !value.isEmpty || taskType.isEmpty else { return }
    taskType = value
}
```

**Effekt:** Selbst wenn ein zukuenftiger Bug nil-Werte durchreicht, werden bestehende Attribute NICHT ueberschrieben. Das ist die letzte Verteidigungslinie.

**Nutzung:** `SyncEngine.updateTask()` und alle anderen Stellen die optionale Attribute schreiben nutzen die safe-Setter statt direkter Zuweisung.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Services/RemindersSyncService.swift` | MODIFY | Fix A: Bedingte Writes + Fix C: Soft-Delete |
| `Sources/Models/ReminderData.swift` | MODIFY | Fix B: calendarItemExternalIdentifier |
| `Sources/Models/LocalTask.swift` | MODIFY | Fix D: Safe-Setter fuer erweiterte Attribute |
| `Sources/Services/SyncEngine.swift` | MODIFY | Fix D: Safe-Setter verwenden |

**Scope:** 4 Dateien, ~60 LoC netto

## Risks

- **Fix B Migration:** Bestehende externalIDs im SwiftData muessen migriert werden. Eine einmalige Migration beim App-Start koennte noetig sein.
- **Fix B Fallback:** `calendarItemExternalIdentifier` kann leer sein fuer frisch erstellte Reminders. Fallback auf `calendarItemIdentifier` implementieren.
- **Fix C Seiteneffekt:** Entkoppelte Tasks bleiben als "local" im Backlog. User muss sie manuell loeschen wenn nicht mehr gewuenscht.
- **Fix D Trade-off:** User kann Attribute nicht mehr auf TBD zuruecksetzen via normalen Code-Pfad. Braucht expliziten "Reset"-Mechanismus wenn gewuenscht (aktuell kein Use-Case dafuer).

## Test Cases

### Unit Test: Bedingte Writes (Fix A)
1. LocalTask mit title="Test", urgency="urgent" erstellen
2. `updateTask(task, from: reminder)` aufrufen mit reminder.title="Test" (identisch)
3. Verifizieren: task.urgency bleibt "urgent" (nicht nil)
4. SwiftData markiert Objekt NICHT als dirty (keine aenderung)

### Unit Test: Stabile IDs (Fix B)
1. ReminderData aus EKReminder erstellen
2. Verifizieren: `id` ist `calendarItemExternalIdentifier` (nicht `calendarItemIdentifier`)
3. Fallback: Wenn `calendarItemExternalIdentifier` leer → `calendarItemIdentifier` nutzen

### Unit Test: Soft-Delete (Fix C)
1. LocalTask mit sourceSystem="reminders", externalID="ABC" erstellen
2. `handleDeletedReminders` aufrufen mit leerer ID-Menge
3. Verifizieren: Task existiert noch, sourceSystem="local", externalID=nil

### Integrations-Test: Cross-Device Szenario
1. LocalTask erstellen mit sourceSystem="reminders", urgency="urgent", importance=3
2. `updateTask(task, from: reminder)` aufrufen (simuliert macOS-Sync)
3. Verifizieren: urgency="urgent" und importance=3 bleiben erhalten
