# EPIC_170c — Intentionsbasierte Nudge-Inhalte

**GitHub Issue:** #170 (letzter offener Teil)
**Status:** Spec approved
**Modus:** ÄNDERUNG (bestehende buildNudgeRequests-Logik erweitern)

---

## Was und Warum

### Problem (IST-Zustand)

`buildNudgeRequests()` in `SmartNotificationEngine` nutzt **3 statische Texte**:
- "Wie läuft dein Tag?" / "Zeit für den nächsten Sprint?" / "Dein Backlog wartet"
- Kein Bezug zur Tagesintention des Users
- `DayIntention` SwiftData-Model existiert bereits (aus #195a), wird aber nicht genutzt

### Lösung (SOLL)

Nudges werden **intentionsbasiert** statt statisch:

1. **Mit Intention:** Nudge-Text referenziert die heutige `DayIntention` direkt
   - z.B. "Wie läuft's mit dem Projektkonzept? Du bist auf dem richtigen Weg."
2. **Ohne Intention:** Kein Nudge (User-Advocate-Empfehlung: lieber Stille als generisch)
3. **AI-Pfad:** Wenn FoundationModels verfügbar → personalisierter Text
4. **Fallback-Pfad:** Statische Templates die den Intentions-Text einweben

### User-Erwartung (aus User-Advocate)

- Fühlt sich persönlich an, nicht wie Spam
- Kein Echo (nicht wortwörtlich wiederholen)
- Max 2 Zeilen auf Sperrbildschirm
- Ohne Intention: kein Nudge (statt generischem Text)

---

## Aktueller Zustand (Delta-Basis)

### SmartNotificationEngine.buildNudgeRequests() — Zeile 374-417

```swift
static func buildNudgeRequests(now: Date = Date(), completedTodayCount: Int = 0) -> [UNNotificationRequest]
```
- Budget, Silence, Window funktionieren bereits
- Texte: 3 statische Paare (Zeile 386-390)
- Wird von 2x `buildAllRequests()` aufgerufen (Zeile 103, 244)
  - Overload 1: `container: ModelContainer` (Zeile 84)
  - Overload 2: `context: ModelContext` (Zeile 225)

### DayIntention — Sources/Models/DayIntention.swift

```swift
@Model final class DayIntention {
    var uuid: UUID
    var date: Date      // startOfDay
    var text: String
    var createdAt: Date
}
```

### NotificationContentService — Zeile 136-147

- `nudgeFallback()` existiert (unused)
- Kein `generateNudgeContent()` mit Intention
- Pattern: `isAIAvailable` + Fallback (wie Morning/Evening)

---

## Implementierungsplan

### Scope: 3 Dateien, ~85 LoC

#### Datei 1: `Sources/Services/NotificationContentService.swift` (~40 LoC)

Neue Methode `generateNudgeContent(intentionText:)`:

```swift
@MainActor
static func generateNudgeContent(intentionText: String) async -> Content
```

- **AI-Pfad:** Prompt mit Intention → kurzer ermutigender Nudge (max 2 Sätze)
- **Fallback-Pfad:** 3 Template-Varianten die `intentionText` einweben:
  - "Wie läuft's mit «{intention}»? Ein kleiner Schritt zählt."
  - "«{intention}» — bist du heute schon einen Schritt nähergekommen?"
  - "Kurzer Check-in: Wie steht's um «{intention}»?"
- Psychologie: Fragen statt Befehle (SDT — Autonomie), kurz + warm

#### Datei 2: `Sources/Services/SmartNotificationEngine.swift` (~30 LoC)

`buildNudgeRequests` bekommt neuen Parameter:

```swift
static func buildNudgeRequests(
    now: Date = Date(),
    completedTodayCount: Int = 0,
    intentionText: String? = nil      // NEU
) -> [UNNotificationRequest]
```

Änderungen:
- Guard: `intentionText != nil && !intentionText!.isEmpty` — ohne Intention → `[]` (keine Nudges)
- Statische `nudgeTexts` ersetzen durch `NotificationContentService.nudgeFallback`-Varianten mit Intention
- **Hinweis:** AI-Content kann hier nicht async aufgerufen werden (Methode ist sync). Lösung: Fallback-Templates direkt, AI nur wenn precomputed.

Beide `buildAllRequests()` Overloads aktualisieren:
- Overload 1 (container): `DayIntention` aus Container fetchen
- Overload 2 (context): `DayIntention` aus Context fetchen
- Intention-Text an `buildNudgeRequests(intentionText:)` übergeben

#### Datei 3: `FocusBloxTests/SmartNotificationEngineIntentionTests.swift` (~40 LoC)

Neue Test-Datei für Intentions-Content (TDD RED):
- `test_nudge_withIntention_bodyContainsIntentionReference`
- `test_nudge_withoutIntention_returnsEmpty`
- `test_nudgeContent_withIntention_notVerbatimEcho`
- `test_nudgeContent_fallback_shortEnough`

---

## Was NICHT in diesem Scope

- SettingsView-Änderungen (Nudge-Settings existieren bereits aus #174)
- AI-generierte Nudge-Inhalte async (zu komplex — Fallback-Templates reichen)
- AppSettings-Keys für Intention (DayIntention SwiftData existiert bereits)
- watchOS-Nudges (separates Ticket)

---

## Plattform-Parität

Notifications sind **Shared Code** in `Sources/Services/`. Änderungen wirken automatisch auf iOS + macOS. Kein plattformspezifischer Code nötig.

**Pflicht:** Nach Implementation `./scripts/sim.sh build` UND `./scripts/sim.sh mac-build` ausführen.

---

## Deep-Link (unverändert)

`userInfo["target"] = "day", "phase" = "daytime"` bleibt identisch. Tap auf Nudge öffnet weiterhin DayView.
