# Bug-Analyse: Kein Abhaken von Tasks im Coach View (#248)

## Root Cause

`CoachView.swift:822` erstellt `BacklogRow` ohne `onComplete`/`onCancelCompletion` Callbacks.
Die Checkbox ist sichtbar und tappbar, aber der Tap hat keinen Effekt (Callback ist `nil`).

## Betroffene Stellen

Alle 7 Task-Anzeige-Stellen im CoachView sind betroffen:
1. Morning Drawer: Tag-Cluster Tasks
2. Morning Drawer: Restliche Vorschläge
3. Daytime Drawer: "Heute geplant"
4. Daytime Drawer: "Erledigt" (kein Undo möglich)
5. Daytime Drawer: "Vorschläge"
6. Evening Drawer: "Erledigt"
7. Evening Drawer: "Offen geblieben"

## Vergleich: BacklogView (funktioniert) vs CoachView (kaputt)

**BacklogView (korrekt):**
```swift
BacklogRow(
    item: item,
    onComplete: { completeTask(item) },
    onCancelCompletion: { cancelCompletion(item) },
    isCompletionPending: deferredCompletion.isPending(item.id)
)
```

**CoachView (kaputt):**
```swift
BacklogRow(item: task, isCompletionPending: completed)
```

## Fehlende Dependencies in CoachView

- `DeferredCompletionController` (als @Environment)
- `completeTask()` Methode
- `cancelCompletion()` Methode

## Blast Radius

- iOS + macOS betroffen (shared CoachView)
- Backlog, Planning, andere Views: NICHT betroffen
- Fix hat kein Risiko für andere Views

## Vorherige Fix-Versuche

Keine. Erster Report dieses Bugs.

## Fix-Aufwand

Klein: ~30-60 LoC in 1-2 Dateien.
