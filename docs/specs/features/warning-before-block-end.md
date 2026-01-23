---
entity_id: warning-before-block-end
type: feature
created: 2026-01-22
status: draft
workflow: warning-before-block-end
tags: [focus, sound, notification, haptic, user-story-sprint-2]
---

# Vorwarnung vor Block-Ende

## Approval

- [ ] Approved for implementation

## Purpose

Konfigurierbarer Hinweis ("noch X min") vor Block-Ende mit Sound + Haptic. Gibt dem Nutzer Zeit, die aktuelle Tätigkeit abzuschließen bevor der Block endet.

## Scope

### Affected Files

| File | Change | Description |
|------|--------|-------------|
| `TimeBox/Sources/Models/WarningTiming.swift` | CREATE | Enum für Warning-Timing Optionen |
| `TimeBox/Sources/Models/AppSettings.swift` | MODIFY | warningEnabled + warningTiming Settings |
| `TimeBox/Sources/Services/SoundService.swift` | MODIFY | playWarning() Methode |
| `TimeBox/Sources/Views/FocusLiveView.swift` | MODIFY | Warning-Check Logik |
| `TimeBox/Sources/Views/SettingsView.swift` | MODIFY | Warning-Toggle + Timing-Picker |

### Estimate

- **Files:** 5
- **LoC:** +80/-5
- **Risk:** LOW

## Implementation Details

### 1. AppSettings erweitern

```swift
/// Warning timing options (percentage of block completed)
enum WarningTiming: Int, CaseIterable {
    case short = 90      // "Knapp" - 10% vor Ende
    case standard = 80   // "Standard" - 20% vor Ende
    case early = 70      // "Früh" - 30% vor Ende

    var label: String {
        switch self {
        case .short: return "Knapp"
        case .standard: return "Standard"
        case .early: return "Früh"
        }
    }

    var percentComplete: Double {
        Double(rawValue) / 100.0
    }
}

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Existing
    @AppStorage("soundEnabled") var soundEnabled: Bool = true

    // NEW: Warning settings
    @AppStorage("warningEnabled") var warningEnabled: Bool = true
    @AppStorage("warningTiming") var warningTimingRaw: Int = WarningTiming.standard.rawValue

    var warningTiming: WarningTiming {
        get { WarningTiming(rawValue: warningTimingRaw) ?? .standard }
        set { warningTimingRaw = newValue.rawValue }
    }
}
```

### 2. SoundService erweitern

```swift
@MainActor
enum SoundService {
    static func playEndGong() {
        guard AppSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1007)  // Tink
    }

    /// NEW: Plays warning sound before block end
    static func playWarning() {
        guard AppSettings.shared.soundEnabled else { return }
        guard AppSettings.shared.warningEnabled else { return }
        // System sound ID 1005 = "Alarm" (different from end gong)
        AudioServicesPlaySystemSound(1005)
    }
}
```

### 3. FocusLiveView Warning-Check

```swift
// State für Warning-Tracking
@State private var warningPlayed = false

private func checkBlockEnd() {
    guard let block = activeBlock else { return }

    let progress = calculateProgress(block: block)
    let warningThreshold = AppSettings.shared.warningTiming.percentComplete

    // Check for warning (nur einmal pro Block, wenn Threshold erreicht)
    if progress >= warningThreshold && !warningPlayed && !block.isPast {
        SoundService.playWarning()
        warningPlayed = true
    }

    // Block ended - play end gong and show review
    if block.isPast && !showSprintReview {
        SoundService.playEndGong()
        showSprintReview = true
        warningPlayed = false  // Reset für nächsten Block
    }
}
```

### 4. SettingsView Warning-Section

```swift
// In SettingsView, add @AppStorage properties
@AppStorage("warningEnabled") private var warningEnabled: Bool = true
@AppStorage("warningTiming") private var warningTimingRaw: Int = WarningTiming.standard.rawValue

// In Form, after Sound toggle
Section {
    Toggle(isOn: $warningEnabled) {
        Text("Vorwarnung")
    }
    .accessibilityIdentifier("warningToggle")

    if warningEnabled {
        Picker("Zeitpunkt", selection: $warningTimingRaw) {
            ForEach(WarningTiming.allCases, id: \.rawValue) { timing in
                Text(timing.label).tag(timing.rawValue)
            }
        }
        .accessibilityIdentifier("warningTimingPicker")
    }
} header: {
    Text("Vorwarnung")
} footer: {
    Text("Sound und Vibration vor Block-Ende.")
}
```

## Test Plan

### Automated Tests (TDD RED)

#### Unit Tests (`TimeBoxTests/WarningTests.swift`)

1. **testWarningEnabledByDefault**
   - GIVEN: Fresh AppSettings
   - WHEN: Check warningEnabled
   - THEN: Returns true

2. **testWarningTimingDefaultsToStandard**
   - GIVEN: Fresh AppSettings
   - WHEN: Check warningTiming
   - THEN: Returns .standard (80%)

3. **testWarningTimingLabels**
   - GIVEN: WarningTiming enum
   - WHEN: Check all labels
   - THEN: "Knapp", "Standard", "Früh"

4. **testPlayWarningRespectsSettings**
   - GIVEN: warningEnabled = false
   - WHEN: SoundService.playWarning() called
   - THEN: No sound played

#### UI Tests (`TimeBoxUITests/WarningSettingsUITests.swift`)

1. **testWarningToggleExistsInSettings**
   - GIVEN: App launched
   - WHEN: Navigate to Settings
   - THEN: "Vorwarnung" toggle is visible

2. **testWarningTimingPickerAppearsWhenEnabled**
   - GIVEN: Settings view open, warning enabled
   - WHEN: Looking at warning section
   - THEN: Timing picker with options is visible

### Manual Tests

- [ ] Warning Sound spielt bei konfiguriertem Prozent-Threshold
- [ ] Haptic Feedback bei Warning
- [ ] Warning spielt nur einmal pro Block
- [ ] Warning respektiert Settings (on/off)
- [ ] Timing konfigurierbar (Knapp/Standard/Früh)

## Acceptance Criteria

- [ ] Warning Sound (1005) spielt bei Prozent-Threshold
- [ ] Haptic Feedback (warning) bei Warning
- [ ] Warning ist in Settings konfigurierbar (on/off)
- [ ] Timing konfigurierbar mit verständlichen Labels
- [ ] Warning spielt nur einmal pro Block
- [ ] Alle Unit Tests grün
- [ ] Alle UI Tests grün

## Design Decisions

| Frage | Entscheidung |
|-------|--------------|
| Warning Sound? | System Sound 1005 (Alarm) - anders als End-Gong |
| Timing-System? | Prozentual (skaliert mit Block-Länge) |
| Default Timing? | Standard (80% = 20% vor Ende) |
| Optionen? | Knapp (90%), Standard (80%), Früh (70%) |
| Labels? | Verständliche Texte statt Prozent-Angaben |
| Haptic Type? | .warning (nicht .error, nicht .success) |

## Known Limitations

- Kein visuelles Warning-Banner (nur Sound + Haptic)

## Changelog

- 2026-01-22: Initial spec created (Sprint 2 der User Story Roadmap)
