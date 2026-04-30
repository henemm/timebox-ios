---
entity_id: bug-295-list-section-a11y
type: bugfix
created: 2026-04-28
updated: 2026-04-28
status: draft
version: "1.0"
workflow: bug-295-backlog-a11y-tree
tags: [ios, macos, backlog, accessibility, ui-test]
---

# Bug #295: BacklogView List-Sektionen fehlen im Accessibility-Tree

## Approval

- [ ] Approved

## Purpose

SwiftUI-`List`-Sektionen in der BacklogView (Mode `.priority`) liefern ab Section 2 keine Body-Rows in den XCUITest-Accessibility-Tree. Nur die "Heute/NextUp"-Section ist vollständig erreichbar; alle weiteren Sektionen (Überfällig, Dringend, Bald, Später, Geparkt) sind für UI-Tests unsichtbar. Das verhindert zuverlässige Tests für Stacking-Badges und Tier-Sektionen — und deutet auf ein reales Accessibility-Problem für VoiceOver-Nutzer hin.

## Source

- **File:** `Sources/Views/BacklogView.swift` — Sektionen Überfällig (Z. 1224-1244), Geparkt (Z. 1252-1281), tierSection (Z. 1294-1326), backlogRowWithSwipe (Z. 1090-1156)
- **File:** `FocusBloxMac/ContentView.swift` — Sektionen Überfällig (Z. 516-536), Geparkt (Z. 549-572), macTierSection (Z. 403-438)
- **Identifier:** `Section { ... } header: { ... }` ohne `.accessibilityElement(children: .contain)`

## Root Cause

Zwei Ursachen, Hypothese B ist primär:

**Hypothese B (primär):** Nur die NextUp-Section trägt einen Accessibility-Container-Modifier (`.accessibilityIdentifier("nextUpSection")` auf ihrem Header). Alle anderen Sektionen haben keinerlei Container-Modifier. SwiftUI collapsed diese Sektionen im Accessibility-Tree, sodass ihre Body-Rows nicht erreichbar sind. Diagnose-Werte bestätigen das: `taskTitleIds=4` (genau die 4 NextUp-Tasks), `badgeIds=0`, `ueberfaelligHeader=1` (Header sichtbar, Body fehlt).

**Hypothese A (sekundär, möglicher Verschärfer):** `backlogRowWithSwipe(_:)` (Z. 1090-1156) ist `@ViewBuilder` und liefert `TupleView<(VStack, ForEach)>` wegen eines trailing `ForEach` für blockierte Tasks (Z. 1153-1155). Die NextUp-Section nutzt diesen Helper nicht — was erklären könnte, warum NextUp korrekt funktioniert. Eine `TupleView` aus zwei Top-Level-Kinder kann SwiftUI im Accessibility-Tree anders behandeln als eine einzelne View.

## Änderung

### Schritt 1 — Accessibility-Container-Modifier (primärer Fix)

Auf jeder betroffenen Section (iOS + macOS) einfügen:

```swift
Section {
    // ... bestehende Body-Rows
} header: {
    // ... bestehender Header
}
.accessibilityElement(children: .contain)
.accessibilityIdentifier("<sectionId>")
```

Identifier-Tabelle:

| Sektion | `accessibilityIdentifier` |
|---------|--------------------------|
| Überfällig | `ueberfaelligSection` |
| Dringend | `dringendSection` |
| Bald | `baldSection` |
| Spaeter | `spaeterSection` |
| Geparkt | `geparktSection` |

Auf macOS gelten dieselben Identifier (Parität iOS/macOS).

**Nach Schritt 1 sofort testen** (TDD-GREEN-Prüfung). Falls alle 4 Tests grün sind, ist Schritt 2 abgeschlossen — nicht implementieren.

### Schritt 2 — Fallback: trailing ForEach herauslösen (nur bei Bedarf)

Nur wenn Schritt 1 allein nicht ausreicht:

`backlogRowWithSwipe(_:)` so refactoren, dass der Helper eine einzelne View liefert. Die blockierten Tasks-`ForEach` (Z. 1153-1155) werden im Aufrufer separat appended:

```swift
// Vorher (im Helper):
// ... VStack + ForEach als TupleView

// Nachher (im Aufrufer):
backlogRowWithSwipe(task)
ForEach(blockedTasks) { blocked in blockedTaskRow(blocked) }
```

Der Helper liefert dann eine reine `VStack`-View ohne trailing `ForEach`.

## Expected Behavior

**Vorher:**
- `taskTitleIds` = 4 (nur NextUp-Tasks)
- `badgeIds` = 0
- `ueberfaelligHeader` sichtbar, Rows nicht erreichbar
- UI-Tests für Sektionen 2-N schlagen fehl

**Nachher:**
- Alle `taskTitle_<id>`-Rows aller Sektionen im Accessibility-Tree erreichbar
- `stackingBadge_<id>`-Elemente (Label "x3" etc.) erreichbar
- NextUp bleibt weiterhin vollständig erreichbar
- Swipe-Gesten und Refresh-Logik unverändert

## Test-Plan

**Neue Datei:** `FocusBloxUITests/BacklogSectionsA11yUITests.swift`

Anti-Silent-Pass-Regeln (zwingend einhalten):
- KEIN `if let` / `guard let ... else { return }` in Assertions
- KEIN optionales Chaining ohne Fehlerpfad (`view?.button?.tap()`)
- IMMER `XCTUnwrap` fuer optionale Elemente
- Tests muessen VOR Fix rot sein, NACH Fix gruen

| # | Test | Assertion |
|---|------|-----------|
| 1 | `testUeberfaelligBodyRowErreichbar` | Task mit `taskTitle_<id>` in Überfällig-Sektion ist via `waitForExistence` erreichbar; `XCTUnwrap` erzwingen |
| 2 | `testStackingBadgeErreichbar` | `stackingBadge_<id>` mit Label "x3" (oder konkretem Wert aus Seed-Daten) ist erreichbar |
| 3 | `testTierSektionBodyRowErreichbar` | Task in Dringend- oder Bald-Sektion (`taskTitle_<id>`) ist erreichbar |
| 4 | `testNextUpBleibtErreichbar` | Nach Fix: NextUp-Row (erste Task, bekannte ID aus Seed) weiterhin erreichbar — Negativ-Anker |

macOS-Tests: `FocusBloxMacUITests/MacBacklogSectionsA11yUITests.swift` (selbe 4 Tests, macOS-Adapter).

## Scope

**Enthalten:**
- `.accessibilityElement(children: .contain)` + `.accessibilityIdentifier(...)` auf betroffenen Sektionen (iOS + macOS)
- Ggf. Herauslösen des trailing `ForEach` aus `backlogRowWithSwipe` (nur Schritt 2)
- Neue UI-Test-Datei iOS + macOS

**Nicht enthalten:**
- Swipe-Gesten-Logik
- Pull-to-Refresh
- Sortierung/Filterung der Sektionen
- NextUp-Section (bereits korrekt)
- Andere Views (Settings, Coach, etc.)

## Betroffene Dateien

| Datei | Änderung | ~LoC |
|-------|----------|------|
| `Sources/Views/BacklogView.swift` | `.accessibilityElement` + `.accessibilityIdentifier` auf 3+ Sektionen; ggf. Schritt 2 backlogRowWithSwipe | +15 (Schritt 1), +20 (Schritt 2) |
| `FocusBloxMac/ContentView.swift` | `.accessibilityElement` + `.accessibilityIdentifier` auf 3+ macOS-Sektionen | +15 |
| `FocusBloxUITests/BacklogSectionsA11yUITests.swift` | Neue Datei, 4 Tests | +80 |
| `FocusBloxMacUITests/MacBacklogSectionsA11yUITests.swift` | Neue Datei, 4 Tests macOS | +80 |

Gesamt: ~210 LoC — innerhalb ±250 LoC Scope-Limit.

## Side Effects

Keine. Die List-Struktur, Swipe-Gesten, Sortierung und alle Service-Klassen bleiben unverändert. `.accessibilityElement(children: .contain)` ist ein reiner Accessibility-Overlay-Modifier ohne Layout-Einfluss.

## Risiko-Bewertung

**Niedrig.** Der Modifier ist nicht-destruktiv und kann jederzeit entfernt werden ohne Datenverlust oder Layout-Aenderung. Schritt 2 (ViewBuilder-Refactor) hat hoeheres Risiko (Swipe-Verhalten koennte sich aendern) und wird nur bei Bedarf umgesetzt.

## Changelog

- 2026-04-28: Initial spec created
