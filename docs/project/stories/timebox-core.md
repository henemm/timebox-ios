# User Story: TimeBox Core

> Erstellt: 2026-01-22
> Status: Approved
> Produkt: TimeBox

## JTBD Statement

**When** ich freie Zeitblöcke zwischen meinen Terminen habe,
**I want to** diese Blöcke bewusst mit Aufgaben füllen, die mir wichtig sind – und eine harte Grenze haben, die mich zum nächsten Thema schickt,
**So that** ich am Ende des Tages sehe, dass ich die Dinge getan habe, die mir wichtig sind – statt nur reagiert zu haben.

## Kontext

### Die Situation
Ende des Tages: Diffuses Gefühl, dass "schon wieder ein Tag vorbei ist", ohne die wichtigen Dinge getan zu haben. Nicht die Termine sind das Problem – die stehen fest. Es ist die **Zeit dazwischen**. Die freien Blöcke, die eigentlich Potenzial sind, aber zu oft zerfließen.

Das Problem ist nicht Zeitmangel, sondern **Fokusmangel**. Die Zeitblöcke sind da, aber sie werden nicht für die richtigen Dinge genutzt. Eine Sache (z.B. Claude Code) dehnt sich aus und frisst die andere (z.B. Klavier spielen).

### Das Problem heute
- Apple Reminders hat die ToDos, Apple/Google Kalender hat die Termine
- Aber: Keine Sicht auf die **freie Zeit zwischen Terminen**
- Keine **harte TimeBox** die stoppt und weiterschickt
- Ergebnis: Reaktiv statt proaktiv – der Tag passiert, statt dass man ihn gestaltet

### Alternativen
- Apple Reminders + Kalender: Zeigt nicht die freien Lücken, keine TimeBox-Funktion
- Papierkalender: Keine Integration, kein Timer
- Im Kopf behalten: Funktioniert nicht, man lässt sich treiben

## Dimensionen

### Funktional
- Freie Zeitblöcke im Kalender erkennen und anzeigen
- Aufgaben aus dem Backlog in diese Blöcke einplanen
- Timer mit Fortschrittsanzeige während des Fokusblocks
- Gong/Alarm am Ende des Blocks
- Rückblick: Was wurde erledigt (Tag/Woche)

### Emotional
- **Morgens:** Intentionalität – "Ich entscheide, was heute wichtig ist"
- **Tagsüber:** Fokus – "Ich bin bei der Sache, nicht getrieben"
- **Abends:** Zufriedenheit – "Ich habe die wichtigen Dinge getan"
- **Nicht:** Eingeengt oder überplant fühlen

### Sozial
- Nicht primär relevant (persönliches Produktivitätstool)
- Eventuell: Stolz zeigen können, was man geschafft hat

## Live-Fokus-Modus (Herzstück)

**Während des Fokusblocks:**
- Sehe aktuelle Aufgabe + ablaufenden Fortschrittsbalken
- Sichtbar auf: App, Lockscreen, Dynamic Island
- Sehe bereits die nächste Aufgabe

**Vor Ende:**
- Konfigurierbarer Hinweis ("noch X Minuten")

**Am Ende (Gong):**
- Auswahl: "Erledigt" oder "Nicht fertig"
- Nicht fertig → zurück ins Backlog

**Offener Wunsch:**
- Wenn "nicht fertig": Option, im nächsten Block weiterzumachen (Spontan-Tausch?)

## Kategorien (Bedeutung geben)

Aufgaben können kategorisiert werden, um im Rückblick zu sehen "wofür" die Zeit verwendet wurde:

| Kategorie | Bedeutung |
|-----------|-----------|
| Schneeschaufeln | Pflicht, muss einfach gemacht werden |
| Weitergeben | Wissen/Fähigkeiten zurückgeben |
| Lernen | Neues lernen, wachsen |
| Wertschaffend | Geld verdienen, produktiv |
| Aufladen | Batterien laden, Regeneration |

## Erfolgskriterien

- [ ] Ich plane morgens bewusst, fühle mich aber nicht eingeengt
- [ ] Ich sehe die freien Zeitblöcke zwischen meinen Terminen
- [ ] Die harte TimeBox (Gong) hält mich bei der Stange
- [ ] Ich sehe während des Fokusblocks: Aufgabe, Fortschritt, nächste Aufgabe
- [ ] Ich sehe abends/wöchentlich was ich geschafft habe
- [ ] Ich habe das Gefühl: Ich gestalte meine Zeit, sie passiert mir nicht

## Abgeleitete Features

| Feature | Priorität | Status |
|---------|-----------|--------|
| Backlog-View (Aufgaben sortieren) | Must | Done |
| Planning-View (Aufgaben in Blöcke ziehen) | Must | Done |
| Live-Fokus-Modus mit Timer | Must | Done |
| Lockscreen / Dynamic Island | Must | In Progress |
| Rückblick (Tag/Woche) | Should | Backlog |
| Kategorien für Aufgaben | Could | Backlog |
| Spontan-Tausch bei "nicht fertig" | Could | Backlog |

---
*Ermittelt im JTBD-Dialog am 2026-01-22*
