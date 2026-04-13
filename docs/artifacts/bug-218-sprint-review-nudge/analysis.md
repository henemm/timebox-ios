# Bug #218 — Sprint-Review Hinweis kommt obwohl erledigt

## Symptom
Push-Notification "Zeit für dein Sprint Review!" erscheint im Notification Center, obwohl der User das Sprint Review bereits in-app abgeschlossen hat.

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (Wiederholungs-Check)
- 3 verwandte Bugs gefunden: #42 (Dauerloop), #211 (Abort-Cleanup), #221 (Orphan Live Activities)
- Alle fixten UI-State oder Live Activity Probleme
- **Keiner hat delivered Notification Cleanup adressiert**

### Agent 2 (Datenfluss-Trace)
- Notification wird in `SmartNotificationEngine.buildTimerRequests()` (Zeile 133) erstellt
- Registriert via `reconcile()` → `center.add(request)` (Zeile 75)
- Trigger: `UNTimeIntervalNotificationTrigger` zum Block-Ende-Zeitpunkt
- `removeAllPendingNotificationRequests()` entfernt nur PENDING (Zeile 65)
- **KEIN `removeDeliveredNotifications()` im gesamten Codebase**
- Sprint Review Dismiss (`FocusLiveView.swift:160-172`) hat **kein Notification-Cleanup**

### Agent 3 (Alle Schreiber)
- 7 Stellen die Notifications hinzufügen (`center.add`)
- 7 Stellen die PENDING entfernen (`removePendingNotificationRequests`)
- **0 Stellen die DELIVERED entfernen**
- `cancelFocusBlockNotification()` existiert (NotificationService:248), wird aber nirgends aufgerufen

### Agent 4 (Szenarien)
- **6 von 6 Szenarien** führen zum Bug:
  1. Block endet, App im Vordergrund → Notification delivered, nicht entfernt
  2. Block endet, App im Hintergrund → Notification delivered, nicht entfernt
  3. User startet Review früh → Pending Notification wird trotzdem delivered
  4. User bricht Block ab → Pending Notification wird trotzdem delivered
  5. App-Neustart nach Block-Ende → Delivered Notification bleibt
  6. reconcile() nach Dismiss → Nur pending entfernt, nicht delivered

### Agent 5 (Blast Radius)
- **ALLE 8 Notification-Typen** haben dasselbe Problem (keine delivered Cleanup)
- Besonders kritisch: Block-End, Morning, Evening, DueDate
- Kein einziges `removeDeliveredNotifications()` oder `getDeliveredNotifications()` im Code

## Hypothesen

### Hypothese 1: Fehlende `removeDeliveredNotifications()` nach Sprint Review Dismiss
- **Wahrscheinlichkeit: HOCH**
- **Beweis dafür:** Kein einziger `removeDeliveredNotifications` Aufruf im gesamten Code. Sprint Review onDismiss (FocusLiveView:160-172) setzt nur `reviewDismissed = true` und ruft `loadData()` auf — kein Notification-Cleanup.
- **Beweis dagegen:** Keiner. Die Apple API ist klar: `removeAllPendingNotificationRequests()` entfernt nur geplante, nicht zugestellte Notifications.

### Hypothese 2: Fehlendes `reconcile()` nach Sprint Review Dismiss (pending Notifications)
- **Wahrscheinlichkeit: HOCH (ergänzend zu H1)**
- **Beweis dafür:** `checkBlockEnd()` (Zeile 710-747) und `onDismiss` (Zeile 160-172) rufen KEIN `reconcile()` auf. Bei Szenario 3 (Early Review) und 4 (Abort) bleibt die Notification PENDING und wird später delivered.
- **Beweis dagegen:** Wenn die App im Vordergrund bleibt und `reconcile()` durch andere Events getriggert wird (z.B. taskChanged), werden pending Notifications indirekt entfernt. Aber das ist nicht garantiert.

### Hypothese 3: `cancelFocusBlockNotification()` ist Dead Code
- **Wahrscheinlichkeit: MITTEL (verstärkt H1+H2)**
- **Beweis dafür:** Die Funktion existiert in NotificationService:248-253, wird aber nirgends aufgerufen. Sie könnte genau den Fall abdecken, wird aber nicht genutzt.
- **Beweis dagegen:** Ist kein eigenständiger Bug, sondern Indikator für das fehlende Cleanup-Pattern.

## Wahrscheinlichste Ursache

**Kombination aus H1 + H2:** Nach Sprint Review Dismiss werden weder:
- DELIVERED Notifications entfernt (`removeDeliveredNotifications`)
- PENDING Notifications entfernt (kein `reconcile()` oder `cancelFocusBlockNotification()`)

Der Fix muss BEIDES adressieren:
1. Delivered Notification entfernen nach Dismiss
2. Pending Notification entfernen bei Early Review / Abort

## Debugging-Plan (falls gewünscht)

**Bestätigung H1:** Nach Sprint Review Dismiss `UNUserNotificationCenter.current().getDeliveredNotifications()` aufrufen und loggen — wenn `focus-block-end-{blockID}` in der Liste ist, bestätigt das H1.

**Bestätigung H2:** Bei Early Review (Szenario 3) nach Dismiss `UNUserNotificationCenter.current().getPendingNotificationRequests()` aufrufen — wenn `focus-block-end-{blockID}` noch pending ist, bestätigt das H2.

**Plattform:** iOS primär (Push-Notifications im Notification Center). macOS hat dasselbe Code-Pattern.

## Blast Radius

| Notification-Typ | Prefix | Delivered Cleanup? | Risiko |
|---|---|---|---|
| Focus Block End | `focus-block-end-` | Nein | **BUG #218** |
| Focus Block Start | `focus-block-start-` | Nein | Mittel |
| Morning Review | `focusblox.morning.` | Nein | Hoch |
| Evening Review | `focusblox.review.` | Nein | Hoch |
| Due Date Morning | `due-date-morning-` | Nein | Hoch |
| Due Date Advance | `due-date-advance-` | Nein | Hoch |
| Task Overdue | `task-timer-` | Nein | Mittel |
| Backlog Hygiene | `focusblox.backlog-hygiene` | Nein | Niedrig |

**Empfehlung:** Bug #218 fokussiert auf Block-End-Notification fixen. Blast Radius (andere Typen) als separates Ticket.

## Challenge-Runde 1: Lücken geschlossen

### Lücke 1: Szenario 3 (Early Review) — Bestätigt
`allTasksCompletedView` in FocusLiveView:504 hat Button "Sprint Review starten" der `showSprintReview = true` setzt BEVOR `block.isPast`. Die Pending Block-End-Notification wird NICHT entfernt und wird später delivered.

### Lücke 2: cancelFocusBlockNotification() ist Dead Code — Bestätigt
Grep zeigt: Nur in Tests (SmartNotificationEnginePhaseBTests) referenziert, KEINE Aufrufe im Produktionscode. RW_0.1b-Migration hat diese Funktion vollständig durch reconcile() ersetzt, aber reconcile() entfernt nur pending, nicht delivered.

### Lücke 3: Reconcile nach Dismiss ist sicher
`buildFocusBlockEndNotificationRequest` hat `guard timeInterval > 0` (NotificationService:290). Wenn Block bereits past, wird KEINE neue Notification erstellt. Ein reconcile() nach Dismiss würde also keine neue Block-End-Notification erstellen.

### Lücke 4: macOS gleiches Problem
`MacFocusView.swift:68-84` — onDismiss setzt nur `reviewDismissed = true` + `loadData()`, kein reconcile(), kein Notification-Cleanup. Identisches Problem.

### Lücke 5: reviewDismissed ist nicht persistent
`@State private var reviewDismissed = false` — geht bei App-Kill verloren. Nach Neustart wird Sprint Review Sheet erneut gezeigt (gewolltes Verhalten), aber die delivered Notification bleibt trotzdem. Fix adressiert dies durch Cleanup beim Dismiss.

### Aktualisierte Haupthypothese
Kombination H1 + H2 bleibt korrekt. Alle Lücken stärken die Hypothese statt sie zu schwächen.
