# Proposal: Monster Coach Phase 3b — Smart Notifications (Tagesbegleitung)

> Erstellt: 2026-03-12
> Status: Zur Freigabe
> Bezug: User Story `docs/project/stories/monster-coach.md` — Section "Smart Notifications"

---

## Was und Warum

### Das Problem

Die Morgen-Intention lebt im Vakuum. Der User waehlt "BHAG", wechselt zum Backlog — und dann passiert nichts mehr. Ohne Tagesbegleitung verpufft die Intention bis zum Nachmittag. FocusBlox weiss aber ob die Intention gelebt wird: Gibt es einen Focus Block mit BHAG-Tasks? Wurden Lernen-Tasks erledigt? Wurden Tasks ausserhalb von Blocks erledigt?

### Was diese Phase loest

Phase 3b schliesst den Loop zwischen Morgen-Intention und dem Rest des Tages. Das Monster meldet sich — aber NUR wenn es eine Luecke zwischen Intention und Handlung gibt. Wer seine Intention lebt, hoert nichts. Das ist das Kern-Versprechen der Stille-Regel.

Die Phase liefert:

1. **IntentionEvaluationService** — neue Service-Schicht, die prueft ob eine Intention erfuellt ist. Liest Tasks aus SwiftData. Wird von Phase 3b (Notifications) und Phase 3c (Abend-Spiegel) genutzt.

2. **Smart Notification Scheduling** — nach dem Setzen der Morgen-Intention werden bis zu N Notifications im konfigurierten Zeitfenster verteilt. Jede Notification hat einen spezifischen Text basierend auf der Intention und der Luecken-Bedingung.

3. **Stille-Regel** — beim App-Foreground wird geprueft ob die Intention bereits erfuellt ist. Wenn ja, werden alle noch ausstehenden Tages-Nudge-Notifications gecancelt.

4. **Settings-Erweiterung** — drei neue Einstellungen in der Monster Coach Section der SettingsView.

---

## Scope: Was gebaut wird

### 1. IntentionEvaluationService (neue Datei)

`Sources/Services/IntentionEvaluationService.swift`

Eine `enum` ohne State (wie `NotificationService`), rein funktional und testbar.

**Kern-Funktion:**

```
static func isFulfilled(
    intention: IntentionOption,
    tasks: [LocalTask],
    focusBlocks: [FocusBlock]
) -> Bool
```

**Erfuellungs-Logik pro Intention:**

| Intention | Erfuellt wenn... |
|-----------|-----------------|
| `.survival` | Immer `true` — Survival braucht keine Pruefung |
| `.fokus` | Mindestens ein Focus Block heute ODER Block-Completion >= 70% |
| `.bhag` | Mindestens ein Task mit `importance == 3` heute erledigt |
| `.growth` | Mindestens ein Task mit `taskType == "learning"` heute erledigt |
| `.connection` | Mindestens ein Task mit `taskType == "giving_back"` heute erledigt |
| `.balance` | Tasks in mindestens 3 verschiedenen Kategorien heute erledigt |

**Luecken-Bedingungen (fuer Notification-Text-Auswahl):**

```
enum IntentionGap {
    case noBhagBlockCreated        // BHAG: Kein Block mit BHAG-Task
    case bhagTaskNotStarted        // BHAG: Nachmittags noch kein BHAG-Task erledigt
    case noFocusBlockPlanned       // Fokus: Kein Block geplant
    case tasksOutsideBlocks        // Fokus: Tasks ausserhalb von Blocks erledigt
    case onlySingleCategory        // Balance: Nur 1-2 Kategorien aktiv
    case noLearningTask            // Growth: Kein Lernen-Task erledigt
    case noConnectionTask          // Connection: Kein Geben-Task erledigt
}

static func detectGap(
    intention: IntentionOption,
    tasks: [LocalTask],
    focusBlocks: [FocusBlock],
    now: Date = Date()
) -> IntentionGap?
```

Gibt `nil` zurueck wenn Survival oder Intention bereits erfuellt.

**Hilfsfunktionen:**

```
static func completedToday(_ tasks: [LocalTask], now: Date = Date()) -> [LocalTask]
static func focusBlocksToday(_ blocks: [FocusBlock], now: Date = Date()) -> [FocusBlock]
```

"Heute" bedeutet: `completedAt >= startOfDay(now)`.

---

### 2. NotificationService — Tages-Nudge Scheduling

`Sources/Services/NotificationService.swift`

Neuer Abschnitt `// MARK: - Coach Daily Nudges`.

**Notification-Identifier-Prefix:** `"coach-nudge-"` gefolgt von einer fortlaufenden Nummer (z.B. `"coach-nudge-0"`, `"coach-nudge-1"`, `"coach-nudge-2"`).

**Nudge-Texte pro Intention und Gap:**

| Intention / Gap | Text |
|----------------|------|
| BHAG / `noBhagBlockCreated` | "Du wolltest das grosse Ding anpacken. Wann legst du los?" |
| BHAG / `bhagTaskNotStarted` | "Dein BHAG wartet noch." |
| Fokus / `noFocusBlockPlanned` | "Kein Block geplant. Du wolltest fokussiert bleiben." |
| Fokus / `tasksOutsideBlocks` | "Tasks ohne Block erledigt. Willst du einen erstellen?" |
| Balance / `onlySingleCategory` | "Bisher nur Arbeit. Wie waer's mit was fuer dich?" |
| Growth / `noLearningTask` | "Du wolltest was Neues lernen. Hast du schon was im Auge?" |
| Connection / `noConnectionTask` | "Du wolltest fuer andere da sein heute." |

**Neue Build-Funktion (testbar):**

```
static func buildDailyNudgeRequests(
    intention: IntentionOption,
    gap: IntentionGap,
    windowStart: Date,    // Zeitfenster-Beginn heute
    windowEnd: Date,      // Zeitfenster-Ende heute
    maxCount: Int,        // 1, 2 oder 3
    now: Date = Date()
) -> [UNNotificationRequest]
```

Verteilt `maxCount` Notifications gleichmaessig im Zeitfenster `[windowStart, windowEnd]`.
- Gibt `[]` zurueck wenn `intention == .survival`
- Gibt `[]` zurueck wenn `windowEnd <= now` (Zeitfenster vorbei)
- Filtert einzelne Fire-Dates die in der Vergangenheit liegen heraus

**Schedule-Funktion:**

```
static func scheduleDailyNudges(
    intention: IntentionOption,
    gap: IntentionGap
)
```

Liest Settings (`AppSettings.shared`), berechnet `windowStart`/`windowEnd` fuer heute, ruft `buildDailyNudgeRequests` auf, registriert alle Requests.

**Cancel-Funktion:**

```
static func cancelDailyNudges()
```

Cancelt alle Requests mit Prefix `"coach-nudge-"`.

**Wann Schedule-Funktion aufgerufen wird:**

In `MorningIntentionView` direkt nach dem Speichern der Intention (naechste Phase nach dem bestehenden AppStorage-Write aus 3a). Der Gap-Aufruf greift auf `IntentionEvaluationService` zu.

**Wann Cancel-Funktion aufgerufen wird:**

Beim App-Foreground (`scenePhase == .active`). Prueft ob Intention erfuellt (`IntentionEvaluationService.isFulfilled`). Wenn ja: `cancelDailyNudges()`. Wenn nein: keine Aktion (bestehende Notifications bleiben).

---

### 3. AppSettings — Neue Coach-Notification-Settings

`Sources/Models/AppSettings.swift`

Drei neue `@AppStorage`-Properties in der `// MARK: - Monster Coach` Section:

```swift
/// Whether daily intention nudge notifications are enabled
@AppStorage("coachDailyNudgesEnabled") var coachDailyNudgesEnabled: Bool = true

/// Maximum number of daily nudge notifications (1, 2 or 3)
@AppStorage("coachDailyNudgesMaxCount") var coachDailyNudgesMaxCount: Int = 2

/// Hour for nudge window start (0-23)
@AppStorage("coachNudgeWindowStartHour") var coachNudgeWindowStartHour: Int = 10

/// Hour for nudge window end (0-23)
@AppStorage("coachNudgeWindowEndHour") var coachNudgeWindowEndHour: Int = 18
```

Minute-Felder werden weggelassen — Stunden-Granularitaet reicht fuer ein Tages-Zeitfenster.

---

### 4. SettingsView — Neue Controls in Monster Coach Section

`Sources/Views/SettingsView.swift`

In der bestehenden Monster Coach Section, nach dem Morgen-Erinnerung-Toggle, werden neue Controls hinzugefuegt wenn `coachModeEnabled`:

```
Toggle "Tages-Erinnerungen"  [coachDailyNudgesEnabled]
  └─ wenn aktiv:
     Picker "Max. Erinnerungen"  [1 / 2 / 3, default 2]
     DatePicker "Von"  [Stunden, default 10:00]
     DatePicker "Bis"  [Stunden, default 18:00]
```

Neue `@AppStorage`-Deklarationen am View-Kopf:

```swift
@AppStorage("coachDailyNudgesEnabled") private var coachDailyNudgesEnabled: Bool = true
@AppStorage("coachDailyNudgesMaxCount") private var coachDailyNudgesMaxCount: Int = 2
@AppStorage("coachNudgeWindowStartHour") private var coachNudgeWindowStartHour: Int = 10
@AppStorage("coachNudgeWindowEndHour") private var coachNudgeWindowEndHour: Int = 18
```

Neue Binding-Helper (analog zu `intentionTimeBinding`/`morningTimeBinding`):

```swift
private var nudgeWindowStartBinding: Binding<Date>
private var nudgeWindowEndBinding: Binding<Date>
```

---

### 5. MorningIntentionView — Nudge Scheduling nach Intention-Setzen

`Sources/Views/MorningIntentionView.swift`

Ergaenzung an der Stelle wo die Intention gespeichert wird (bestehend aus Phase 3a). Nach dem AppStorage-Write:

```swift
if AppSettings.shared.coachDailyNudgesEnabled,
   AppSettings.shared.coachModeEnabled,
   selectedOptions != [.survival] {
    let gap = IntentionEvaluationService.detectGap(...)
    if let gap {
        NotificationService.scheduleDailyNudges(intention: ..., gap: gap)
    }
}
```

Der Context fuer `detectGap` wird als Dependency uebergeben — entweder als Parameter oder via Environment.

**Wichtig:** Wenn Survival gewaehlt wird — keine Nudges, keine Scheduling. Survival = absolute Ruhe.

---

### Wann wird auf Erfuellung geprueft?

In `FocusBloxApp.swift` (bestehendes Pattern via `scenePhase`):

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        // bestehend: Badge update, etc.
        // NEU:
        checkAndCancelFulfilledNudges()
    }
}
```

`checkAndCancelFulfilledNudges` laedt heutige Tasks + Focus Blocks und ruft `IntentionEvaluationService.isFulfilled` auf. Wenn erfuellt: `cancelDailyNudges()`.

---

## Dateien und Scoping

| Datei | Aenderung | Schaetzung |
|-------|-----------|-----------|
| `Sources/Services/IntentionEvaluationService.swift` | **Neu** — Evaluation + Gap-Detection | +100 LoC |
| `Sources/Services/NotificationService.swift` | Neuer MARK-Block Daily Nudges | +70 LoC |
| `Sources/Models/AppSettings.swift` | 4 neue `@AppStorage`-Properties | +12 LoC |
| `Sources/Views/SettingsView.swift` | 4 neue Controls + Bindings in Coach Section | +50 LoC |
| `Sources/Views/MorningIntentionView.swift` | Nudge-Scheduling nach Intention-Setzen | +15 LoC |
| `Sources/FocusBloxApp.swift` | Foreground-Check auf Erfuellung | +20 LoC |

**Gesamt: 5+1 Dateien (1 neu, 5 bestehend), ca. +267 LoC — knapp im Scope.**

---

## Architektur-Entscheidungen

### Warum IntentionEvaluationService als separate Datei?

Die Evaluation-Logik wird von zwei Subsystemen genutzt: Smart Notifications (Phase 3b) und Abend-Spiegel (Phase 3c). Eine gemeinsame Service-Schicht vermeidet Code-Duplizierung und macht die Logik unabhaengig testbar. Das Pattern existiert bereits im Projekt (NotificationService, SyncEngine als pure Logik-Layer).

### Warum Gap am Morgen berechnen, nicht spaeter?

Die Gap-Berechnung am Morgen ist der einzige valide Zeitpunkt wo der User gerade seine Intention gesetzt hat und der Status klar ist (keine Tasks erledigt, keine Blocks). Alternative waere: Notification zum Fire-Time im Hintergrund neu evaluieren (Background Processing). Das ist komplexer, benoetigt Background-Permissions und ist fuer diesen Anwendungsfall ueberdimensioniert. Der einfache Ansatz reicht: Notifications werden beim Setzen der Intention geplant und beim App-Foreground gecancelt wenn erfuellt.

### Warum nur Stunden-Granularitaet beim Zeitfenster?

Minuten-Granularitaet bei "Von 10:00 bis 18:00" bringt keinen Mehrwert fuer den User. Stunden reichen — die Settings sind einfacher, der Code kleiner.

### Warum maxCount als Picker (1/2/3) statt Slider?

Der User versteht "Max. 2 Erinnerungen pro Tag" sofort. Ein Slider mit beliebigen Werten (0-10) wuerde zu mehr Notifications fuehren und widerspricht der Stille-Regel. Drei fixe Optionen sind klar und sicher.

### FocusBloxApp.swift als 6. Datei

Technisch sind es 6 Dateien, aber `FocusBloxApp.swift` bekommt nur ~20 LoC fuer den Foreground-Check. Es waere moeglich den Check in `MorningIntentionView` selbst zu steuern (nur beim ersten Foreground nach Intention-Setzen). Aber der Foreground-Check in `FocusBloxApp` ist robuster — er funktioniert auch wenn der User die App komplett schliesst und wieder oeffnet. Das Pattern existiert bereits in `FocusBloxApp` (Badge-Updates beim Foreground).

---

## Was NICHT in Phase 3b enthalten ist

- **Abend-Spiegel** (Phase 3c) — die Abend-Auswertung und Review-Tab-Karte
- **Foundation Models Abend-Text** — AI-generierter persoenlicher Text
- **Abend Push-Notification** — separater Notification-Typ fuer 20:00
- **macOS** — Smart Notifications sind iOS-only (MorningIntentionView existiert nur im iOS-Target, scenePhase-Pruefung laeuft aber auf beiden Plattformen)
- **Dynamic Gap Re-evaluation** — der Gap wird einmalig am Morgen berechnet, nicht kontinuierlich neu evaluiert waehrend des Tages
