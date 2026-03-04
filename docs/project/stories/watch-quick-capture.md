# User Story: Watch Quick Capture

> Erstellt: 2026-03-04
> Status: Approved
> Produkt: FocusBlox

## JTBD Statement

**When** ich unterwegs bin (laufen, einkaufen, Hände nicht frei),
**I want to** einen Gedanken/Task blitzschnell auf der Apple Watch festhalten,
**So that** der Gedanke nicht verloren geht und ich ihn später auf dem iPhone verfeinern kann.

## Kontext

### Die Situation
Henning ist draußen unterwegs — beim Laufen, Einkaufen, oder in einer Situation wo die Hände nicht frei sind und das iPhone nicht griffbereit ist. In dem Moment kommt ein Gedanke ("Milch kaufen", "Meeting mit Lisa vorbereiten"), der sofort festgehalten werden muss, bevor er verloren geht.

### Das Problem heute
Der aktuelle Watch-Flow hat zu viele Interaktionsschritte:
1. App öffnen
2. "Task hinzufügen" Button tippen
3. Diktat-Keyboard erscheint → sprechen
4. OK tippen
5. Bestätigungs-Screen (2 Sekunden warten)

Mit vollen Händen oder beim Laufen sind das mindestens 3 bewusste Interaktionen zu viel. Die Hürde ist hoch genug, dass man es oft lässt und den Gedanken verliert.

### Alternativen
- Apple Reminders via Siri: Funktioniert, aber Task landet nicht in FocusBlox-Workflow
- Sich selbst eine Sprachnachricht schicken: Umständlich, muss später manuell übertragen werden
- Einfach merken: Klappt oft nicht

## Dimensionen

### Funktional
- Complication auf Watchface für 1-Tap-Zugang
- Diktat startet automatisch nach Tap (kein weiterer Button)
- Erkannter Text wird kurz angezeigt (Abbruch bei Fehlererkennung möglich)
- Auto-Save nach ~1.5s ohne Abbruch
- Siri Shortcut für komplett freihändige Erfassung
- CloudKit-Sync zum iPhone/Mac mit TBD-Badge

### Emotional
- **Erleichterung:** Gedanke ist gesichert, ich kann ihn loslassen
- **Mühelosigkeit:** Es fühlt sich so leicht an wie "laut denken"
- **Vertrauen:** Ich weiß, der Task kommt auf meinem iPhone an

### Sozial
- Nicht relevant — private Aufgabenverwaltung

## Erfolgskriterien

- [x] Complication auf Watchface verfügbar (1-Tap zum Diktat)
- [x] Diktat startet automatisch nach Complication-Tap (kein extra Button)
- [ ] Erkannter Text wird kurz angezeigt (~1.5s, mit Abbruch-Option)
- [ ] Auto-Save nach Anzeige-Timeout + Haptik-Feedback (nur Vibration, kein Screen)
- [ ] Kein Bestätigungs-Screen — Haptik reicht als Feedback
- [ ] Siri Shortcut: "Hey Siri, [App-Name] [Task-Text]" legt Task direkt an
- [ ] Task erscheint auf iPhone/Mac via CloudKit-Sync mit TBD-Badge
- [ ] Gesamtflow Complication: 1 Tap + Sprechen + fertig (max 3 Sekunden aktive Interaktion)
- [ ] Gesamtflow Siri: 0 Taps, rein sprachgesteuert

## Abgeleitete Features

| Feature | Priorität | Status |
|---------|-----------|--------|
| Watch Complication (Quick Capture) | Must | Done |
| Auto-Diktat nach Complication-Tap | Must | Done |
| Auto-Save mit Haptik (kein Bestätigungs-Screen) | Must | Done |
| Text-Preview mit Abbruch-Option | Must | Done |
| Siri Shortcut Integration | Must | Backlog |
| Bestehenden Watch-Flow vereinfachen (In-App) | Should | Done |

## Technische Notizen (Ist-Zustand)

Aktueller Watch-Code:
- `FocusBloxWatch Watch App/ContentView.swift` — Hauptscreen mit Button
- `FocusBloxWatch Watch App/VoiceInputSheet.swift` — Diktat-Eingabe
- `FocusBloxWatch Watch App/ConfirmationView.swift` — Bestätigungs-Screen (soll entfallen)

Aktuelle Architektur:
- Task wird als `LocalTask` mit `needsTitleImprovement = true` gespeichert
- CloudKit-Sync via App Group + Private Database
- Alle Metadaten (Priorität, Dauer etc.) bleiben nil → TBD-Badge auf iPhone

---
*Ermittelt im JTBD-Dialog am 2026-03-04*
