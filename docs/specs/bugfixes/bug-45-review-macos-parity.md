# Bug 45: macOS Review Tab - Feature Parity mit iOS

## Problem

macOS Review Tab zeigt deutlich weniger als iOS:
- Kein Completion Ring (% geschafft)
- Keine Offen/Blocks Stats
- Laedt keine FocusBlocks aus EventKit
- Wochen-View zeigt Kategorie nach Anzahl statt nach Zeit
- Keine FocusBlock-Karten im Tages-View

## Scope

Alles in einer Datei: `FocusBloxMac/MacReviewView.swift`

### 1. FocusBlocks laden
- Neuer `@State var blocks: [FocusBlock]` in MacReviewView
- `loadCalendarEvents()` erweitern um `fetchFocusBlocks()`
- `todayBlocks` und `weekBlocks` computed properties

### 2. Completion Ring + Stats (Daily + Weekly)
- Completion Ring Komponente (identisch zu iOS)
- Stats: Erledigt / Offen / Blocks
- Ersetzen der bisherigen StatCard-Zeile

### 3. Wochen-View: Zeit statt Anzahl
- Alten `CategoryStat` (count-basiert) + Chart + CategoryStatCard entfernen
- Durch `MacCategoryStat` + `MacCategoryBar` ersetzen (bereits vorhanden)
- Gleiche Logik wie im Tages-View

### 4. FocusBlock-Karten im Tages-View
- Block-Karten mit Titel, Zeitraum, Tasks pro Block
- Analog zur iOS `blockCard()` Methode

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `FocusBloxMac/MacReviewView.swift` | Komplett-Umbau DayReviewContent + WeekReviewContent |

## Testplan

- macOS Build erfolgreich
- Unit Tests gruen
- Visuell: Completion Ring + Kategorie-Balken in beiden Views
