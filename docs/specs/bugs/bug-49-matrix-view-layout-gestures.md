---
entity_id: bug_49_matrix_view
type: bugfix
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [ios, matrix, eisenhower, layout, gestures]
---

# Bug 49: Matrix View - Swipe-Gesten + Layout zu breit (iOS)

## Approval

- [ ] Approved

## Purpose

Zwei Probleme in der Eisenhower Matrix Ansicht auf iOS beheben:
1. Swipe-Gesten (Next Up, Bearbeiten, Loeschen) funktionieren nicht
2. View ist zu breit - Inhalt geht ueber den Bildschirmrand hinaus

## Source

- **File:** `Sources/Views/BacklogView.swift`
- **Lines:** 593-669 (eisenhowerMatrixView), 948-1027 (QuadrantCard)
- **Sekundaer:** `Sources/Views/BacklogRow.swift` (Metadata-Layout)

## Root Cause Analyse

### Problem 1: Swipe-Gesten fehlen

**Ursache:** Architektur-bedingt. `.swipeActions()` ist ein `List`-only Modifier.

- **List View** (Zeile 541-590): Nutzt `List { ForEach { BacklogRow.swipeActions() } }` - funktioniert
- **Matrix View** (Zeile 593-669): Nutzt `ScrollView { VStack { QuadrantCard { ForEach { BacklogRow } } } }` - `.swipeActions()` ist hier **nicht moeglich**

Die Swipe-Aktionen wurden bei der Matrix-Implementierung nie hinzugefuegt, weil der technische Ansatz (ScrollView statt List) sie nicht unterstuetzt.

### Problem 2: Layout zu breit

**Ursache:** Metadata-Badges in BacklogRow ueberlaufen.

In `BacklogRow.swift` hat die `metadataRow` (Zeile 124-167) eine HStack mit bis zu 6 Badges, die ALLE `.fixedSize()` haben:
- `importanceBadge` (Zeile 189)
- `urgencyBadge` (Zeile 240)
- `categoryBadge` (Zeile 283)
- Tags mit `.fixedSize()` (Zeile 142, 150)
- `durationBadge` (Zeile 336)
- Due Date Badge (Zeile 164)

Wenn alle Badges gleichzeitig sichtbar sind, uebersteigt die HStack-Breite den verfuegbaren Platz innerhalb der QuadrantCard. Da kein `.clipped()` oder flexibles Wrapping vorhanden ist, drueckt der Overflow die gesamte View breiter.

Verstaerkend: QuadrantCard hat nur `.padding(.horizontal, 8)` auf den Rows (Zeile 1006), was wenig Spielraum laesst.

## Fix-Strategie

### Fix 1: Context Menu statt Swipe-Gesten

`.contextMenu` auf BacklogRow innerhalb der QuadrantCards hinzufuegen. Gleiche Aktionen wie die Swipe-Gesten:

**Aktionen:**
- "Next Up" (Swipe Leading = `arrow.up.circle.fill`, gruen)
- "Bearbeiten" (Swipe Trailing = `pencil`, blau)
- "Loeschen" (Swipe Trailing = `trash`, rot/destructive)

**Wo:** In `QuadrantCard` body, auf die `BacklogRow` innerhalb des `ForEach` (Zeile 993-1006).

**Warum Context Menu statt Custom Swipe:**
- Standard macOS/iOS Pattern fuer Nicht-List-Views
- Kein Konflikt mit ScrollView-Scroll-Geste
- Things 3, Todoist nutzen das gleiche Pattern in Kartenansichten
- Deutlich weniger Code als custom DragGesture

### Fix 2: Metadata-HStack Overflow verhindern

Zwei Aenderungen in `BacklogRow.swift`:

**A)** `.fixedSize()` von Badges entfernen die komprimierbar sind:
- Category Badge Label (`Text(categoryLabel)`) - kann truncaten
- Tags - koennen truncaten
- Due Date Text - kann truncaten

**B)** Auf der `metadataRow` HStack `.clipped()` hinzufuegen als Sicherheitsnetz, damit Overflow nie die Parent-View verbreitert.

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `Sources/Views/BacklogView.swift` | `.contextMenu` auf QuadrantCard-Rows (Zeile ~993-1006) |
| `Sources/Views/BacklogRow.swift` | `.fixedSize()` anpassen + `.clipped()` auf metadataRow |

**Geschaetzter Aufwand:** ~45 LoC, 2 Dateien - innerhalb Scoping-Limits.

## Expected Behavior

### Nach Fix 1 (Context Menu):
- Long-Press auf Task-Row in Matrix-Quadrant zeigt Context Menu
- Menu enthaelt: "Next Up", "Bearbeiten", "Loeschen"
- Aktionen verhalten sich identisch zu den Swipe-Aktionen in der List-View

### Nach Fix 2 (Layout):
- Matrix View hat sichtbare Raender links und rechts (~16pt)
- Metadata-Badges werden bei Platzmangel abgeschnitten statt die View zu verbreitern
- Kein horizontaler Overflow mehr sichtbar

## Akzeptanzkriterien

1. Long-Press auf Task in Matrix zeigt Context Menu mit 3 Aktionen
2. "Next Up" Aktion verschiebt Task in Next Up Section
3. "Bearbeiten" oeffnet Edit-Dialog
4. "Loeschen" entfernt Task
5. Matrix View hat korrekte horizontale Raender (kein Overflow)
6. Metadata-Badges truncaten statt zu ueberlaufen
7. Bestehende Swipe-Gesten in List-View funktionieren weiterhin

## Known Limitations

- Context Menu ist kein 1:1 Ersatz fuer Swipe-Gesten (erfordert Long-Press statt Wisch)
- Full-Swipe-to-action (schnelles Durchswipen) ist im Context Menu nicht moeglich

## Changelog

- 2026-02-13: Initial spec created (Root Cause Analyse + Fix-Strategie)
