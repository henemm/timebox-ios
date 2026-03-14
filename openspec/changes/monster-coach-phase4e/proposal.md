# Proposal: Monster Coach Phase 4e — Monster in Push-Notifications

> Erstellt: 2026-03-14
> Status: Zur Freigabe
> Bezug: User Story `docs/project/stories/monster-coach.md` — Section "Monster-Grafiken"

---

## Was und Warum

### Das Problem

Die bestehenden Coach-Notifications (Morgen-Erinnerung, Abend-Erinnerung, Tages-Nudges) sind reine Text-Notifications. Sie zeigen den richtigen Inhalt, aber kein visuelles Monster-Bild. Gerade in der Notification-Center-Ansicht, wo die Notification laenger sichtbar ist, geht die Monster-Identitaet komplett verloren — obwohl das Monster das Herzstuck des Coach-Systems ist.

### Was diese Phase loest

Phase 4e fuegt den drei Coach-Notification-Typen ein Monster-Bild als Rich Notification Attachment hinzu. Das Bild erscheint rechts neben dem Notification-Text als Thumbnail, und bei Long-Press auf die Notification als grosses Bild.

Welches Monster erscheint haengt direkt von der gesetzten Morgen-Intention ab:

| Intention | Discipline | Monster |
|-----------|-----------|---------|
| `survival` | `.ausdauer` | Golem (`monsterAusdauer`) |
| `fokus` | `.fokus` | Eule (`monsterFokus`) |
| `bhag` | `.mut` | Feuer (`monsterMut`) |
| `balance` | `.ausdauer` | Golem (`monsterAusdauer`) |
| `growth` | `.fokus` | Eule (`monsterFokus`) |
| `connection` | `.konsequenz` | Troll (`monsterKonsequenz`) |

Dieses Mapping existiert bereits vollstaendig in `IntentionOption.monsterDiscipline` (Phase 4a). Nichts neues zu definieren — nur nutzen.

---

## Technischer Ansatz: UNNotificationAttachment

iOS erlaubt `UNNotificationAttachment` als Bild-Anhang zu einer lokalen Notification. Das Bild muss als temporaere Datei im Filesystem vorliegen — `UNNotificationAttachment` akzeptiert keine Asset-Catalog-Bilder direkt.

**Ablauf:**
1. `UIImage(named: imageName)` aus dem Asset Catalog laden
2. PNG-Data erzeugen und in ein temporaeres Verzeichnis schreiben
3. `UNNotificationAttachment(identifier:url:options:)` erstellen
4. `content.attachments = [attachment]` setzen

Dieser Schritt ist einmalig in einer neuen Hilfsfunktion `buildMonsterAttachment(for:)` zu implementieren, die von allen drei Notification-Builder-Funktionen genutzt wird.

### Plattform-Abgrenzung

`UNNotificationAttachment` mit Bild-Data existiert nur auf iOS. Auf macOS werden Rich Attachments anders gehandhabt und sind fuer lokale Notifications deutlich eingeschraenkter. Die gesamte Attachment-Logik muss in `#if !os(macOS)` eingebettet werden — analog zu `updateOverdueBadge` weiter oben im selben File.

---

## Scope: Was gebaut wird

### 1. NotificationService.swift — Neue Hilfsfunktion + Attachment in drei Buildern

`Sources/Services/NotificationService.swift`

**Neue private Hilfsfunktion:**

```
#if !os(macOS)
private static func buildMonsterAttachment(
    for intention: IntentionOption
) -> UNNotificationAttachment?
```

Ablauf:
- `imageName = intention.monsterDiscipline.imageName`
- `UIImage(named: imageName)` laden
- PNG-Data schreiben nach `FileManager.default.temporaryDirectory`
- Filename: `"monster-\(imageName).png"` (eindeutig genug, kein UUID noetig)
- `UNNotificationAttachment` erstellen und zurueckgeben
- Bei jedem Fehler-Schritt `nil` zurueckgeben (safe fallback — Notification erscheint ohne Bild)

**Attachment in bestehende Builder einhaengen:**

Drei bestehende Builder-Funktionen erhalten eine optionale `intention: IntentionOption?`-Parameter-Erweiterung:

| Builder | Intention-Quelle |
|---------|-----------------|
| `buildIntentionReminderRequest(hour:minute:)` | Neu: `intention: IntentionOption` als Parameter |
| `buildEveningReminderRequest(hour:minute:now:)` | Neu: `intention: IntentionOption?` als Parameter |
| `buildDailyNudgeRequests(intention:gap:...)` | Bereits `intention: IntentionOption` — nur Attachment hinzufuegen |

Jede Builder-Funktion ruft `buildMonsterAttachment(for: intention)` auf und setzt `content.attachments` wenn nicht nil.

**Wichtig:** Default-Parameter `nil` fuer `intention` bei den Builder-Funktionen sicherstellt Backward-Kompatibilitaet aller bestehenden Unit Tests — die uebergeben keinen Intention-Parameter und erhalten weiterhin eine Notification ohne Attachment.

**Scheduling-Funktionen muessen Intention uebergeben:**

- `scheduleIntentionReminder(hour:minute:)` → bekommt zusaetzlich `intention: IntentionOption`
- `scheduleEveningReminder(hour:minute:)` → bekommt zusaetzlich `intention: IntentionOption?`
- `scheduleDailyNudges(intention:gap:)` → bereits vorhanden, wird intern weitergereicht

**Aufrufer muessen angepasst werden:**

- `MorningIntentionView.swift` ruft `scheduleIntentionReminder` auf — uebergibt die gespeicherte Intention
- `FocusBloxApp.swift` ruft `scheduleEveningReminder` und `scheduleIntentionReminder` auf — laedt `DailyIntention.load().selections.first` fuer die Intention

---

## Dateien und Scoping

| Datei | Aenderung | Schaetzung |
|-------|-----------|-----------|
| `Sources/Services/NotificationService.swift` | `buildMonsterAttachment()` + Attachment in 3 Buildern + Parameter-Erweiterung | +50 LoC |
| `Sources/Views/MorningIntentionView.swift` | `scheduleIntentionReminder`-Aufruf + Intention uebergeben | +5 LoC |
| `Sources/FocusBloxApp.swift` | `scheduleEveningReminder`-Aufruf + Intention uebergeben | +8 LoC |

**Gesamt: 3 Dateien, ca. +63 LoC — deutlich im Scope (Limit: 4-5 Dateien, 250 LoC).**

---

## Architektur-Entscheidungen

### Warum keine Notification Service Extension?

Eine Notification Service Extension kann eingehende Remote Notifications abfangen und Attachments hinzufuegen. Hier handelt es sich aber um lokale Notifications — die Extension wird dafuer nicht benoetigt. Das Attachment kann direkt beim Erstellen der Notification angehaengt werden.

### Warum temporaere Datei statt Asset-URL?

`UNNotificationAttachment` akzeptiert nur `file://`-URLs, keine `asset://`-URLs oder in-memory Data. Die temporaere Datei ist der einzig valide Weg. Der Dateiname ist deterministisch (`monster-monsterFokus.png`) statt UUID-basiert, damit kein Muell im Temp-Verzeichnis angehaeuft wird — jeder Schreibvorgang ueberschreibt dieselbe Datei.

### Warum `intention: IntentionOption?` mit nil-Default?

Backward-Kompatibilitaet fuer alle bestehenden Unit Tests. Die Tests fuer `buildIntentionReminderRequest`, `buildEveningReminderRequest` und `buildDailyNudgeRequests` muessen nicht angepasst werden — sie erhalten weiterhin Notifications ohne Attachment und bleiben gruen.

### Warum nicht alle Notification-Typen?

Nur die drei Coach-Notification-Typen erhalten Monster-Bilder. Task-Timer-Notifications, Focus-Block-Notifications und Due-Date-Notifications haben keinen Bezug zum Monster Coach System — dort waere ein Monster-Bild deplaziert und verwirrend.

### macOS: kein Attachment

Auf macOS werden die Builder-Funktionen ebenfalls genutzt (z.B. fuer Due-Date-Notifications). Der gesamte Attachment-Code ist in `#if !os(macOS)` eingebettet. macOS-Notifications erhalten kein Bild — das ist korrekt, da macOS keine vergleichbare Notification-Attachment-API fuer lokale Notifications bietet.

---

## Was NICHT in Phase 4e enthalten ist

- **Notification Service Extension** — nicht noetig fuer lokale Notifications
- **Due-Date-Notifications mit Monster** — kein Coach-Bezug
- **Focus-Block-Notifications mit Monster** — kein Coach-Bezug
- **macOS Rich Notifications** — API-Einschraenkung, zudem hat macOS noch keine Coach-Views (Phase 6)
- **Dynamischer Monster-Wechsel bei mehreren Intentions** — bei Multi-Select wird das erste Monster der ersten Intention verwendet (einfachste Regel, kein Mehrwert durch Komplexitaet)
