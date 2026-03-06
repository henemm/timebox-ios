# Context: TD-02 iOS/macOS View-Duplikation

## Request Summary
Tech Debt TD-02: ~7.700 LoC in FocusBloxMac/ — davon ~1.800 LoC identische/nahezu-identische Logik zu Sources/Views/. Ziel: Duplikation reduzieren ohne macOS-spezifische Layouts zu verlieren.

## Analysis

### Type
Feature (Refactoring / Tech Debt Reduction)

### Tiefenanalyse: Was ist WIRKLICH dupliziert?

Die Detailanalyse zeigt ein differenzierteres Bild als die Oberflaechen-Schaetzung:

#### Duplikation Tier 1: BADGE-RENDERING (~300 LoC, 7 identische Badges)
- Importance-Badge: MacBacklogRow L171-198 vs BacklogRow L230-263
- Urgency-Badge: MacBacklogRow L202-235 vs BacklogRow L275-318
- Priority-Badge: MacBacklogRow L288-310 vs BacklogRow L359-381
- Duration-Badge: MacBacklogRow L318-340 vs BacklogRow L398-422
- Category-Badge, Tags-Badge, Recurrence-Badge: jeweils dupliziert
- **100% identische Logik, 0% plattform-spezifisch**

#### Duplikation Tier 2: SHEETS (~130 LoC, 55-70% identisch)
- CreateFocusBlockSheet: 71 (iOS) + 59 (macOS) = 130 LoC, ~40 LoC identisch
- EventCategorySheet: 61 (iOS) + 74 (macOS) = 135 LoC, ~35 LoC identisch
- **Logik identisch, Container plattform-spezifisch (Sheet vs Frame)**

#### Duplikation Tier 3: ROW-LAYOUT (~200 LoC, 60% identisch)
- Zeilen-Layout (HStack, Titel, Badges) ist aehnlich
- **ABER:** Callbacks sind fundamental verschieden:
  - iOS: Signal-Callbacks (kein Payload), Parent fetcht + mutiert
  - macOS: Direkte-Mutation-Callbacks, Parent injiziert Logik inline
  - Category/Duration: iOS = Modal Sheet, macOS = Dropdown Menu
  - Edit/Delete: iOS = Row-Buttons, macOS = Selection + Inspector
- **Row-Unification ist NICHT trivial wegen Callback-Divergenz**

#### Duplikation Tier 4: ARCHITEKTUR-VIEWS (~600 LoC, NICHT teilbar)
- ContentView (macOS) vs BacklogView (iOS): 3-Column vs Single-Column
- MacAssignView vs TaskAssignmentView: HSplitView vs VStack
- MacPlanningView vs BlockPlanningView: HSplitView vs ScrollView+Tabs
- FocusBlockCard: iOS nutzt custom D&D, macOS nutzt List+onMove (13% gemeinsam)
- **Plattform-bedingte Divergenz, kein sinnvolles Sharing moeglich**

### Realistisches Einsparpotenzial

| Bereich | Aktuelle LoC | Einsparung | Risiko |
|---------|-------------|------------|--------|
| Badge-Komponenten extrahieren | ~600 (beide) | ~250-300 | NIEDRIG |
| CreateFocusBlockSheet unifizieren | 130 | ~35 | NIEDRIG |
| EventCategorySheet unifizieren | 135 | ~30 | NIEDRIG |
| FocusBlockCard Header | 260 | ~15 | MINIMAL |
| **Summe realistisch** | | **~330-380 LoC** | |

### Was sich NICHT lohnt (hoher Aufwand, geringer Gewinn)

| Bereich | Warum nicht |
|---------|-------------|
| BacklogRow unifizieren (Protocol) | Callbacks fundamental verschieden (Modal vs Menu, Signal vs Direct-Mutation). Protocol loest nur die Property-Seite, nicht die Interaktions-Seite. |
| ContentView/BacklogView mergen | Komplett verschiedene Layouts (3-Column vs Single-Column). Nur Filtering-Logik ist gleich, aber die ist ~50 LoC — nicht genug fuer Abstraktion. |
| FocusBlockCard mergen | 13% gemeinsam. iOS: custom D&D. macOS: List+onMove. Erzwungene Unification = mehr Code, nicht weniger. |

### Revidierte Empfehlung

**Strategie B (Bottom-Up Components) ist richtig. Strategie A (Protocol) lohnt sich NICHT.**

Warum Protocol sich nicht lohnt:
1. Properties sind kompatibel (25+ identische) — das ist einfach
2. Callbacks sind INKOMPATIBEL — das ist das eigentliche Problem
3. Category: iOS = Sheet-Callback, macOS = Menu-Inline → nicht abstrahierbar
4. Duration: iOS = Sheet-Callback, macOS = Menu-Inline → nicht abstrahierbar
5. Edit/Delete: iOS = Row-Buttons, macOS = Selection+Inspector → nicht abstrahierbar
6. Ein Protocol fuer Properties + Generics fuer 5 verschiedene Callback-Signaturen = mehr Komplexitaet, nicht weniger

### Scope: 3 Arbeitspakete

**Paket 1: Shared Badges (groesster Hebel, geringstes Risiko)**
- 7 Badge-Views in `Sources/Views/Components/TaskBadges.swift` extrahieren
- Beide Rows importieren statt duplizieren
- ~250-300 LoC Einsparung
- 0 Verhaltens-Aenderung

**Paket 2: Sheet-Unification (mittlerer Hebel)**
- `CreateFocusBlockSheetContent` (shared Logik) + plattform-spezifische Wrapper
- `EventCategorySheetContent` (shared Logik) + plattform-spezifische Wrapper
- ~65 LoC Einsparung
- 0 Verhaltens-Aenderung

**Paket 3: FocusBlockCard Header (kleiner Hebel)**
- Shared `FocusBlockCardHeader` View (~15 LoC)
- Optional, geringstes ROI

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| Sources/Views/Components/TaskBadges.swift | CREATE | 7 Shared Badge-Views |
| Sources/Views/BacklogRow.swift | MODIFY | Import TaskBadges statt inline |
| FocusBloxMac/MacBacklogRow.swift | MODIFY | Import TaskBadges statt inline |
| Sources/Views/BlockPlanningView.swift | MODIFY | Sheet-Content extrahieren |
| FocusBloxMac/MacPlanningView.swift | MODIFY | Shared Sheet-Content nutzen |
| FocusBloxTests/TaskBadgesTests.swift | CREATE | Tests fuer Badge-Rendering |

### Scope Assessment
- Files: 6 (2 CREATE, 4 MODIFY)
- Estimated LoC: +150 (neue Dateien) / -480 (entfernter Duplikat-Code) = **netto -330 LoC**
- Risk Level: LOW (reine View-Extraktion, keine Logik-Aenderung)

### Dependencies
- Upstream: TaskPriorityScoringService (fuer Priority-Badge), TaskCategory (fuer Category-Badge)
- Downstream: BacklogRow, MacBacklogRow, BlockPlanningView, MacPlanningView

### Open Questions
- Keine — Scope ist klar, Ansatz ist konservativ
