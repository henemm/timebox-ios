---
entity_id: review_components_dedup
type: refactoring
created: 2026-02-13
updated: 2026-02-13
status: draft
version: "1.0"
tags: [backlog-007, deduplication, cross-platform, review]
---

# Review-Komponenten Deduplizierung (BACKLOG-007)

## Approval

- [ ] Approved

## Purpose

Duplizierte Review-Komponenten (StatItem, CategoryBar, AccuracyPill, CategoryStat) vereinheitlichen. `Sources/Views/ReviewComponents.swift` enthaelt bereits alle shared Versionen, ist aber nicht im Xcode-Projekt registriert. Duplikate in 4 Dateien muessen entfernt und durch die shared Versionen ersetzt werden.

## Source

- **File:** `Sources/Views/ReviewComponents.swift` (existiert, muss registriert werden)
- **Shared Components:** `CategoryStat`, `StatItem`, `CategoryBar`, `AccuracyPill`

### Duplikate (werden entfernt)

**iOS:**
- `DailyReviewView.swift:11` - `typealias CategoryConfig = TaskCategory`
- `DailyReviewView.swift:14-18` - `CategoryStat` (nutzt `CategoryConfig` = `TaskCategory`)
- `DailyReviewView.swift:395-407` - `accuracyPill()` private func
- `DailyReviewView.swift:599-647` - `CategoryBar` struct
- `SprintReviewSheet.swift:333-348` - `StatItem` struct

**macOS:**
- `MacFocusView.swift:843-858` - `MacStatItem` (identisch zu `StatItem`)
- `MacReviewView.swift:281-293` - `macAccuracyPill()` private func
- `MacReviewView.swift:682-707` - `MacCategoryStat` (String-basiert, muss umgestellt werden)
- `MacReviewView.swift:711-748` - `MacCategoryBar` (nutzt `MacCategoryStat`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| TaskCategory | Model | Kategorie-Enum mit displayName, color, icon |
| PlanItem | Model | Task-Daten fuer Drill-Down Sheets |
| FocusBlock | Model | Block-Daten fuer Drill-Down Sheets |
| ReviewStatsCalculator | Service | Berechnet Kategorie-Minuten |

## Implementation Details

### Schritt 1: ReviewComponents.swift registrieren
- Datei fuer iOS-Target (FocusBlox) und macOS-Target (FocusBloxMac) im pbxproj registrieren
- Build beider Targets verifizieren (Compile-Fehler wegen doppelter Definitionen erwartet)

### Schritt 2: iOS-Duplikate entfernen
- `DailyReviewView.swift`: `typealias CategoryConfig`, `CategoryStat`, `CategoryBar` entfernen
- `DailyReviewView.swift`: `accuracyPill()` func durch `AccuracyPill()` struct ersetzen (3 Aufrufstellen)
- `SprintReviewSheet.swift`: `StatItem` entfernen

### Schritt 3: macOS einfache Duplikate entfernen
- `MacFocusView.swift`: `MacStatItem` entfernen → `StatItem` nutzen (4 Aufrufstellen)
- `MacReviewView.swift`: `macAccuracyPill()` func durch `AccuracyPill()` struct ersetzen (3 Aufrufstellen)
- `MacReviewView.swift`: `MacStatItem` Aufrufe → `StatItem` (6 Aufrufstellen)

### Schritt 4: macOS CategoryStat-Umstellung
- `MacReviewView.swift`: `MacCategoryStat` und `MacCategoryBar` entfernen
- Stats-Erstellung umstellen von String-basiert auf `TaskCategory.allCases.compactMap` (wie iOS)
- `MacCategoryBar` Aufrufe → `CategoryBar` (2 Aufrufstellen)

### Schritt 5: Build verifizieren
- Beide Targets (iOS + macOS) muessen kompilieren

## Expected Behavior

- **Keine funktionale Aenderung** - reine Code-Verschiebung/Vereinheitlichung
- Alle Review-Views zeigen identische UI wie vorher
- Shared Components in `ReviewComponents.swift` werden von beiden Plattformen genutzt

## Affected Files

| File | Change | LoC |
|------|--------|-----|
| `FocusBlox.xcodeproj/project.pbxproj` | MODIFY | +5 |
| `Sources/Views/DailyReviewView.swift` | MODIFY | -55 |
| `Sources/Views/SprintReviewSheet.swift` | MODIFY | -16 |
| `FocusBloxMac/MacFocusView.swift` | MODIFY | -18 |
| `FocusBloxMac/MacReviewView.swift` | MODIFY | -50 |

**Scope:** 5 Dateien, netto ~-130 LoC

## Test Plan

- Build-Validierung: beide Targets kompilieren ohne Fehler
- Bestehende Funktionalitaet bleibt unveraendert (reine Verschiebung/Vereinheitlichung)

## Known Limitations

- `MacCategoryStat` hatte computed properties (label, color, icon, formattedTime) die jetzt ueber `CategoryStat.config` (TaskCategory) bezogen werden - funktional identisch

## Changelog

- 2026-02-13: Initial spec created
