# User Story: Quick Capture

> Erstellt: 2026-01-25
> Status: Approved
> Produkt: FocusBlox

## JTBD Statement

**When** mir unterwegs oder bei der Arbeit ein Gedanke/Todo einfällt,
**I want to** ihn mit minimalem Aufwand festhalten (1-2 Taps + Sprache/Text),
**So that** ich ihn nicht vergesse und später in Ruhe Details ergänzen kann.

## Kontext

### Die Situation

Drei typische Szenarien:

1. **Watch - Beim Spaziergang**
   - Kontext: Unterwegs mit Hund, Hände nicht frei
   - Eingabe: Sprache (nach Button-Tap)
   - Erwartung: Später in App vorfinden und anreichern

2. **iPhone - An der Supermarkt-Kasse**
   - Kontext: Kurzer Moment, abgelenkt, schnell
   - Eingabe: Kurze Textnotiz via Button/Widget
   - Optional: Wichtigkeit + Dringlichkeit per Tap wählbar
   - Erwartung: Später in App ergänzen

3. **Mac - Mitten in der Arbeit**
   - Kontext: Am Schreibtisch, in Flow-Zustand, will nicht unterbrechen
   - Eingabe: CMD+Leertaste (Spotlight) + einfache Syntax
   - Erwartung: Kein App-Wechsel nötig, Todo landet im Backlog

### Das Problem heute

Die App erfordert zu viele Schritte:
1. App öffnen
2. Richtigen Tab finden
3. Formular ausfüllen (Titel, Dauer, Kategorie, ...)

**Konsequenzen:**
- Gedanke ist weg, bevor man fertig ist
- "Mach ich später" → vergessen
- Zu viel Friction → man nutzt es nicht

### Alternativen (aktuell)

- Apple Reminders (schneller, aber keine FocusBlox-Integration)
- Notizen-App (noch ein Ort mehr)
- Sich merken (funktioniert nicht)

## Dimensionen

### Funktional
- Max 2 Taps/Klicks bis zur Eingabe
- Nur Titel ist Pflicht, alles andere optional
- Capture landet als "Inbox"-Item im Backlog
- Später anreichern möglich (Wichtigkeit, Dringlichkeit, Art, Dauer)

### Emotional
- **Vermeiden:** "Mist, was wollte ich nochmal..." (Gedanke verloren)
- **Vermeiden:** "Das dauert zu lange, ich mach's später" (Friction)
- **Erreichen:** Erleichterung - "Ist notiert, kann ich vergessen"
- **Erreichen:** Vertrauen - "Ich weiß, es ist im System"

### Sozial
- Nicht relevant für diesen Job

## Erfolgskriterien

- [ ] Max 2 Taps/Klicks bis zur Eingabe (auf allen Plattformen)
- [ ] Eingabe erscheint im Backlog als "Inbox"-Item (erkennbar als unverarbeitet)
- [ ] Optional: Wichtigkeit + Dringlichkeit beim Capture wählbar
- [ ] Watch: Spracheingabe nach Button-Tap
- [ ] iPhone: Widget oder Lock Screen Button
- [ ] Mac: Spotlight-Integration mit einfacher Syntax
- [ ] Später anreichern funktioniert reibungslos

## Abgeleitete Features

| Feature | Plattform | Priorität | Status |
|---------|-----------|-----------|--------|
| Inbox-Konzept | App (alle) | Must | Backlog |
| Watch Voice Capture | watchOS | Must | Backlog |
| Quick Add Widget | iOS | Must | Backlog |
| Lock Screen Quick Add | iOS | Should | Backlog |
| Spotlight Integration | macOS | Should | Backlog |
| Wichtigkeit/Dringlichkeit Quick-Select | iOS/Watch | Should | Backlog |

## Nebeneffekt: Terminologie

**Umbenennung erforderlich:**
- "Priorität" → "Wichtigkeit"

Grund: "Priorität" ist semantisch zu nah an "Dringlichkeit".
Die Eisenhower-Matrix unterscheidet klar:
- **Wichtigkeit** = Impact/Bedeutung (wichtig vs. unwichtig)
- **Dringlichkeit** = Zeitdruck (dringend vs. kann warten)

## Referenzen

- Bestehende Recherche: `docs/research/ios-task-input-methods.md`
- Bisheriges MVP (ohne Nutzen): `docs/specs/features/quick-capture-launcher.md`

---

*Ermittelt im JTBD-Dialog am 2026-01-25*
