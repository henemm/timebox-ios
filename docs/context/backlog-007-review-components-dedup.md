# Context: BACKLOG-007 Review-Komponenten Deduplizierung

## Request Summary
Duplizierte Review-Komponenten (StatItem, CategoryBar, AccuracyPill, CategoryStat) vereinheitlichen. `ReviewComponents.swift` existiert bereits als Shared-File, ist aber NICHT im Xcode-Projekt registriert.

## Key Finding
`Sources/Views/ReviewComponents.swift` enthaelt bereits die shared Versionen aller Komponenten:
- `CategoryStat` (struct)
- `StatItem` (View)
- `CategoryBar` (View)
- `AccuracyPill` (View)
- Diverse Drill-Down Sheets

**ABER: Die Datei ist nicht im Xcode-Projekt!** Deshalb existieren ueberall noch Duplikate.

## Duplikate-Map

### 1. StatItem (identisch, 3 Kopien)
| File | Definition | Status |
|------|-----------|--------|
| `Sources/Views/ReviewComponents.swift:69` | `StatItem` | SHARED (nicht im Projekt!) |
| `Sources/Views/SprintReviewSheet.swift:333` | `StatItem` | DUPLIKAT |
| `FocusBloxMac/MacFocusView.swift:843` | `MacStatItem` | DUPLIKAT (identisch) |

Nutzung MacStatItem: `MacFocusView.swift:703-706`, `MacReviewView.swift:328-334,562-568`

### 2. AccuracyPill (identisch, 3 Kopien)
| File | Definition | Status |
|------|-----------|--------|
| `Sources/Views/ReviewComponents.swift:136` | `AccuracyPill` (struct) | SHARED |
| `Sources/Views/DailyReviewView.swift:395` | `accuracyPill()` (private func) | DUPLIKAT |
| `FocusBloxMac/MacReviewView.swift:281` | `macAccuracyPill()` (private func) | DUPLIKAT |

### 3. CategoryStat (teilweise unterschiedlich)
| File | Definition | Datentyp |
|------|-----------|----------|
| `Sources/Views/ReviewComponents.swift:6` | `CategoryStat` mit `config: TaskCategory` | Shared |
| `Sources/Views/DailyReviewView.swift:14` | `CategoryStat` mit `config: CategoryConfig` | DUPLIKAT (leicht anders!) |
| `FocusBloxMac/MacReviewView.swift:682` | `MacCategoryStat` mit `category: String` | ANDERS |

### 4. CategoryBar (fast identisch)
| File | Definition | Nutzt |
|------|-----------|-------|
| `Sources/Views/ReviewComponents.swift:87` | `CategoryBar` | `CategoryStat` |
| `Sources/Views/DailyReviewView.swift:599` | `CategoryBar` | `CategoryStat` |
| `FocusBloxMac/MacReviewView.swift:711` | `MacCategoryBar` | `MacCategoryStat` |

## Dependencies
- Upstream: `TaskCategory`, `CategoryConfig`, `PlanItem`, `FocusBlock`, `CalendarEvent`
- Downstream: `DailyReviewView`, `SprintReviewSheet`, `MacReviewView`, `MacFocusView`

## Risks & Considerations
- `ReviewComponents.swift` muss fuer BEIDE Targets registriert werden
- `CategoryConfig` ist nur `typealias CategoryConfig = TaskCategory` → kompatibel!
- `MacCategoryStat` nutzt `category: String` → Umstellung auf `TaskCategory.allCases` wie iOS
- Scope ist groesser als im BACKLOG geschaetzt

## Analysis

### Type
Refactoring (Deduplizierung)

### Technischer Ansatz
1. `ReviewComponents.swift` fuer BEIDE Targets im Xcode-Projekt registrieren
2. `typealias CategoryConfig = TaskCategory` aus DailyReviewView entfernen (ReviewComponents nutzt direkt TaskCategory)
3. Duplikate entfernen:
   - `CategoryStat` aus `DailyReviewView.swift` (nutzt shared Version)
   - `CategoryBar` aus `DailyReviewView.swift` (nutzt shared Version)
   - `accuracyPill()` func aus `DailyReviewView.swift` → `AccuracyPill()` struct
   - `StatItem` aus `SprintReviewSheet.swift` (nutzt shared Version)
   - `MacStatItem` aus `MacFocusView.swift` → `StatItem`
   - `MacCategoryStat` aus `MacReviewView.swift` → `CategoryStat`
   - `MacCategoryBar` aus `MacReviewView.swift` → `CategoryBar`
   - `macAccuracyPill()` func aus `MacReviewView.swift` → `AccuracyPill()` struct
4. macOS Stats-Erstellung umstellen: `TaskCategory.allCases.compactMap` statt String-basiert

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBlox.xcodeproj/project.pbxproj` | MODIFY | ReviewComponents.swift fuer beide Targets registrieren |
| `Sources/Views/DailyReviewView.swift` | MODIFY | CategoryStat, CategoryBar, accuracyPill, typealias entfernen |
| `Sources/Views/SprintReviewSheet.swift` | MODIFY | StatItem-Duplikat entfernen |
| `FocusBloxMac/MacFocusView.swift` | MODIFY | MacStatItem entfernen, StatItem nutzen |
| `FocusBloxMac/MacReviewView.swift` | MODIFY | MacCategoryStat, MacCategoryBar, macAccuracyPill entfernen, shared Versionen nutzen |

### Scope Assessment
- Files: 5
- Estimated LoC: +5 / -130 (netto ~-125)
- Risk Level: MEDIUM (Datentyp-Umstellung in macOS)

### Reihenfolge
1. ReviewComponents.swift ins Projekt (beide Targets)
2. iOS: Duplikate entfernen (DailyReviewView, SprintReviewSheet)
3. macOS: MacStatItem → StatItem (einfach, identisch)
4. macOS: MacCategoryStat/MacCategoryBar → CategoryStat/CategoryBar (braucht Umstellung)
5. Build beider Targets verifizieren
