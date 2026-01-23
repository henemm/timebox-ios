# Fix-Vorschlag: Scrolling in Focus Blocks

## Zusammenfassung

**Problem:** `.scrollDisabled(true)` verhindert Scrolling bei vielen Tasks
**Lösung:** `.scrollDisabled(true)` entfernen und `.frame(maxHeight:)` setzen

---

## Änderungen

### 1. TaskAssignmentView.swift - FocusBlockCard

**Zeile 327-331 (vorher):**
```swift
.listStyle(.plain)
.environment(\.editMode, .constant(.active))
.frame(minHeight: CGFloat(tasks.count * 44))
.scrollDisabled(true)
```

**Nachher:**
```swift
.listStyle(.plain)
.environment(\.editMode, .constant(.active))
.frame(maxHeight: min(CGFloat(tasks.count * 44), 264))  // Max 6 Tasks sichtbar
```

**Erklärung:**
- `maxHeight: 264` = 6 Tasks * 44pt Höhe
- Bei <= 6 Tasks: Volle Höhe, kein Scrolling nötig
- Bei > 6 Tasks: Feste Höhe mit Scrolling innerhalb

---

### 2. BlockPlanningView.swift - existingBlocksSection

**Zeile 214-216 (vorher):**
```swift
.listStyle(.plain)
.frame(minHeight: CGFloat(focusBlocks.count * 60))
.scrollDisabled(true)
```

**Nachher:**
```swift
.listStyle(.plain)
.frame(maxHeight: min(CGFloat(focusBlocks.count * 60), 300))  // Max 5 Blocks sichtbar
```

**Erklärung:**
- `maxHeight: 300` = 5 Blocks * 60pt Höhe
- Bei <= 5 Blocks: Volle Höhe
- Bei > 5 Blocks: Feste Höhe mit Scrolling

---

## Betroffene Dateien

| Datei | Änderungen | LoC |
|-------|------------|-----|
| TaskAssignmentView.swift | 2 Zeilen | ~3 |
| BlockPlanningView.swift | 2 Zeilen | ~3 |
| **Total** | | **~6** |

---

## Risiko-Bewertung

**Risiko: Niedrig**

- Keine Architektur-Änderung
- Keine neuen Dependencies
- Keine API-Änderungen
- Nur UI-Verhalten-Anpassung

---

## Nicht im Scope

Folgende potenzielle Issues werden NICHT in diesem Fix adressiert:

1. **taskBacklog** in TaskAssignmentView (VStack ohne ScrollView)
   - Aktuell kein Bug bestätigt
   - Würde separaten Fix erfordern

2. **NextUpSection** (VStack ohne ScrollView)
   - Aktuell kein Bug bestätigt
   - Bei Bedarf separater Fix

---

## Warte auf Freigabe

**Frage an PO:** Soll ich mit diesem Fix fortfahren?

- Fix betrifft 2 Dateien, ~6 Zeilen Code
- Kein Risiko für andere Funktionalität
- UI Tests werden VOR Implementation geschrieben (TDD)
