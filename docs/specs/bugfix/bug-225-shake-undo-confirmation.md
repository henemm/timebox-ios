---
entity_id: bug-225-shake-undo-confirmation
type: bugfix
created: 2026-04-15
updated: 2026-04-15
status: draft
version: "1.0"
tags: [ios, backlog, undo, shake]
---

# Bug #225: Rückfrage vorm Wiederherstellen (Shake to Undo)

## Approval

- [ ] Approved

## Purpose

Beim Schütteln des iPhones (Shake to Undo) wird die letzte Task-Completion sofort rückgängig gemacht. Es soll vorher ein Bestätigungs-Dialog erscheinen.

## Source

- **File:** `Sources/Views/BacklogView.swift`
- **Identifier:** `.onShake` Handler (Zeile ~367) + `undoLastCompletion()` (Zeile ~398)

## Root Cause

Der `.onShake`-Handler ruft `undoLastCompletion()` direkt auf. Der bestehende Alert (Zeile ~371) ist nur eine Erfolgs-Meldung nach dem Undo, keine Rückfrage davor.

## Änderung

1. **Neuer State:** `@State private var showUndoConfirmation = false`
2. **Shake-Handler ändern:** Statt `undoLastCompletion()` direkt aufzurufen → `showUndoConfirmation = true`
3. **Bestätigungs-Dialog hinzufügen:** `.confirmationDialog("Rückgängig machen?", isPresented: $showUndoConfirmation)` mit:
   - Button "Rückgängig machen" → ruft `undoLastCompletion()` auf
   - Button "Abbrechen" (cancel role)
4. **Bestehender Erfolgs-Alert bleibt** — wird weiterhin nach erfolgreichem Undo angezeigt

## Expected Behavior

- **Vorher:** Shake → Task sofort wiederhergestellt → Info-Alert "XY wiederhergestellt"
- **Nachher:** Shake → Dialog "Rückgängig machen?" → User bestätigt → Task wiederhergestellt → Info-Alert "XY wiederhergestellt"
- **Abbrechen:** Shake → Dialog → User bricht ab → nichts passiert

## Scope

- **Nur** Shake Gesture auf iOS
- **Nicht** betroffen: Swipe/Context-Menu im Erledigt-Tab, macOS Cmd+Z

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/BacklogView.swift` | Shake-Handler + confirmationDialog |

## Side Effects

Keine. Der `TaskCompletionUndoService` bleibt unverändert.

## Changelog

- 2026-04-15: Initial spec created
