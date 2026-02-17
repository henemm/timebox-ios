# Aenderung: Einheitliche Navigation-Labels und Icons (iOS + macOS)

## Zusammenfassung

Tab-Bar (iOS) und Sidebar-Sections (macOS) nutzen unterschiedliche Labels und Icons fuer dieselben 5 Sections. Angleichen auf einheitliche Werte und das `MainSection` Enum als Shared Code in `Sources/` bereitstellen.

---

## Ist-Zustand

### iOS (`Sources/Views/MainTabView.swift`)

Labels und Icons sind direkt als String-Literale in `.tabItem` hardcodiert:

```swift
Label("Backlog", systemImage: "list.bullet")
Label("Blöcke", systemImage: "rectangle.split.3x1")
Label("Zuordnen", systemImage: "arrow.up.and.down.text.horizontal")
Label("Fokus", systemImage: "target")
Label("Rückblick", systemImage: "clock.arrow.circlepath")
```

### macOS (`FocusBloxMac/SidebarView.swift`)

Labels und Icons sind in einem `MainSection` Enum definiert:

```swift
enum MainSection: String, Hashable, CaseIterable {
    case backlog = "Backlog"       // tray.full
    case planning = "Planen"       // calendar
    case assign = "Zuweisen"       // arrow.up.arrow.down
    case focus = "Focus"           // target
    case review = "Review"         // chart.bar
}
```

### Delta-Tabelle

| Section | iOS Label | iOS Icon | macOS Label | macOS Icon | Unterschied |
|---------|-----------|----------|-------------|------------|-------------|
| Tasks | Backlog | `list.bullet` | Backlog | `tray.full` | Icon |
| Zeitplanung | Bloecke | `rectangle.split.3x1` | Planen | `calendar` | Label + Icon |
| Zuordnung | Zuordnen | `arrow.up.and.down.text.horizontal` | Zuweisen | `arrow.up.arrow.down` | Label + Icon |
| Timer | Fokus | `target` | Focus | `target` | Label (deutsch/englisch) |
| Statistik | Rueckblick | `clock.arrow.circlepath` | Review | `chart.bar` | Label + Icon |

**4 von 5 Labels unterschiedlich, 4 von 5 Icons unterschiedlich.**

---

## Soll-Zustand

### Einheitliche Werte (beide Plattformen)

| Section | Label | Icon | Begruendung |
|---------|-------|------|-------------|
| Tasks | **Backlog** | `list.bullet` | Beide nutzen bereits "Backlog"; `list.bullet` ist als Listen-Icon klarer |
| Zeitplanung | **Planen** | `calendar` | "Planen" beschreibt die Aktion besser als "Bloecke"; Kalender-Icon passt zur Timeline |
| Zuordnung | **Zuordnen** | `arrow.up.and.down.text.horizontal` | Kuerzeres Label; spezifischeres Icon |
| Timer | **Fokus** | `target` | Deutsch einheitlich (statt englisch "Focus"); Icon bereits identisch |
| Statistik | **Rueckblick** | `chart.bar` | Deutsch einheitlich (statt englisch "Review"); `chart.bar` ist als Statistik-Icon klarer |

### Shared Enum in Sources/

`MainSection` Enum aus `SidebarView.swift` nach `Sources/Models/MainSection.swift` verschieben:

```swift
import Foundation

/// Unified navigation sections for iOS and macOS
enum MainSection: String, Hashable, CaseIterable {
    case backlog = "Backlog"
    case planning = "Planen"
    case assign = "Zuordnen"
    case focus = "Fokus"
    case review = "Rückblick"

    var icon: String {
        switch self {
        case .backlog: return "list.bullet"
        case .planning: return "calendar"
        case .assign: return "arrow.up.and.down.text.horizontal"
        case .focus: return "target"
        case .review: return "chart.bar"
        }
    }
}
```

### iOS MainTabView nutzt das Enum

```swift
TabView {
    BacklogView()
        .tabItem { Label(MainSection.backlog.rawValue, systemImage: MainSection.backlog.icon) }
    BlockPlanningView()
        .tabItem { Label(MainSection.planning.rawValue, systemImage: MainSection.planning.icon) }
    // ...
}
```

### macOS SidebarView importiert aus Sources/

Entfernt die lokale `MainSection` Definition und nutzt die Shared-Version.

---

## Technischer Plan

### Dateien (3 Dateien, ~20 LoC netto)

| Datei | Aenderung | LoC |
|-------|-----------|-----|
| `Sources/Models/MainSection.swift` | **NEU** - Shared Enum mit Labels + Icons | ~18 LoC |
| `Sources/Views/MainTabView.swift` | Labels/Icons durch `MainSection` Enum ersetzen | ~5 LoC (netto 0, Umbau) |
| `FocusBloxMac/SidebarView.swift` | Lokales `MainSection` Enum entfernen, Shared-Version nutzen | ~-15 LoC (Entfernung) |

### Netto-Ergebnis

- **+18 LoC** (neues Shared Enum)
- **-15 LoC** (entferntes Duplikat in SidebarView)
- **~5 LoC** Umbau in MainTabView
- **= ~8 LoC netto**
- **1 Duplikat weniger** im Codebase

---

## Abgrenzung (Out of Scope)

- Keine Aenderung an der Navigation-Struktur selbst (Tabs, Sidebar-Filter bleiben)
- Keine Aenderung an Views oder Funktionalitaet
- Keine neuen Views oder Screens
- Keine Lokalisierung (Labels bleiben deutsch)
- SidebarFilter Enum bleibt in SidebarView.swift (nur macOS-spezifisch)

---

## Acceptance Criteria

1. iOS Tab-Bar zeigt: Backlog, Planen, Zuordnen, Fokus, Rueckblick
2. macOS Sidebar zeigt: Backlog, Planen, Zuordnen, Fokus, Rueckblick
3. Icons sind auf beiden Plattformen identisch (list.bullet, calendar, arrow.up.and.down.text.horizontal, target, chart.bar)
4. `MainSection` Enum liegt in `Sources/Models/` (Shared Code)
5. Kein dupliziertes Enum in `FocusBloxMac/SidebarView.swift`
6. Build erfolgreich auf iOS und macOS

---

## Geschaetzter Aufwand

**KLEIN** (~10k Tokens, 3 Dateien, ~8 LoC netto)

Reines Refactoring: Enum verschieben, String-Literale durch Enum-Referenzen ersetzen. Keine Logik-Aenderung.
