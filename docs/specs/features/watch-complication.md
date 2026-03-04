---
entity_id: watch-complication
type: feature
created: 2026-03-04
updated: 2026-03-04
status: draft
version: "1.0"
tags: [watch, widget, complication, quick-capture]
---

# Watch Quick Capture Complication

## Approval

- [ ] Approved

## Purpose

WidgetKit-Complication fuer watchOS, die als `accessoryCircular` auf dem Watchface erscheint ("+"-Icon). Bei Tap oeffnet die App und zeigt sofort das VoiceInputSheet — 1-Tap vom Watchface zum Diktat.

Teil der Watch Quick Capture User Story (`docs/project/stories/watch-quick-capture.md`).

## Source

- **Files:**
  - `FocusBloxWatchWidgets/QuickCaptureComplication.swift` (NEU)
  - `FocusBloxWatchWidgets/FocusBloxWatchWidgetsBundle.swift` (NEU)
  - `FocusBloxWatchWidgets/FocusBloxWatchWidgets.entitlements` (NEU)
  - `FocusBloxWatch Watch App/ContentView.swift` (MODIFY)
  - `FocusBlox.xcodeproj/project.pbxproj` (MODIFY)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| WidgetKit | Framework | StaticConfiguration, TimelineProvider |
| SwiftUI | Framework | Views, AccessoryWidgetBackground |
| ContentView (Watch) | View | Empfaengt Deep-Link, oeffnet VoiceInputSheet |
| VoiceInputSheet | View | Ziel-UI nach Complication-Tap |
| App Group | Entitlement | `group.com.henning.focusblox` |

## Implementation Details

### 1. QuickCaptureComplication.swift (~65 LoC)

```swift
// Widget Definition
struct QuickCaptureComplication: Widget {
    static let kind = "com.focusblox.watch.quickcapture"
    // StaticConfiguration, .accessoryCircular, .widgetURL("focusblox://voice-capture")
}

// TimelineProvider mit .never Policy (rein statisch)
struct QuickCaptureComplicationProvider: TimelineProvider { ... }

// View: AccessoryWidgetBackground + plus.circle.fill SF Symbol
struct QuickCaptureComplicationView: View { ... }
```

### 2. FocusBloxWatchWidgetsBundle.swift (~10 LoC)

```swift
@main
struct FocusBloxWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickCaptureComplication()
    }
}
```

### 3. ContentView.swift Aenderung (~5 LoC)

```swift
// Nach .sheet(isPresented:) hinzufuegen:
.onOpenURL { url in
    if url.host == "voice-capture" {
        showingInput = true
    }
}
```

### 4. Deep-Link Flow

```
Complication Tap
    -> widgetURL("focusblox://voice-capture")
    -> watchOS oeffnet Host-App
    -> Cold Launch: onAppear setzt showingInput = true (bestehend)
    -> Warm Launch: onOpenURL setzt showingInput = true (NEU)
    -> VoiceInputSheet erscheint
```

### 5. Xcode Target

- Name: `FocusBloxWatchWidgets`
- Type: Widget Extension (watchOS)
- Bundle ID: `com.henning.timebox.watchkitapp.widgets`
- Embed in: FocusBloxWatch Watch App
- Entitlements: App Group (`group.com.henning.focusblox`)

## Expected Behavior

- **Input:** User tippt auf Complication auf dem Watchface
- **Output:** App oeffnet sich, VoiceInputSheet erscheint sofort
- **Side effects:** Keine (Widget ist rein statisch, kein Datenzugriff)

## Test Plan

### Unit Tests
1. `QuickCaptureComplicationProvider` gibt Entry mit `.never` Policy zurueck
2. Deep-Link URL-Parsing: `url.host == "voice-capture"` wird korrekt erkannt

### UI Tests
1. App oeffnet VoiceInputSheet wenn via Deep-Link Launch-Argument gestartet
2. Complication View rendert korrekt (Widget Preview)

## Known Limitations

- Nur `accessoryCircular` Familie (andere Familien nicht sinnvoll fuer einen reinen Tap-Target)
- Kein dynamischer Content (rein statisches "+"-Icon)
- Kein URL-Scheme in Info.plist noetig (widgetURL routet automatisch zur Host-App)

## Scope

- **Files:** 5 (3 CREATE, 2 MODIFY)
- **LoC:** ~95 handgeschrieben
- **Risk:** LOW

## Changelog

- 2026-03-04: Initial spec created
