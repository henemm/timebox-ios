---
entity_id: monster-graphics-phase4
type: feature
created: 2026-03-13
updated: 2026-03-13
status: approved
version: "1.0"
tags: [monster-coach, graphics, discipline, ui]
---

# Monster-Grafiken & Discipline-Visualisierung (Phase 4)

## Approval

- [x] Approved (Henning, 2026-03-13)

## Purpose

4 Monster-Grafiken (PNG, transparenter Hintergrund) fuer die 4 Disciplines ins Projekt integrieren und an den relevanten Stellen anzeigen: Morgen-Dialog, Abend-Spiegel, Task-Zeilen, Push-Notifications.

## Quelldateien (Monster-Grafiken)

Die PNGs liegen in Hennings Downloads-Ordner:

| Datei | Discipline | Asset-Name |
|-------|-----------|------------|
| `Gemini_Generated_Image_pez16ipez16ipez1.png` | Fokus (Blau) | `monsterFokus` |
| `Gemini_Generated_Image_a8pm6na8pm6na8pm.png` | Mut (Orange) | `monsterMut` |
| `Gemini_Generated_Image_qy0hhcqy0hhcqy0h.png` | Ausdauer (Grau) | `monsterAusdauer` |
| `Gemini_Generated_Image_3ult7e3ult7e3ult.png` | Konsequenz (Gruen) | `monsterKonsequenz` |

Ziel: `Resources/Assets.xcassets/` als Image Sets.

## Monster-Discipline Mapping

| Discipline | Farbe | Monster-Charakter | Beschreibung |
|-----------|-------|-------------------|--------------|
| Fokus | Blau | Eule mit Lupe | Wachsam, analytisch |
| Mut | Orange/Rot | Feuer-Monster | Energisch, mutig |
| Ausdauer | Grau | Stein-Golem mit Hut & Stock | Geduldig, bestaendig |
| Konsequenz | Gruen | Fels-Troll mit verschraenkten Armen | Diszipliniert, stark |

## Intention → Monster Mapping (Morgen-Dialog)

Die 6 Morgen-Intentionen mappen auf die 4 Monster:

| Intention | Monster | Verhalten |
|-----------|---------|-----------|
| Survival | Golem (Ausdauer) | Sanft, beschuetzend |
| Fokus | Eule (Fokus) | Aufmerksam, wachsam |
| BHAG | Feuer (Mut) | Energisch, fordernd |
| Balance | Golem (Ausdauer) | Ausgleichend, erinnernd |
| Wachstum | Eule (Fokus) | Neugierig, ermutigend |
| Verbundenheit | Troll (Konsequenz) | Warm, dankbar |

## Aenderungen an bestehenden Dateien

### Discipline.swift
- Neue Property `imageName: String` (gibt den Asset-Namen zurueck)

### BacklogRow.swift
- Abhak-Kreis (aktuell: SF Symbol `circle`, Farbe `Color.secondary`) aendern:
  - Kraeftiger darstellen
  - Farbe = Discipline-Farbe des Tasks (blau/orange/grau/gruen)
- Discipline-Klassifizierung fuer offene Tasks:
  - `rescheduleCount >= 2` → Konsequenz (gruen)
  - `importance == 3` → Mut (orange)
  - Sonst → Ausdauer (grau, Default)
  - Fokus (blau) erst nach Erledigung bestimmbar

### MorningIntentionView.swift
- Monster-Grafik passend zur gewaehlten Intention anzeigen
- Monster auch WAEHREND der Auswahl sichtbar (grosses Bild oben im Dialog, wechselt bei Chip-Auswahl)
- Nach Auswahl: Monster in Kompaktansicht
- Mapping siehe Tabelle oben

### EveningReflectionCard.swift / DailyReviewView.swift
- Monster-Grafik der staerksten Discipline des Tages auf der Abend-Karte
- Groesse: Klein (60x60px Icon neben dem Titel), NICHT als grosses prominentes Bild

### NotificationService.swift (optional, Phase 4e — SEPARAT)
- Rich Notifications mit Monster-Bild als Attachment
- **ENTSCHEIDUNG:** Wird NICHT mit Phase 4a-4d zusammen implementiert, sondern separat

## Phasen

| Phase | Was | Prio | Dateien |
|-------|-----|------|---------|
| 4a | Monster-PNGs als Assets + Discipline.imageName | Must | Assets.xcassets, Discipline.swift |
| 4b | Farbiger Discipline-Kreis in Task-Zeilen | Should | BacklogRow.swift, Discipline.swift |
| 4c | Monster im Morgen-Dialog | Must | MorningIntentionView.swift |
| 4d | Monster im Abend-Spiegel | Must | EveningReflectionCard.swift, DailyReviewView.swift |
| 4e | Monster in Push-Notifications | Could | NotificationService.swift |

## Referenzen

- User Story: `docs/project/stories/monster-coach.md`
- Backlog: `docs/ACTIVE-todos.md` (Abschnitt "Phase 4")
- Bestehendes Discipline-Enum: `Sources/Models/Discipline.swift`

## Changelog

- 2026-03-13: Spec erstellt nach Gespraech mit Henning. Monster-Grafiken geliefert, Mapping abgestimmt, in User Story und ACTIVE-todos dokumentiert.
- 2026-03-13: PO-Entscheidungen: (1) Monster auch waehrend Auswahl im Morgen-Dialog sichtbar, (2) Abend-Spiegel klein 60x60 Icon, (3) Phase 4e separat.
