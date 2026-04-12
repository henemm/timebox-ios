# Bug-Analyse: "Du hast heute 120min" (#208)

## Symptom
Morning-Notification zeigt immer "Du hast 120 Min frei heute" — unabhängig von der tatsächlichen freien Zeit im Kalender.

## Agenten-Ergebnisse

### 1. Wiederholungs-Check
- Kein vorheriger Bug-Report für hardcoded freeMinutes
- BUG_169 (geschlossen) war verwandt (BGAppRefreshTask/Notification-Profil), aber adressierte nicht die Berechnung
- FEATURE_206 (offen) plant Coach-Morning mit freien Lücken, ist aber UI-Feature, kein Notification-Fix

### 2. Datenfluss-Trace
- **Bug-Stelle:** `SmartNotificationEngine.swift:467` — `freeMinutes: 120` hardcoded
- **Ebenfalls hardcoded:** `meetingCount: 0` (Zeile 468)
- **Korrekte Berechnung existiert:** `GapFinder.swift` berechnet echte freie Zeitslots aus Kalender-Events
- **OrganizeMyDayIntent** nutzt GapFinder korrekt — nur Notifications sind "blind"
- **CoachView/DayView** nutzen GapFinder korrekt

### 3. Alle Schreiber
- `freeMinutes` wird an 3 Stellen als Parameter akzeptiert: NotificationContentService, IntentionSuggestionService, SmartNotificationEngine
- NUR in SmartNotificationEngine wird der Wert hardcoded gesetzt (120)
- Es gibt KEINE zentrale Funktion die `freeMinutes` als aggregierten Int-Wert berechnet — GapFinder liefert TimeSlot-Arrays

### 4. Szenarien
- `precomputeNotificationContent()` hat KEINEN Zugriff auf EventKitRepository
- Kalender-Berechtigung wird nicht geprüft
- Cached Content wird für bis zu 7 Tage wiederverwendet
- Background Task hat keinen Kalender-Zugriff

### 5. Blast Radius
- **Betroffen:** Nur Morning-Notifications (SmartNotificationEngine)
- **NICHT betroffen:** OrganizeMyDayIntent (korrekt), CoachView (korrekt), BlockPlanningView (korrekt)
- **Zusätzlich hardcoded:** `focusMinutes: 0` in Evening-Notifications (Zeile 488)

## Hypothesen

### Hypothese 1: Hardcoded Placeholder nie ersetzt (HOCH)
- `freeMinutes: 120` war ein Placeholder während der Entwicklung
- GapFinder existierte, wurde aber nie in `precomputeNotificationContent` integriert
- **Beweis dafür:** Kommentar "// Morning: Find the most overdue task + free time estimate" (Zeile 455) deutet auf geplante Berechnung hin
- **Beweis dagegen:** Keiner — alle anderen Stellen (Intent, CoachView) nutzen GapFinder korrekt
- **Wahrscheinlichkeit: HOCH**

### Hypothese 2: Bewusste Entscheidung wegen Background-Limitierung (MITTEL)
- `precomputeNotificationContent` läuft möglicherweise im Background ohne EventKit-Zugriff
- Hardcoded Wert als bewusster Workaround
- **Beweis dafür:** Background Tasks haben eingeschränkten API-Zugriff
- **Beweis dagegen:** OrganizeMyDayIntent nutzt EventKit auch aus AppIntent-Kontext erfolgreich
- **Wahrscheinlichkeit: MITTEL**

### Hypothese 3: Zeitdruck/Vergessen (MITTEL)
- BUG_169 Fix fokussierte auf BGAppRefreshTask-Aktivierung, nicht auf Notification-Inhalte
- Die Berechnung wurde einfach vergessen
- **Wahrscheinlichkeit: MITTEL** (ergänzt Hypothese 1)

## Wahrscheinlichste Ursache
**Hypothese 1** — Placeholder nie ersetzt. GapFinder existiert und funktioniert, wurde aber nie in die Notification-Pipeline integriert. Die korrekte Lösung existiert bereits in OrganizeMyDayIntent als Vorlage.

## Debugging-Plan
1. In `precomputeNotificationContent` einen Logger setzen der die echte freie Zeit (via GapFinder) berechnet und ausgibt
2. Prüfen ob EventKitRepository im Background-Kontext funktioniert
3. Wenn ja: GapFinder-Berechnung einbauen, Summe der freien Minuten als `freeMinutes` übergeben
4. Wenn nein: Alternative Berechnung aus gespeicherten Kalender-Daten

## Blast Radius
- **Fix-Scope:** Primär `SmartNotificationEngine.swift`, aber Signatur von `precomputeNotificationContent` muss um `eventKitRepo`-Parameter erweitert werden
- **Zusätzlich hardcoded:** `meetingCount: 0` (Morning) und `focusMinutes: 0` (Evening) — gleiche Stelle
- **Evening-Fix ist ANDERS:** `focusMinutes` braucht Summe der heutigen FocusBlock-Dauer (rückblickend), nicht GapFinder (vorausschauend)
- **Keine anderen Features betroffen** — CoachView, DayView, Intent nutzen eigene korrekte Berechnung

## Challenger-Ergebnisse (Verdict: LÜCKEN)
1. **Signaturänderung nötig:** `precomputeNotificationContent` hat keinen `eventKitRepo`-Parameter — muss durchgereicht werden
2. **Plattform-Divergenz:** macOS hat kein `registerBackgroundTask` (`#if !os(macOS)`), Reconcile läuft anders
3. **7-Tage-Cache:** `cachedMorningContent` wird für alle 7 geplanten Notifications wiederverwendet — selber Text für 7 Tage
4. **Background EventKit:** Ob EventKit-Fetch im BGAppRefreshTask funktioniert ist ungeprüft (OrganizeMyDayIntent läuft als AppIntent = privilegierter Kontext)
5. **bgEventKitRepo existiert:** In `registerBackgroundTask` wird ein EventKitRepo gespeichert — könnte ohne Signaturänderung nutzbar sein (nur iOS)
