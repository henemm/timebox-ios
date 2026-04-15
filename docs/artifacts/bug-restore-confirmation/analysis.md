# Bug #225: Analyse — Rückfrage vorm Wiederherstellen

## Problem

Beim Schütteln des iPhones (Shake to Undo) wird die letzte Task-Completion sofort rückgängig gemacht — ohne vorherige Rückfrage. iOS zeigt normalerweise einen "Rückgängig?"-Dialog, aber FocusBlox überspringt diesen und führt den Undo direkt aus.

## Root Cause

**`BacklogView.swift:367-368`** — Der `.onShake`-Handler ruft `undoLastCompletion()` direkt auf, ohne vorher zu fragen:

```swift
.onShake {
    undoLastCompletion()  // ← sofort, keine Rückfrage
}
```

Der Alert auf Zeile 371 (`"Rückgängig"`) ist nur eine **Erfolgs-Meldung** nach dem Undo — kein Bestätigungs-Dialog davor.

## Hypothesen

1. **Fehlender Bestätigungs-Dialog vor Shake-Undo (iOS)** — WAHRSCHEINLICHSTE URSACHE
   - `.onShake` → direkt `undoLastCompletion()` → Alert nur als Info danach
   - Fix: Erst Dialog zeigen, bei Bestätigung Undo ausführen

2. **Fehlender Bestätigungs-Dialog bei Swipe/Context-Menu im Erledigt-Tab**
   - `BacklogView.swift:1468`: `allowsFullSwipe: true` + kein Dialog
   - Ebenfalls kein Schutz, aber laut User ist Shake der gemeldete Trigger

3. **macOS Cmd+Z ohne Rückfrage**
   - `FocusBloxMacApp.swift:507-510`: identisches Pattern
   - Plattform-Parität: sollte analog gefixt werden

## Betroffene Stellen

| Szenario | Datei:Zeile | Plattform | Rückfrage? |
|---|---|---|---|
| Shake Gesture | BacklogView.swift:367-368 | iOS | Nein |
| Swipe "Wiederherstellen" | BacklogView.swift:1468-1474 | iOS | Nein |
| Context Menu | BacklogView.swift:1483-1488 | iOS | Nein |
| Cmd+Z | FocusBloxMacApp.swift:507-510 | macOS | Nein |
| Swipe/Context macOS | ContentView.swift:1032-1036 | macOS | Nein |

## Blast Radius

**Klein.** Primär 1 Datei (BacklogView.swift) für den gemeldeten Bug. Für Plattform-Parität zusätzlich FocusBloxMacApp.swift.

Der `TaskCompletionUndoService` selbst ist korrekt und braucht keine Änderung.

## Vorgeschlagener Ansatz

Den Shake-Handler so umbauen, dass erst ein Bestätigungs-Alert ("Rückgängig machen?" mit Ja/Abbrechen) erscheint und der Undo nur bei Bestätigung ausgeführt wird.
