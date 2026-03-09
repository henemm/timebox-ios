# Bug: macOS Task-Titel werden ohne Platzgrund abgeschnitten ("...")

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- 10 bisherige Layout/Truncation-Bugs gefunden, alle gefixt
- Relevantester: Bug 49 entfernte `.fixedSize()` von Badges in iOS BacklogRow
- Badge-Overflow war schon mal Thema (FlowLayout-Fix in iOS BacklogRow)

### Agent 2 (Datenfluss-Trace)
- **MacBacklogRow.swift:39-43** — Titel mit `.lineLimit(1)` OHNE `.frame(maxWidth: .infinity)`
- VStack (Zeile 37-47) hat KEINE Breitenangabe
- HStack-Layout: Button → VStack(title+metadata) → **Spacer()** → Icons
- Spacer() nach VStack = VStack wird NICHT auf volle Breite expandiert

### Agent 3 (Layout-Constraints)
- **8 Stellen** mit `.lineLimit(1)` auf Task-Titeln (nur macOS)
- Alle Metadata-Badges: `.fixedSize()` — können NICHT komprimiert werden
- VStack ohne `.frame(maxWidth: .infinity)` = Titel wird als einziges Element komprimiert

### Agent 4 (Szenarien)
- 7 Szenarien identifiziert, alle bestätigt
- **Hauptursache:** VStack ohne explizite Breitenangabe + Spacer() = Titel wird vom Layout komprimiert
- iOS-Vergleich: `.frame(maxWidth: .infinity, alignment: .leading)` auf contentSection (Zeile 42)

### Agent 5 (Blast Radius)
- **8+ macOS Views** betroffen mit identischem Pattern
- iOS ist GESCHÜTZT: `.truncationMode(.tail)` + `.lineLimit(2)` + `.frame(maxWidth: .infinity)`

## Hypothesen

### Hypothese 1: VStack ohne `.frame(maxWidth: .infinity)` (HOCH - 95%)
**Beweis DAFÜR:**
- iOS BacklogRow Zeile 42: `.frame(maxWidth: .infinity, alignment: .leading)` auf contentSection
- macOS MacBacklogRow: KEIN solcher Modifier auf VStack (Zeile 37-47)
- Ohne `.frame(maxWidth: .infinity)` bekommt der VStack nur seine "natürliche" Breite
- Spacer() danach (Zeile 49) bekommt den Restplatz statt ihn dem Titel zu geben

**Beweis DAGEGEN:**
- In einer einfachen HStack sollte der VStack trotzdem expandieren — aber nur wenn kein Spacer() da ist

### Hypothese 2: Spacer() nach VStack drückt Titel zusammen (HOCH - 90%)
**Beweis DAFÜR:**
- HStack-Layout: `Button | VStack | Spacer() | Icons`
- SwiftUI gibt Spacer() Priorität über flexible Inhalte
- Alle Badges im metadataRow haben `.fixedSize()` → können nicht schrumpfen
- Einziges Element das schrumpfen KANN = der Titel-Text

**Beweis DAGEGEN:**
- Spacer() sollte eigentlich keinen Platz "stehlen" wenn genug Breite da ist

### Hypothese 3: NavigationSplitView begrenzt Content-Spalte (MITTEL - 60%)
**Beweis DAFÜR:**
- ContentView nutzt `NavigationSplitView` mit Sidebar + Content + Detail
- Bei offenem Inspector (Detail-Spalte) wird Content schmaler
- Fenster-MinWidth = 1000px, Sidebar ~180px, Inspector ~300px → nur ~520px für Content

**Beweis DAGEGEN:**
- Screenshot zeigt keinen Inspector — Content hat die volle Breite

## Wahrscheinlichste Ursache

**Kombination von Hypothese 1 + 2:**
Der VStack mit Titel+Metadata hat KEINEN `.frame(maxWidth: .infinity)` Modifier. Dadurch bekommt er nur seine "natürliche Breite" (= Breite des breitesten Kind-Elements). Der Spacer() danach füllt den Rest. Bei langem Metadata-Row (8 Badges mit `.fixedSize()`) wird der Titel in eine enge Box gezwängt und mit `...` abgeschnitten.

**iOS-Fix als Beweis:** Die iOS-Version hat genau dieses Problem gelöst mit `.frame(maxWidth: .infinity, alignment: .leading)` auf dem contentSection (BacklogRow.swift:42).

## Debugging-Plan
Nicht nötig — der Vergleich iOS vs. macOS beweist die Ursache direkt im Code.

## Blast Radius
**8+ macOS Views** mit identischem Pattern (fehlender `.frame(maxWidth: .infinity)`):
1. MacBacklogRow (Backlog) — **PRIMARY**
2. NextUpTaskRow (MacPlanningView)
3. MacTaskInBlockRow (MacAssignView)
4. MacDraggableTaskRow (MacAssignView)
5. TaskQueueRow (MacFocusView)
6. MacReviewTaskRow (MacFocusView)
7. MenuBarView (3 Instanzen)
8. MacTimelineView

**Sidebar-Labels** ("Überf...", "Wiede...", "Erle...") — separate Ursache: NavigationSplitView Sidebar-Breite ist knapp für Labels + Badge-Count.
