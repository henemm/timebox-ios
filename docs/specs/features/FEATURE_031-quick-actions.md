---
entity_id: feature_031_quick_actions
type: feature
created: 2026-03-30
updated: 2026-03-30
status: draft
version: "1.0"
tags: [ios, ux, quick-actions]
---

# FEATURE_031 — iOS App Icon Quick Actions

## Approval

- [ ] Approved

## Purpose

Long-Press auf das FocusBlox App-Icon zeigt 3 Quick Actions: Task notieren, Sprint starten, Heute. Ermöglicht schnellen Zugriff auf die häufigsten Aktionen ohne App-Navigation.

## Scope

| Datei | Änderung | LoC |
|-------|----------|-----|
| `Resources/Info.plist` | 3 statische `UIApplicationShortcutItem` Einträge | ~30 |
| `Sources/Views/SprintPickerSheet.swift` | **Neu:** Sheet mit Next-Up Tasks + Sprint-Start | ~70 |
| `Sources/FocusBloxApp.swift` | URL-Case `sprint-picker` + Sheet-State + `.sheet()` | ~20 |

**Gesamt: 3 Dateien, ~120 LoC**

## Quick Actions

### 1. Task notieren

| Feld | Wert |
|------|------|
| **Label** | Task notieren |
| **Icon** | `plus.circle` (SF Symbol) |
| **URL** | `focusblox://create-task` |
| **Verhalten** | Öffnet Quick Capture Sheet (existiert bereits) |
| **Neue Logik** | Keine — bestehender `onOpenURL`-Case |

### 2. Sprint starten

| Feld | Wert |
|------|------|
| **Label** | Sprint starten |
| **Icon** | `bolt.fill` (SF Symbol) |
| **URL** | `focusblox://sprint-picker` |
| **Verhalten** | Öffnet SprintPickerSheet mit Next-Up Tasks |
| **Neue Logik** | SprintPickerSheet + URL-Handler |

### 3. Heute

| Feld | Wert |
|------|------|
| **Label** | Heute |
| **Icon** | `calendar` (SF Symbol) |
| **URL** | `focusblox://day-view` |
| **Verhalten** | Wechselt zu DayView Tab |
| **Neue Logik** | Keine — bestehender `onOpenURL`-Case |

## Info.plist — Statische Quick Actions

```xml
<key>UIApplicationShortcutItems</key>
<array>
    <dict>
        <key>UIApplicationShortcutItemType</key>
        <string>com.henning.focusblox.create-task</string>
        <key>UIApplicationShortcutItemTitle</key>
        <string>Task notieren</string>
        <key>UIApplicationShortcutItemIconSymbolName</key>
        <string>plus.circle</string>
        <key>UIApplicationShortcutItemTargetURL</key>
        <string>focusblox://create-task</string>
    </dict>
    <dict>
        <key>UIApplicationShortcutItemType</key>
        <string>com.henning.focusblox.sprint-picker</string>
        <key>UIApplicationShortcutItemTitle</key>
        <string>Sprint starten</string>
        <key>UIApplicationShortcutItemIconSymbolName</key>
        <string>bolt.fill</string>
        <key>UIApplicationShortcutItemTargetURL</key>
        <string>focusblox://sprint-picker</string>
    </dict>
    <dict>
        <key>UIApplicationShortcutItemType</key>
        <string>com.henning.focusblox.day-view</string>
        <key>UIApplicationShortcutItemTitle</key>
        <string>Heute</string>
        <key>UIApplicationShortcutItemIconSymbolName</key>
        <string>calendar</string>
        <key>UIApplicationShortcutItemTargetURL</key>
        <string>focusblox://day-view</string>
    </dict>
</array>
```

## SprintPickerSheet — Neues View

**Zweck:** Kompaktes Sheet das Next-Up Tasks zeigt. Antippen startet sofort einen Focus Sprint.

### Verhalten

1. Sheet öffnet mit `.presentationDetents([.medium])`
2. Zeigt alle Tasks mit `isNextUp == true && !isCompleted`
3. Jede Row: Task-Titel + geschätzte Dauer + Kategorie-Badge
4. Tap auf Row → `FocusBlockActionService.startImmediate(taskID:)` → Sprint läuft
5. Bei Erfolg: Sheet schließt, App wechselt zu Focus Tab
6. Bei Konflikt (aktiver Block): Alert mit Konflikt-Info
7. Leerer Zustand: "Keine Next-Up Tasks. Markiere Tasks im Backlog als Next Up."

### Accessibility Identifiers

| Element | Identifier |
|---------|-----------|
| Sheet | `sprintPickerSheet` |
| Task Row | `sprintPickerRow_<taskID>` |
| Leerer Zustand | `sprintPickerEmpty` |

## FocusBloxApp.swift — Änderungen

```swift
// Neue State-Variable
@State private var showSprintPicker = false

// Neuer URL-Case in .onOpenURL
} else if url.host == "sprint-picker" {
    showSprintPicker = true
}

// Neues Sheet
.sheet(isPresented: $showSprintPicker) {
    SprintPickerSheet()
}
```

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `FocusBlockActionService` | Service | Sprint starten via `startImmediate()` |
| `PlanItem` | Model | Task-Daten (isNextUp, Titel, Dauer) |
| `QuickCaptureView` | View | Bestehendes Quick Capture (unverändert) |
| `FocusBloxApp` | App | URL-Handler + Sheet-Präsentation |

## Keine Änderungen an

- Permissions (Info.plist Usage Descriptions)
- AppStorage-Keys
- Dependencies/Packages
- macOS (Quick Actions = iOS-only Feature)
- Bestehende Views/Services

## Edge Cases

| Fall | Verhalten |
|------|-----------|
| Keine Next-Up Tasks | Leerer Zustand mit Hinweis |
| Aktiver Focus Block läuft | Alert: "Sprint läuft bereits: [Titel]" |
| App war nicht gestartet (Cold Launch) | iOS öffnet App + sendet URL → Sheet erscheint |
| App war im Hintergrund | iOS bringt App in Vordergrund + sendet URL |

## Testplan

### Unit Tests (SprintPickerSheetTests)
1. Sheet zeigt nur Next-Up Tasks (nicht alle Tasks)
2. Sheet zeigt leeren Zustand wenn keine Next-Up Tasks
3. Sprint-Start ruft `FocusBlockActionService.startImmediate` auf

### UI Tests (QuickActionUITests)
1. Sprint-Picker Sheet öffnet via URL `focusblox://sprint-picker`
2. Next-Up Tasks erscheinen im Sheet
3. Tap auf Task startet Sprint (Tab wechselt zu Focus)
4. Leerer Zustand erscheint ohne Next-Up Tasks

## Changelog

- 2026-03-30: Initial spec created
