# Spec: TD-02 Shared Badge Components (Paket 1)

## Ziel
7 duplizierte Badge-Views aus BacklogRow (iOS) und MacBacklogRow (macOS) in Shared Components extrahieren. Netto ~250-300 LoC Einsparung bei 0 Verhaltensaenderung.

## Analyse-Ergebnis

| Badge | Identitaet | Teilbar? | Unterschied |
|-------|-----------|----------|-------------|
| Importance | 95% | JA | Font/Padding/sensoryFeedback |
| Urgency | 95% | JA | Font/Padding/sensoryFeedback |
| Recurrence | 95% | JA | Font/Padding |
| Tags | 95% | JA | Enumeration-Style |
| Priority Score | 90% | JA | macOS rechnet frisch (Inkonsistenz) |
| Category | 70% | NEIN | iOS=Button, macOS=Menu |
| Duration | 75% | NEIN | iOS=Button, macOS=Menu |

## Design

### Plattform-Sizing via Conditional Compilation

```swift
// In TaskBadges.swift (top-level)
#if os(iOS)
let badgeIconFont: CGFloat = 14
let badgePaddingH: CGFloat = 6
let badgePaddingV: CGFloat = 4
let badgeCornerRadius: CGFloat = 6
let badgeSpacing: CGFloat = 4
#else
let badgeIconFont: CGFloat = 12
let badgePaddingH: CGFloat = 5
let badgePaddingV: CGFloat = 3
let badgeCornerRadius: CGFloat = 5
let badgeSpacing: CGFloat = 3
#endif
```

### 5 Shared Badge Views

Jede Badge-View nimmt **Werte als Parameter** (nicht das Task-Objekt), damit sie von beiden Rows genutzt werden kann.

#### 1. ImportanceBadge
- Parameter: `importance: Int?`, `taskId: String`, `onCycle: ((Int) -> Void)?`
- Logik: Cycling 1→2→3→1
- iOS-only: `.sensoryFeedback(.impact(weight: .light))`, `.accessibilityLabel()`

#### 2. UrgencyBadge
- Parameter: `urgency: String?`, `taskId: String`, `onToggle: ((String?) -> Void)?`
- Logik: nil→"not_urgent"→"urgent"→nil
- iOS-only: `.sensoryFeedback(.impact(weight: .medium))`, `.accessibilityLabel()`

#### 3. RecurrenceBadge
- Parameter: `pattern: String`, `taskId: String`
- Read-only (kein Button), zeigt Icon + DisplayName
- Nur sichtbar wenn pattern != "none"

#### 4. TagsBadge
- Parameter: `tags: [String]`, `taskId: String`
- Zeigt max 2 Tags + "+N" Overflow
- Capsule-Style statt RoundedRectangle

#### 5. PriorityScoreBadge
- Parameter: `score: Int`, `tier: TaskPriorityScoringService.PriorityTier`, `taskId: String`
- Read-only, zeigt Score + Farbe nach Tier
- Caller liefert Score (behebt macOS-Inkonsistenz: kein Recalculate im Badge)

### NICHT geteilt (bleibt plattform-spezifisch)
- **CategoryBadge**: iOS = Button+Callback, macOS = Menu+Dropdown → fundamental verschiedene UX
- **DurationBadge**: iOS = Button+Callback, macOS = Menu+Presets → fundamental verschiedene UX

## Aenderungen

| Datei | Typ | Beschreibung |
|-------|-----|-------------|
| `Sources/Views/Components/TaskBadges.swift` | CREATE | 5 Shared Badge-Views + Sizing-Konstanten |
| `Sources/Views/BacklogRow.swift` | MODIFY | Import Shared Badges, inline Badge-Code entfernen |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | Import Shared Badges, inline Badge-Code entfernen |
| `FocusBloxTests/TaskBadgesTests.swift` | CREATE | Unit Tests fuer Badge-Rendering-Logik |

## Scope
- **4 Dateien** (2 CREATE, 2 MODIFY)
- **~150 LoC neu** (TaskBadges.swift)
- **~400 LoC entfernt** (aus beiden Rows)
- **Netto: ~-250 LoC**
- **Risiko: NIEDRIG** (reine View-Extraktion, keine Logik-Aenderung)

## NICHT im Scope
- Sheet-Unification (Paket 2) — separates Ticket
- FocusBlockCard Header (Paket 3) — separates Ticket
- Category/Duration Badge Unification — nicht sinnvoll (verschiedene UX)
