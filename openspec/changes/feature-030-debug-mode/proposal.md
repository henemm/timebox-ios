# FEATURE_030 — Task Lifecycle Debug Mode

## Was

Ein Developer-Tool, das über einen Toggle in den Settings aktiviert wird. Bei aktiviertem Modus werden alle Task-Mutationen (Erstellen, Ändern, Löschen, Abschliessen, Wiedereröffnen, Anreichern) in eine separate Log-Datei geschrieben. Der Log ist direkt in der App einsehbar und per Share Sheet teilbar.

## Warum

Daten-Bugs (z.B. Task verschwindet, Felder werden unerwartet überschrieben, doppelte Events) sind ohne Sichtbarkeit auf den tatsächlichen Lifecycle schwer zu reproduzieren. Dieses Tool liefert exakte Timestamps, Task-UUIDs und Feldänderungen (alt → neu) — damit lassen sich Bugs gezielt diagnostizieren statt zu raten.

## Kategorie

**Developer Tool** — nicht sichtbar für Endnutzer im Normalbetrieb, kein Impact auf Production-Performance wenn deaktiviert.

## Technische Analyse

### Architektur: Singleton Logger

Ein neuer `TaskLifecycleLogger` Singleton wird eingeführt. Er prüft vor jedem Schreibvorgang `AppSettings.shared.taskDebugModeEnabled`. Ist der Toggle aus, ist der gesamte Aufruf ein No-Op — kein I/O, kein Overhead.

Logziel ist eine dedizierte Datei `Documents/task-lifecycle.log`, getrennt vom bestehenden `DebugLogger`. Damit bleibt der bestehende Log sauber und der Lifecycle-Log ist gezielt teilbar.

### Log-Format

Jede Zeile folgt dem Schema:

```
[ISO8601-Timestamp] [EVENT_TYPE] taskID=<uuid> field=old→new field2=old→new
```

Beispiel:
```
[2026-03-31T14:22:01Z] [updated] taskID=A1B2-... title="Alte Headline"→"Neue Headline" priority=medium→high
[2026-03-31T14:22:05Z] [completed] taskID=A1B2-...
[2026-03-31T14:22:10Z] [deleted] taskID=C3D4-...
```

Event-Typen: `created`, `updated`, `deleted`, `completed`, `uncompleted`, `enriched`

### Betroffene Dateien

| Datei | Änderung | LoC-Schätzung |
|-------|----------|---------------|
| `Sources/Helpers/TaskLifecycleLogger.swift` | Neue Datei: Singleton, Log-Writer, `logCreated/Updated/Deleted/Completed/Uncompleted/Enriched`, `getLog()`, `clearLog()`, `logPath()` | +90 LoC |
| `Sources/Models/AppSettings.swift` | `@AppStorage("taskDebugModeEnabled") var taskDebugModeEnabled: Bool = false` | +2 LoC |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | Aufrufe in `createTask()`, `updateTask()`, `deleteTask()`, `markComplete()`, `markIncomplete()` | +10 LoC |
| `Sources/Views/SettingsView.swift` | Section "Entwickler": Toggle + Log-Sheet (ScrollView + Share Button) + Log-löschen-Button | +90 LoC |

**Gesamt: 4 Dateien, ~190 LoC. Innerhalb des Limits (4–5 Dateien, ±250 LoC).**

### FieldChange-Modell

`LocalTaskSource.updateTask()` erhält Zugriff auf alte und neue Werte. Um diese an den Logger zu übergeben, wird ein leichtgewichtiges Struct verwendet:

```swift
struct FieldChange {
    let field: String
    let oldValue: String
    let newValue: String
}
```

Kein neues Dependency, rein intern im Logger-Modul.

### Settings-UI

Die neue Section "Entwickler" erscheint ganz unten in `SettingsView`. Sie enthält:

- Toggle "Task Debug Mode" (`accessibilityIdentifier: "taskDebugModeToggle"`)
- Button "Lifecycle Log anzeigen" → öffnet ein Sheet mit `ScrollView` + `Text(log)` + `ShareLink`
- Button "Log löschen" mit `.confirmationDialog` zur Sicherheit

Das Sheet zeigt den Log-Inhalt als Monospace-Text (`.font(.system(.footnote, design: .monospaced))`).

### Risiken & Einschränkungen

- `Documents/task-lifecycle.log` wächst unbegrenzt bis der User ihn manuell löscht — kein Auto-Truncate in dieser Version
- Der Log enthält UUIDs und Task-Titel (personenbezogene Daten) — Share Sheet macht das explizit sichtbar, der User entscheidet bewusst
- `LocalTaskSource.updateTask()` muss old/new Values verfügbar haben bevor der CoreData-Save passiert — Reihenfolge im bestehenden Code prüfen

## Acceptance Criteria

1. Toggle in Settings schaltet Logging ein und aus
2. Bei aktiviertem Debug Mode werden alle Task-Mutationen in `task-lifecycle.log` geschrieben
3. Log ist als Text im App-Sheet einsehbar und via Share Sheet teilbar
4. Jeder Log-Eintrag enthält: ISO8601-Timestamp, Event-Typ, Task-UUID, geänderte Felder mit alten und neuen Werten
5. Bei deaktiviertem Toggle wird nichts geloggt — kein I/O, kein Performance-Impact

## Scope-Bewertung

**Klein bis mittel.** 4 Dateien, ~190 LoC. Keine neuen Dependencies. Keine neuen Permissions. Keine macOS-Änderungen erforderlich (Developer-Tool ist iOS-only sinnvoll, macOS-Pendant kann separat bewertet werden).
