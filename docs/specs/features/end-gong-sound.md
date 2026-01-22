---
entity_id: end-gong-sound
type: feature
created: 2026-01-22
status: approved
workflow: user-story-gap-analysis
tags: [focus, sound, notification, user-story-sprint-1]
---

# End-Gong/Sound

## Approval

- [x] Approved for implementation (2026-01-22)

## Purpose

Akustisches Signal am Ende eines Focus Blocks, damit der Nutzer weiß "Schluss jetzt, nächstes Thema". Löst das Kern-Problem der User Story: Ohne harte Grenze dehnt sich eine Tätigkeit aus und frisst die nächste.

## Scope

### Affected Files

| File | Change | Description |
|------|--------|-------------|
| `TimeBox/Sources/Services/SoundService.swift` | CREATE | Sound-Abstraction |
| `TimeBox/Sources/Views/FocusLiveView.swift` | MODIFY | Sound bei Block-Ende abspielen |
| `TimeBox/Sources/Models/AppSettings.swift` | CREATE | Settings-Model mit `soundEnabled` |
| `TimeBox/Sources/Views/SettingsView.swift` | MODIFY | Toggle für Sound |

### Estimate

- **Files:** 4
- **LoC:** +80/-5
- **Risk:** LOW

## Implementation Details

### 1. SoundService

```swift
import AudioToolbox

enum SoundService {
    /// Plays the end-of-block gong sound
    static func playEndGong() {
        guard AppSettings.shared.soundEnabled else { return }
        // System sound ID 1007 = "Tink" (short, pleasant)
        // Alternative: 1005 = "Alarm"
        AudioServicesPlaySystemSound(1007)
    }
}
```

**System Sound IDs (Auswahl):**
- 1007: Tink (kurz, angenehm)
- 1005: Alarm
- 1304: Fanfare
- 1322: Anticipate

### 2. AppSettings

```swift
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("soundEnabled") var soundEnabled: Bool = true
}
```

### 3. FocusLiveView Integration

In `checkBlockEnd()`:

```swift
private func checkBlockEnd() {
    guard let block = activeBlock else { return }

    if block.isPast && !showSprintReview {
        SoundService.playEndGong()  // NEW
        showSprintReview = true
    }
}
```

### 4. SettingsView Toggle

```swift
Toggle("Sound bei Block-Ende", isOn: $settings.soundEnabled)
```

## Test Plan

### Automated Tests (TDD RED)

#### Unit Tests (`TimeBoxTests/SoundServiceTests.swift`)

1. **testSoundEnabledByDefault**
   - GIVEN: Fresh AppSettings
   - WHEN: Check soundEnabled
   - THEN: Returns true

2. **testSoundCanBeDisabled**
   - GIVEN: AppSettings with soundEnabled = true
   - WHEN: Set soundEnabled = false
   - THEN: soundEnabled is false

3. **testPlayEndGongRespectsSettings**
   - GIVEN: soundEnabled = false
   - WHEN: SoundService.playEndGong() called
   - THEN: No sound played (mock verification)

#### UI Tests (`TimeBoxUITests/SoundSettingsUITests.swift`)

1. **testSoundToggleExistsInSettings**
   - GIVEN: App launched
   - WHEN: Navigate to Settings
   - THEN: "Sound bei Block-Ende" toggle is visible

2. **testSoundToggleCanBeToggled**
   - GIVEN: Settings view open
   - WHEN: Tap sound toggle
   - THEN: Toggle state changes

### Manual Tests

- [ ] Sound spielt am Ende eines Focus Blocks
- [ ] Sound spielt NICHT wenn in Settings deaktiviert
- [ ] Sound ist angenehm und nicht zu laut/leise

## Acceptance Criteria

- [ ] System-Sound spielt am Block-Ende
- [ ] Sound ist in Settings konfigurierbar (on/off)
- [ ] Sound respektiert System-Lautstärke
- [ ] Kein Sound wenn App im Hintergrund (iOS managed)
- [ ] Alle Unit Tests grün
- [ ] Alle UI Tests grün

## Design Decisions

| Frage | Entscheidung |
|-------|--------------|
| Custom vs. System Sound? | System Sound (einfacher, kein Asset nötig) |
| Welcher System Sound? | 1007 (Tink) - kurz, angenehm |
| Sound auch bei Task-Wechsel? | Nein, nur Block-Ende (MVP) |
| Lautstärke konfigurierbar? | Nein, System-Lautstärke (MVP) |

## Known Limitations

- System Sounds funktionieren nicht wenn Gerät auf "Stumm"
- Kein Sound im Background (iOS-Einschränkung)
- Lautstärke nicht separat konfigurierbar

## Changelog

- 2026-01-22: Initial spec created (Sprint 1 der User Story Roadmap)
