# Bug 21: Tag-Eingabe mit Autocomplete und Vorschlaegen

## Problem

Die Tag-Eingabe ist an 3 Stellen unterschiedlich implementiert:
1. **TaskFormSheet** (iOS, Hauptpfad): Chips + TextField + Plus-Button - gut, aber ohne Autocomplete
2. **EditTaskSheet** (iOS, Nebenpfad): Einfaches Komma-getrenntes TextField - veraltet
3. **TaskInspector** (macOS): Keine Tag-Bearbeitung vorhanden

Kein Autocomplete, keine Vorschlaege fuer bereits verwendete Tags.

## Loesung

### 1. Neue Methode: `LocalTaskSource.fetchAllUsedTags()`
- Liest alle Tasks, sammelt unique Tags
- Sortiert nach Haeufigkeit (meistgenutzt zuerst)
- ~15 LoC

### 2. Neuer Component: `TagInputView`
- Wiederverwendbar fuer iOS und macOS
- Zeigt aktuelle Tags als Chips (Tap/Click = entfernen)
- TextField fuer neue Tags mit Autocomplete-Dropdown
- Vorschlaege filtern sich beim Tippen
- Bereits zugewiesene Tags werden aus Vorschlaegen ausgeblendet
- ~100 LoC

### 3. Integration in bestehende Views
- **TaskFormSheet**: Bestehende Tag-Section durch `TagInputView` ersetzen
- **EditTaskSheet**: Komma-TextField durch `TagInputView` ersetzen (Tags als `[String]` statt `String`)
- **TaskInspector** (macOS): Neue Tags-Section mit `TagInputView` hinzufuegen

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `Sources/Services/TaskSources/LocalTaskSource.swift` | `fetchAllUsedTags()` hinzufuegen |
| `Sources/Views/TagInputView.swift` | **NEU** - Wiederverwendbarer Component |
| `Sources/Views/TaskFormSheet.swift` | Tag-Section durch TagInputView ersetzen |
| `Sources/Views/EditTaskSheet.swift` | Komma-TextField durch TagInputView ersetzen |
| `FocusBloxMac/TaskInspector.swift` | Tags-Section hinzufuegen |
| `FocusBlox.xcodeproj/project.pbxproj` | TagInputView registrieren |

## Scope

- ~6 Dateien, ~200 LoC netto
- Kein neues Datenmodell noetig (Tags sind bereits `[String]` in LocalTask)
