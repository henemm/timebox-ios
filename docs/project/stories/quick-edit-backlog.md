# User Story: Quick Edit Tasks im Backlog

> Erstellt: 2026-01-27
> Status: Draft
> Produkt: FocusBlox

## JTBD Statement

**When** ich mein Backlog durchschaue, um zu entscheiden, was ich als naechstes tun will,
**I want to** unvollstaendige oder falsche Task-Metadaten (Kategorie, Prioritaet, Wichtigkeit, Dauer) mit moeglichst wenig Taps korrigieren,
**So that** ich meinen Planungs-Flow nicht unterbrechen muss und den Ueberblick im Backlog behalte.

## Kontext

### Die Situation
Der Nutzer plant seinen naechsten Schritt und schaut dafuer sein Backlog durch. Dabei faellt auf, dass ein Task nicht vollstaendig oder falsch eingeordnet ist - z.B. falsche Kategorie, fehlende Prioritaet oder falsche Dauer.

### Das Problem heute
Der aktuelle Edit-Flow erfordert 3 Schritte:
1. Task antippen (oeffnet Detail-Sheet)
2. Im Detail-Sheet auf "Bearbeiten" klicken
3. Erst dann kann man Aenderungen vornehmen

Das ist umstaendlich und nach dem Zurueckkehren ins Backlog hat man den Kontext verloren (Scroll-Position, mentaler Ueberblick).

Das Detail-Sheet als Zwischenschritt bietet keinen Mehrwert, wenn man nur schnell eine Eigenschaft aendern will.

### Alternativen
- Keine Workarounds vorhanden
- Nutzer lebt mit unvollstaendigen Tasks oder nimmt den umstaendlichen 3-Schritt-Flow in Kauf

## Dimensionen

### Funktional
- Long-Press auf einen Task oeffnet direkt den Edit-Modus
- Inline-Editing: Einzelne Metadaten-Elemente (Kategorie, Prioritaet, Wichtigkeit, Dauer) direkt in der Task-Zeile antippen - kleines Popup zur Auswahl erscheint
- Backlog-Ansicht bleibt sichtbar und Scroll-Position bleibt erhalten

### Emotional
- Schnell und reibungslos - kein Gefuehl von Umstaendlichkeit
- In Kontrolle bleiben - den Planungs-Flow nicht verlieren
- Ueberblick behalten - nicht den Kontext im Backlog verlieren

### Sozial
- Nicht relevant fuer diese Story

## Erfolgskriterien

- [ ] Kategorie, Prioritaet, Wichtigkeit und Dauer sind mit max. 2 Taps aenderbar
- [ ] Der Nutzer bleibt im Backlog (kein Sheet-Wechsel noetig)
- [ ] Die Scroll-Position geht nicht verloren
- [ ] Long-Press auf Task oeffnet direkt Edit-Modus
- [ ] Inline-Popups fuer einzelne Metadaten-Felder funktionieren

## Abgeleitete Features

| Feature | Prioritaet | Status |
|---------|-----------|--------|
| Long-Press Context Menu fuer Tasks | Must | Backlog |
| Inline-Editing Popups (Kategorie, Prioritaet, Dauer) | Must | Backlog |
| Detail-Sheet Zwischenschritt ueberpruefen/vereinfachen | Should | Backlog |

---
*Ermittelt im JTBD-Dialog am 2026-01-27*
