# TD_002a: BacklogRow Badge-Konsolidierung

## Ziel
Duplizierte Badge-Komponenten aus BacklogRow (iOS) und MacBacklogRow (macOS) in shared Components konsolidieren.

## Neue Shared Components (in TaskBadges.swift)

### 1. DueDateBadge
- Parameter: `date: Date`
- Anzeige: Kalender-Icon + formatierter Text
- Rot wenn überfällig oder heute, sonst secondary

### 2. StackingBadge
- Parameter: `count: Int, taskId: String`
- Anzeige: "x{count}" mit Capsule-Hintergrund
- Orange ab count >= 3, sonst secondary

### 3. CategoryDisplayLabel
- Parameter: `taskType: String`
- Anzeige: Icon + displayName mit farbigem Hintergrund
- Wird als Label in iOS-Button und macOS-Menu genutzt

### 4. DurationDisplayLabel
- Parameter: `duration: Int?, isDurationSet: Bool`
- Anzeige: Timer/Fragezeichen-Icon + optional Minutenzahl
- Blau wenn gesetzt, grau wenn nicht

## Änderungen an bestehenden Dateien

### BacklogRow.swift (iOS)
- DueDateBadge inline → shared DueDateBadge
- StackingBadge inline → shared StackingBadge
- categoryBadge: Label durch CategoryDisplayLabel ersetzen
- durationBadge: Label durch DurationDisplayLabel ersetzen
- categoryColor/Icon/Label helpers entfernen
- isDurationSet/durationBadgeColor/Background helpers entfernen

### MacBacklogRow.swift (macOS)
- dueDateBadge() Funktion → shared DueDateBadge
- StackingBadge inline → shared StackingBadge
- categoryBadge: Label durch CategoryDisplayLabel ersetzen
- durationBadge: Label durch DurationDisplayLabel ersetzen
- categoryColor/Icon/Label helpers entfernen
- isDurationSet helper entfernen
- Standalone CategoryBadge struct bleibt (wird anderswo genutzt)

## Keine Änderung
- Interaktionsmodell (Button vs. Menu) bleibt plattformspezifisch
- Visuelle Darstellung identisch zu vorher
- Accessibility Identifiers bleiben gleich
