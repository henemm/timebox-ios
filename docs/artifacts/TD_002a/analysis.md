# TD_002a: BacklogRow Badge-Konsolidierung — Analyse

## Ist-Zustand

Bereits shared (TaskBadges.swift): ImportanceBadge, UrgencyBadge, RecurrenceBadge, TagsBadge, PriorityScoreBadge

## Noch dupliziert

| Badge | Typ | Aktion |
|-------|-----|--------|
| DueDateBadge | Reine Anzeige | → Shared Component |
| StackingBadge | Reine Anzeige | → Shared Component |
| CategoryDisplayLabel | Visuelle Label-Komponente | → Shared, von Button (iOS) + Menu (macOS) genutzt |
| DurationDisplayLabel | Visuelle Label-Komponente | → Shared, von Button (iOS) + Menu (macOS) genutzt |
| Category helpers (color/icon/label) | Computed Properties | → Entfallen durch DisplayLabel |
| Duration helpers (isDurationSet) | Computed Properties | → Entfallen durch DisplayLabel |

## Nicht konsolidierbar

- CategoryBadge Interaktion: iOS Button+Callback vs. macOS Menu-Picker
- DurationBadge Interaktion: iOS Button+Callback vs. macOS Menu-Picker

## Scope

- TaskBadges.swift: +65 LoC (4 neue Components)
- BacklogRow.swift: -50 LoC (Inline-Code durch shared Badges ersetzen)
- MacBacklogRow.swift: -60 LoC (Inline-Code durch shared Badges ersetzen)
- Netto: ~45 LoC weniger
