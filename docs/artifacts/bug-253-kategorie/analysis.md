# Bug-Analyse: Kategorie lässt sich nicht ändern (#253)

## User-Erwartung
Kategorie antippen, andere auswählen, fertig. Drei Schritte. Stattdessen: Crash.

## Root Cause (macOS — bestätigt)
`FocusBloxMac/TaskInspector.swift:575` — `saveAndNotify()` ruft sich selbst rekursiv auf statt `modelContext.save()`. Stack Overflow bei JEDER Speicheroperation im Inspector.

```swift
private func saveAndNotify() {
    saveAndNotify()  // ← REKURSION statt try? modelContext.save()
    NotificationCenter.default.post(name: .taskDataChanged, object: nil)
}
```

Betrifft ALLE 14 Speicheroperationen im macOS TaskInspector — nicht nur Kategorie.

## iOS — unklar
Mehrere Hypothesen (Race Condition, SwiftData Reentrancy) aber kein bestätigter Crash-Pfad. Issue sagt "platform:ios" — möglicherweise Verwechslung mit macOS.

## Blast Radius
- macOS TaskInspector: ALLE Save-Operationen crashen (Kategorie, Wichtigkeit, Dringlichkeit, Dauer, etc.)
- iOS BacklogView: Separater Code-Pfad, nicht direkt betroffen
- Coach/Planung: Lesen nur, kein Crash

## Fix
1 Zeile: `saveAndNotify()` → `try? modelContext.save()` in Zeile 575
