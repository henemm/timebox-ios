# macOS Layout Debug - Systematischer Plan

## Problem
Timeline zeigt nur ~4 Stunden (06:00-10:00) statt 16 Stunden (06:00-22:00).
Der Content nimmt nur ~1/3 der verfügbaren Höhe ein.

## View-Hierarchie (von oben nach unten)

```
FocusBloxMacApp
└── ContentView
    └── NavigationSplitView
        ├── sidebar: SidebarView / List
        ├── content: mainContentView
        │   └── MacPlanningView
        │       └── HSplitView
        │           ├── timelineSection
        │           │   └── MacTimelineView
        │           │       └── GeometryReader
        │           │           └── ScrollView
        │           │               └── ZStack (.frame(height: 960))
        │           └── nextUpSection
        └── detail: inspectorView / EmptyView
```

## Debug-Schritt 1: ContentView Ebene

Frage: Bekommt `content:` den vollen Platz von NavigationSplitView?

```swift
} content: {
    mainContentView
        .border(.yellow, width: 8)  // DEBUG
}
```

## Debug-Schritt 2: MacPlanningView Ebene

Frage: Bekommt HSplitView den vollen Platz?

```swift
HSplitView { ... }
    .border(.cyan, width: 6)  // DEBUG
```

## Debug-Schritt 3: timelineSection Ebene

Frage: Bekommt timelineSection den vollen Platz von HSplitView?

```swift
timelineSection
    .border(.orange, width: 5)  // DEBUG
```

## Debug-Schritt 4: MacTimelineView Ebene

Frage: Füllt MacTimelineView den timelineSection-Bereich?

```swift
// In MacTimelineView body:
GeometryReader { ... }
    .border(.red, width: 3)  // DEBUG: GeometryReader

ScrollView { ... }
    .border(.blue, width: 3)  // DEBUG: ScrollView

ZStack { ... }
    .border(.green, width: 3)  // DEBUG: ZStack (sollte 960px hoch sein)
```

## Erwartete Ergebnisse

- Gelb (content): Sollte fast ganzes Fenster füllen (minus Sidebar)
- Cyan (HSplitView): Sollte = Gelb sein
- Orange (timelineSection): Sollte linke Seite der HSplitView füllen
- Rot (GeometryReader): Sollte = Orange sein
- Blau (ScrollView): Sollte = Rot sein
- Grün (ZStack): Sollte 960px hoch sein

## Bisherige Debug-Ergebnisse (2026-02-03)

| Ebene | Beobachtung | Screenshot |
|-------|-------------|------------|
| Lila (MacTimelineView äußerste) | ZU KLEIN - nur ~1/3 Höhe | ✓ |
| Orange (timelineSection) | ZU KLEIN - gleich wie Lila | ✓ |
| Cyan (HSplitView) | ZU KLEIN - gleich wie Orange | ✓ |
| Gelb (content) | **AKTUELL TESTEN** | - |

## Lösung gefunden! (2026-02-03)

### Root Cause
`nextUpSection` (VStack) hatte keine explizite Höhe. In HSplitView bestimmt die View mit der kleineren intrinsischen Höhe die Gesamthöhe.

### Fix
```swift
nextUpSection
    .frame(minWidth: 250, maxWidth: 350, maxHeight: .infinity)  // ← maxHeight hinzugefügt
```

### Systematische Tests die zum Fix führten

| Test | Konfiguration | Ergebnis |
|------|---------------|----------|
| 1 | HSplitView { Color.red; Color.blue } | ✅ Volle Höhe |
| 2 | + GeometryReader | ✅ Volle Höhe (871px) |
| 3 | + ScrollView | ✅ Volle Höhe |
| 4 | + VStack | ✅ Volle Höhe |
| 5 | + if/else conditional | ✅ Volle Höhe |
| 6 | Echte timelineSection alleine | ✅ Volle Höhe |
| 7 | + nextUpSection | ❌ Nur 1/3 Höhe |
| 8 | + maxHeight: .infinity | ✅ Volle Höhe |

### Geänderte Dateien
- `FocusBloxMac/MacPlanningView.swift` - `.frame(maxHeight: .infinity)` hinzugefügt
