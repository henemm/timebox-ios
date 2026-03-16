# Context: TD-05 Cross-Platform Code-Sharing Audit

## Request Summary
Systematischer Audit aller Views in `FocusBloxMac/` — welche haben ein iOS-Pendant mit (fast) identischer Logik und koennten nach `Sources/` konsolidiert werden?

## Bestandsaufnahme: 20 macOS-Dateien vs iOS-Pendants

### Kategorie A: HOHE Duplikation (>40%) — Konsolidierung lohnt sich

| macOS-Datei | iOS-Pendant | Duplikation | Einspar-Potenzial |
|-------------|-------------|-------------|-------------------|
| `MacReviewView.swift` (26KB) | `DailyReviewView.swift` | **75-80%** | ~300 LoC — Filter/Stats-Logik identisch |
| `MacAssignView.swift` (15KB) | `TaskAssignmentView.swift` | **60%** | ~280 LoC — Assignment-Logik identisch |
| `MacFocusView.swift` (35KB) | `FocusLiveView.swift` | **45%** | ~350 LoC — Timer/Progress/BlockEnd identisch |
| `MacCoachBacklogView.swift` (5KB) | `CoachBacklogView.swift` | **40%** | ~100 LoC — Intention-Filter identisch |
| `MacSettingsView.swift` (22KB) | `SettingsView.swift` | **60-70%** | ~200 LoC — AppStorage + Bindings identisch |

**Gesamt Kategorie A: ~1.230 LoC Duplikation eliminierbar**

### Kategorie B: MODERATE Duplikation (20-40%) — Teilweise konsolidierbar

| macOS-Datei | iOS-Pendant | Duplikation | Empfehlung |
|-------------|-------------|-------------|------------|
| `MacCoachReviewView.swift` (2KB) | `CoachMeinTagView.swift` | **30%** | DayProgressSection extrahieren (~20 LoC) |
| `MacTimelineView.swift` (27KB) | `TimelineView.swift` | **30%** | TimelineLayout bereits shared — Rest unterschiedlich |
| `MacPlanningView.swift` (24KB) | `PlanningView.swift` | **40-50%** | Service-Layer extrahieren (~150 LoC) |
| `MenuBarView.swift` (16KB) | — (kein Pendant) | **40%** | Focus-Block-State teilen mit FocusLiveView |

### Kategorie C: KEINE sinnvolle Konsolidierung

| macOS-Datei | Grund |
|-------------|-------|
| `ContentView.swift` (46KB) | Komplett andere Architektur (3-Spalten vs TabView-Wrapper) |
| `MacBacklogRow.swift` (11KB) | Zu unterschiedliche UI-Patterns (Menus vs Swipes/FlowLayout) |
| `TaskInspector.swift` (24KB) | macOS-only Sidebar-Panel, iOS nutzt Sheets |
| `SidebarView.swift` (5KB) | Rein macOS-Navigation |
| `QuickCapturePanel.swift` (6KB) | macOS-only (NSPanel, Global Hotkey) |
| `KeyboardShortcutsView.swift` (3KB) | Rein macOS |
| `ClickThroughView.swift` (2KB) | NSView-Workaround |
| `WindowAccessor.swift` (3KB) | NSWindow-Config |
| `MacTaskTransfer.swift` (1KB) | Nutzt LocalTask statt PlanItem |
| `MinimalTestApp.swift` (1KB) | Test-Hilfsdatei |

## Konsolidierungs-Plan: 5 Pakete

### Paket 1: FocusBlockState Manager (HOCH — 350 LoC)
**Betrifft:** MacFocusView + FocusLiveView + MenuBarView

Extrahieren nach `Sources/ViewModels/FocusBlockState.swift`:
- Timer-State (activeBlock, currentTime, taskStartTime)
- Progress-Berechnungen (calculateProgress, calculateTaskProgress)
- Block-End-Erkennung (checkBlockEnd)
- Task-Start-Tracking (trackTaskStart)
- FocusBlockActionService-Integration

### Paket 2: ReviewViewModel (HOCH — 300 LoC)
**Betrifft:** MacReviewView + DailyReviewView

Extrahieren nach `Sources/ViewModels/ReviewViewModel.swift`:
- Filter-Berechnungen (todayTasks, weekTasks, todayBlocks, weekBlocks)
- Stats-Berechnungen (completionPercentage, categoryStats)
- Planning-Accuracy-Logik
- Data-Loading (loadData async)

### Paket 3: AssignmentViewModel (HOCH — 280 LoC)
**Betrifft:** MacAssignView + TaskAssignmentView

Extrahieren nach `Sources/ViewModels/AssignmentViewModel.swift`:
- Block-Loading + Filtering
- Task-Assignment/Removal
- Task-Reordering
- Error-State
- Shared FocusBlockCard-Komponente

### Paket 4: SettingsService (MITTEL — 200 LoC)
**Betrifft:** MacSettingsView + SettingsView

Extrahieren:
- Time-Binding-Helpers → `Sources/ViewModels/SettingsBindings.swift`
- Data-Loading-Funktionen → `Sources/Services/SettingsService.swift`
- Shared Form-Sections (Coach, Notifications, Calendar)

### Paket 5: Coach Quick Wins (MITTEL — 120 LoC)
**Betrifft:** MacCoachBacklogView + CoachBacklogView + MacCoachReviewView + CoachMeinTagView

Extrahieren:
- Intention-Filter-Logik → `Sources/ViewModels/CoachBacklogViewModel.swift`
- MonsterIntentionHeader → `Sources/Views/Components/MonsterIntentionHeader.swift`
- DayProgressSection → `Sources/Views/Components/DayProgressSection.swift`

## Sofort-Massnahmen (Dead Code)

**MacBacklogRow.swift** hat 7 unbenutzte Callback-Parameter:
- `onImportanceCycle`, `onUrgencyToggle`, `onCategorySelect`, `onDurationSelect`
- `dependentCount`, `effectiveScore`, `effectiveTier`
→ Sofort entfernen (~20 LoC)

## Querschnitts-Problem: Data Model Divergenz

Die **groesste Huerde** fuer Code-Sharing ist die Model-Divergenz:
- macOS nutzt `LocalTask` (direkt SwiftData)
- iOS nutzt `PlanItem` (Sync-Wrapper)

Langfristige Optionen:
1. Shared `TaskProtocol` dem beide conformieren
2. Standardisierung auf ein Model (groesserer Umbau)

## Risiken & Ueberlegungen
- Konsolidierung muss schrittweise erfolgen (je Paket ein Ticket)
- Jedes Paket braucht eigene Tests (bestehende muessen weiter gruen sein)
- UI-Tests auf BEIDEN Plattformen validieren
- Model-Divergenz (LocalTask vs PlanItem) begrenzt Sharing-Tiefe
- Pakete 1-3 haben den hoechsten ROI und sollten priorisiert werden

## Abhaengigkeiten
- Upstream: Alle shared Models/Services in `Sources/`
- Downstream: Alle macOS-Views in `FocusBloxMac/`, alle iOS-Views in `Sources/Views/`
- Bestehende Tests: Unit + UI Tests beider Plattformen

## Bestehende Specs
- `docs/context/tech-debt-analysis.md` — TD-02 Detailanalyse
- `docs/specs/features/coach-views-backlog.md` — CoachBacklogView Spec
- `docs/specs/features/coach-views-meintag.md` — CoachMeinTagView Spec

---

## Analysis

### Type
Feature (Technical Debt Konsolidierung)

### Bestehende Shared-Infrastruktur (worauf wir aufbauen)
- **ReviewStatsCalculator** — bereits shared, wird von beiden Review-Views genutzt
- **FocusBlockActionService** — bereits shared enum (complete/skip Tasks)
- **AppSettings** — shared ObservableObject Singleton
- **EventKitRepositoryProtocol** — shared DI-Pattern
- **PlanItem.init(localTask:)** — Bruecke LocalTask → PlanItem existiert bereits!
- **`Sources/ViewModels/`** — Verzeichnis existiert NICHT, muss neu angelegt werden

### Strategische Bewertung

**Empfehlung: Paket 5 (Coach Quick Wins) ZUERST — als Pilot fuer das ViewModel-Pattern.**

Begruendung:
1. **Kleinstes Paket** (120 LoC) = geringstes Risiko
2. **Etabliert das neue Pattern** (`Sources/ViewModels/`) das alle anderen Pakete brauchen
3. **Coach-Views sind die neuesten** = wenigste Legacy-Abhaengigkeiten
4. **Sofort validierbar** mit bestehenden UI-Tests auf beiden Plattformen
5. Nach dem Pilot: Pakete 1-3 koennen das Pattern einfach uebernehmen

**Reihenfolge:**
1. Paket 5: Coach Quick Wins (Pilot, 120 LoC) — **dieses Ticket**
2. Paket 2: ReviewViewModel (300 LoC) — eigenes Ticket
3. Paket 1: FocusBlockState (350 LoC) — eigenes Ticket
4. Paket 3: AssignmentViewModel (280 LoC) — eigenes Ticket
5. Paket 4: SettingsService (200 LoC) — eigenes Ticket

### Scope fuer TD-05 (dieses Ticket): NUR der Audit + Paket 5

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/ViewModels/CoachBacklogViewModel.swift` | CREATE | Shared Intention-Filter-Logik |
| `Sources/Views/Components/MonsterIntentionHeader.swift` | CREATE | Shared Monster-Header Komponente |
| `Sources/Views/Components/DayProgressSection.swift` | CREATE | Shared Tages-Fortschritt Komponente |
| `FocusBloxMac/MacCoachBacklogView.swift` | MODIFY | Nutzt CoachBacklogViewModel + MonsterIntentionHeader |
| `Sources/Views/CoachBacklogView.swift` | MODIFY | Nutzt CoachBacklogViewModel + MonsterIntentionHeader |
| `FocusBloxMac/MacCoachReviewView.swift` | MODIFY | Nutzt DayProgressSection |
| `Sources/Views/CoachMeinTagView.swift` | MODIFY | Nutzt DayProgressSection |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | Dead-Code entfernen (7 unbenutzte Params) |

### Scope Assessment
- Files: 8 (3 CREATE + 5 MODIFY)
- Estimated LoC: +140/-120 (Netto: +20, aber ~120 LoC Duplikation eliminiert)
- Risk Level: LOW (Coach-Views sind isoliert, bestehende Tests validieren)

### Open Questions
- Keine — Analyse ist vollstaendig, Empfehlung steht
