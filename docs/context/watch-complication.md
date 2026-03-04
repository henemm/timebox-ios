# Context: Watch Complication

## Request Summary
WidgetKit-Complication fuer watchOS, die als accessoryCircular auf dem Watchface erscheint ("+"-Icon) und bei Tap die App oeffnet mit VoiceInputSheet.

## Related Files
| File | Relevance |
|------|-----------|
| `FocusBloxWatch Watch App/ContentView.swift` | Braucht `.onOpenURL` Handler fuer Deep-Link |
| `FocusBloxWatch Watch App/FocusBloxWatchApp.swift` | Watch App Entry Point (kein onOpenURL noetig - geht in ContentView) |
| `FocusBloxWatch Watch App/VoiceInputSheet.swift` | Das Sheet das nach Tap geoeffnet wird |
| `FocusBloxWidgets/QuickCaptureWidget.swift` | iOS-Referenz: Gleiches Pattern (StaticConfiguration + widgetURL) |
| `FocusBloxWidgets/FocusBloxWidgetsBundle.swift` | iOS-Referenz: WidgetBundle Struktur |
| `FocusBloxWidgets/QuickAddTaskControl.swift` | iOS-Referenz: ControlWidget Pattern |
| `Sources/FocusBloxApp.swift:267` | iOS onOpenURL fuer `focusblox://create-task` |

## Existing Patterns
- iOS Widget nutzt `StaticConfiguration` + `QuickCaptureProvider` + `.widgetURL(URL(string: "focusblox://create-task"))`
- iOS App faengt URL mit `.onOpenURL { url in if url.host == "create-task" ... }`
- Watch ContentView hat bereits `showingInput` State und `.sheet(isPresented:)` fuer VoiceInputSheet
- Watch ContentView hat `onAppear` Auto-Open (Cold Launch), braucht `onOpenURL` fuer Warm Launch

## Dependencies
- Upstream: WidgetKit, SwiftUI
- Downstream: Watch ContentView VoiceInputSheet

## Risks & Considerations
- Neues Xcode Target muss manuell in pbxproj eingetragen werden (komplex)
- Widget Extension muss in Watch App embedded sein
- URL Schema `focusblox://voice-capture` (NICHT `create-task` wie iOS — anderer Host fuer Watch-spezifischen Flow)

## Analysis

### Type
Feature (Watch Quick Capture Story — Complication)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `FocusBloxWatchWidgets/QuickCaptureComplication.swift` | CREATE | Widget mit StaticConfiguration, accessoryCircular, widgetURL |
| `FocusBloxWatchWidgets/FocusBloxWatchWidgetsBundle.swift` | CREATE | @main WidgetBundle |
| `FocusBloxWatchWidgets/FocusBloxWatchWidgets.entitlements` | CREATE | App Group Entitlement |
| `FocusBloxWatch Watch App/ContentView.swift` | MODIFY | +.onOpenURL Handler (~5 LoC) |
| `FocusBlox.xcodeproj/project.pbxproj` | MODIFY | Neues Widget Extension Target |

### Scope Assessment
- Files: 5 (3 CREATE, 2 MODIFY)
- Estimated LoC: ~95 handgeschrieben
- Risk Level: LOW (rein statisches Widget, kein Datenzugriff)

### Technical Approach
1. StaticConfiguration Widget mit `.never` Refresh (rein statischer Tap-Target)
2. accessoryCircular Family mit `plus.circle.fill` SF Symbol
3. `widgetURL(URL(string: "focusblox://voice-capture"))` fuer Deep-Link
4. ContentView `.onOpenURL` faengt URL und setzt `showingInput = true`
5. Cold Launch: bestehender `onAppear` Auto-Open greift weiterhin
6. Warm Launch: neuer `.onOpenURL` oeffnet Sheet

### Dependencies
- WidgetKit Framework (bereits im Projekt fuer iOS Widgets)
- App Group `group.com.henning.focusblox` (bereits vorhanden)
- Watch ContentView `showingInput` State (bereits vorhanden)
