---
entity_id: bug-keyword-tests-not-running
type: bugfix
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [tests, pbxproj, keyword-system, infrastructure]
---

# Bug: KeywordSystemTests — 0 Tests Executed

## Approval

- [ ] Approved

## Purpose

KeywordSystemTests.swift (79+ Unit Tests) wurde durch Commit `209ea9a` (BUG_169) als Kollateralschaden eines pbxproj-Rewrites aus dem FocusBloxTests-Target entfernt. Seitdem werden 0 von 79+ Tests ausgeführt. Die Tests müssen wieder registriert und lauffähig gemacht werden.

## Source

- **File:** `FocusBlox.xcodeproj/project.pbxproj`
- **Identifier:** FocusBloxTests Target — fehlende KeywordSystemTests.swift Registrierung

Zweite betroffene Quelle:

- **File:** `FocusBloxTests/KeywordSystemTests.swift`
- **Identifier:** `final class KeywordSystemTests: XCTestCase`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| TaskTitleEngine | service | Getesteter Code (stripKeywords, extractDeterministicUrgency/Importance/Duration) |
| LocalTask | model | Test-Setup (ModelContainer, in-memory) |
| pbxproj Python-Library | tool | Zum Hinzufügen der Datei zum Xcode-Projekt |

## Implementation Details

### Schritt 1: Datei zum FocusBloxTests-Target hinzufügen

```python
python3 -c "
from pbxproj import XcodeProject
proj = XcodeProject.load('FocusBlox.xcodeproj/project.pbxproj')
proj.add_file('FocusBloxTests/KeywordSystemTests.swift', target_name='FocusBloxTests')
proj.save()
"
```

### Schritt 2: Build prüfen

```bash
./scripts/sim.sh build
```

Falls Compile-Errors auftreten: API-Drift seit Commit `3b31cb1` beheben. Mögliche Probleme:
- Geänderte Methodensignaturen in TaskTitleEngine
- Entfernte/umbenannte Funktionen durch RW_1.5 Refiner-Rückbau

### Schritt 3: Tests ausführen

```bash
./scripts/sim.sh unit KeywordSystemTests
```

Erwartung: 79+ Tests ausgeführt (statt 0).

### Betroffene Dateien

| File | Change Type | Beschreibung |
|------|-------------|--------------|
| `FocusBlox.xcodeproj/project.pbxproj` | MODIFY | KeywordSystemTests.swift zum FocusBloxTests-Target hinzufügen |
| `FocusBloxTests/KeywordSystemTests.swift` | MODIFY (falls nötig) | API-Drift beheben falls Compile-Errors |

**Scope:** 1-2 Dateien, ~5-20 LoC | **Risk:** LOW

## Expected Behavior

- **Input:** `./scripts/sim.sh unit KeywordSystemTests`
- **Output:** 79+ Tests executed, 0 failures
- **Side effects:** Keine — nur Test-Infrastruktur, kein Produktionscode betroffen

## Acceptance Criteria

- KeywordSystemTests.swift ist im FocusBloxTests-Target registriert (pbxproj)
- `./scripts/sim.sh unit KeywordSystemTests` führt 79+ Tests aus
- Alle Tests sind grün (0 failures)
- Kein anderer Test ist durch die Änderung betroffen

## Known Limitations

- Falls APIs sich seit BUG_148 geändert haben, müssen einzelne Tests angepasst werden
- Das pbxproj-Kollateralschaden-Problem (Commit `209ea9a`) könnte bei zukünftigen Rewrites erneut auftreten

## Changelog

- 2026-03-31: Initial spec created (workflow bug-keyword-tests-not-running)
