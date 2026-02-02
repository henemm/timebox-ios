# Konzept: Backlog Row Redesign

> **Status:** Konzept (nicht umgesetzt)
> **Erstellt:** 2026-01-25
> **Aktualisiert:** 2026-01-25 (Feedback Henning: Prioritaeten + Inkonsistenzen)
> **Bereich:** BacklogView, BacklogRow, TaskDetailSheet, EditTaskSheet

---

## Problem-Analyse

### Aktueller Zustand

Die `BacklogRow` hat folgende UX-Probleme:

1. **Kryptische Prioritaets-Anzeige**
   - Farbige Emojis (🟦🟨🔴) ohne erklaerende Legende
   - User muss raten: Was bedeutet Blau vs. Gelb vs. Rot?

2. **Verwirrende Dauer-Badge**
   - Gelb = Default-Dauer, Blau = manuelle Dauer
   - Farbcode ist nirgends erklaert
   - Sieht aus wie Prioritaet (Farbe), ist aber Dauer

3. **Versteckte Aktion**
   - "Next Up"-Button (Pfeil-Icon) sieht nicht wie Button aus
   - Keine visuelle Affordance (kein Hintergrund, kein Rand)
   - Mittendrin platziert, wirkt wie Dekoration

4. **Fehlende Checkbox**
   - Keine Moeglichkeit, Tasks als "erledigt" zu markieren
   - Standard iOS-Pattern (Apple Reminders) wird nicht befolgt

5. **Ueberladenes Layout**
   - Prioritaet + Titel + Urgency + Tags + Due Date + Button + Duration
   - Zu viel Information auf einmal

6. **Falsche Informations-Priorisierung**
   - Tags werden prominent angezeigt, sind aber weniger wichtig
   - "Art" (Geld verdienen, Schneeschaufeln, Lernen) fehlt oder ist versteckt
   - Dringlichkeit ist genauso wichtig wie Deadline - beides muss sichtbar sein

---

## Inkonsistente Bezeichnungen (App-weit)

### Aktueller Zustand

| Screen | Bezeichnung | Zeigt | Beispielwerte |
|--------|-------------|-------|---------------|
| **TaskDetailSheet** | "Kategorie" | `taskType` | Deep Work, Maintenance, Geld verdienen |
| **EditTaskSheet** | "Typ" | `taskType` | Deep Work, Maintenance, Geld verdienen |
| **BacklogRow** | (nicht angezeigt) | - | - |

**Problem:** Gleiche Daten (`taskType`), unterschiedliche Bezeichnungen ("Kategorie" vs. "Typ")

### Verwirrende taskType-Werte

Das Feld `taskType` enthaelt gemischte Konzepte:

| Ursprung | Werte | Zweck |
|----------|-------|-------|
| Cal Newport Deep Work | deep_work, shallow_work, meetings | Arbeitstiefe |
| Allgemein | maintenance, creative, strategic | Arbeitsart |
| **FocusBlox User Story** | income, recharge, learning, giving_back | Lebensbereich |

**Fuer FocusBlox relevant sind die Lebensbereiche:**
- `income` = Geld verdienen
- `recharge` = Energie aufladen (Schneeschaufeln, Sport, etc.)
- `learning` = Lernen
- `giving_back` = Weitergeben

### Empfehlung: Einheitliche Bezeichnung

**Vorschlag:** "Art" als einheitliche Bezeichnung fuer `taskType`

| Screen | Neu | Alt |
|--------|-----|-----|
| TaskDetailSheet | "Art" | "Kategorie" |
| EditTaskSheet | "Art" | "Typ" |
| BacklogRow | Art-Icon oder Label | (fehlt) |

---

## Informations-Hierarchie fuer BacklogRow

### WICHTIG (immer sichtbar)

| Information | Warum wichtig | Darstellung |
|-------------|---------------|-------------|
| **Titel** | Identifikation | Prominent, Zeile 1 |
| **Dringlichkeit** | Entscheidend fuer "jetzt oder spaeter" | Icon oder Badge |
| **Deadline** | "Heute" = sofortige Aufmerksamkeit | Relatives Datum, rot wenn heute/ueberfaellig |
| **Art** | Lebensbereich (Geld verdienen, Lernen, etc.) | Icon oder kleines Label |

### WENIGER WICHTIG (optional/versteckt)

| Information | Warum weniger wichtig | Darstellung |
|-------------|----------------------|-------------|
| **Tags** | Aktuell nicht sauber implementiert (Freitext) | Nur in Detail-View |
| **Prioritaet** | Wird oft mit Dringlichkeit verwechselt | Nur bei "Hoch" anzeigen |
| **Dauer** | Sekundaer fuer Backlog-Entscheidung | Rechts, dezent |

---

## Best Practices (iOS HIG & Apple Reminders)

### Aus Apple Human Interface Guidelines

- **44px Touch Targets:** Mindestens 44px fuer tappable Elemente
- **Primaere Aktion rechts:** Wichtigste Aktion am rechten Rand
- **Swipe Actions:** Standard-iOS-Pattern fuer Loeschen, Erledigen etc.
- **Disclosure Indicator:** Chevron zeigt "hier kann man drilldown"
- **Visueller Rhythmus:** Titel oben, Details unten, Aktion rechts

### Aus Apple Reminders

- **Checkbox links:** Kreis zum Antippen markiert als erledigt
- **Swipe left:** Delete-Action
- **Swipe right:** Indent/Outdent (Subtask)
- **Tap auf Row:** Oeffnet Detail-Ansicht
- **Farbcodes sparsam:** Nur fuer Listen-Farben, nicht fuer Prioritaet

### Liquid Glass Design (iOS 26)

- Transluzente, glasartige Elemente
- Weiche Schatten und Blur-Effekte
- Klare visuelle Hierarchie durch Tiefe

---

## Empfohlenes Redesign

### Layout-Struktur (von links nach rechts)

```
[ ] Checkbox | Titel                           | Chevron (>)
             | Art  •  Dringlichkeit  •  Heute | 25m
```

### Elemente im Detail

#### 1. Checkbox (links)
- Runder Kreis (unchecked) / gefuellter Kreis mit Haken (checked)
- Standard iOS-Pattern wie Apple Reminders
- Tap auf Checkbox = Task erledigt

#### 2. Titel-Bereich (Mitte)
- **Zeile 1:** Titel (max 2 Zeilen, truncated)
- **Zeile 2:** Meta-Informationen (WICHTIG → weniger wichtig):
  1. **Art** - Icon + Label (💰 Geld verdienen, 🔋 Energie, 📚 Lernen, 🤝 Weitergeben)
  2. **Dringlichkeit** - "Dringend" als rotes Badge (nur wenn urgent)
  3. **Deadline** - "Heute", "Morgen", "Mi" (rot wenn heute/ueberfaellig)

**NICHT in Zeile 2:**
- Tags (nur in Detail-View, da Freitext-Chaos)
- Prioritaet (nur "Hoch" als subtiles Icon, wenn ueberhaupt)

#### 3. Rechte Seite
- **Duration Badge:** Klar als Zeit erkennbar (z.B. "25 min") - EINE Farbe
- **Chevron (>):** Standard iOS Disclosure Indicator

### Aktionen

| Geste | Aktion |
|-------|--------|
| Tap auf Checkbox | Task erledigt markieren |
| Tap auf Row | Detail-Sheet oeffnen |
| Swipe Left | Delete + "Next Up" Buttons |
| Swipe Right | Optional: Quick-Actions |

### Visuelle Unterscheidungen

| Zustand | Darstellung |
|---------|-------------|
| Normal | Schwarzer Titel, graue Meta-Info |
| **Dringend** | Rotes "Dringend" Badge in Meta-Zeile |
| **Heute faellig** | Rotes "Heute" in Meta-Zeile |
| **Ueberfaellig** | Rotes Datum + evtl. roter Hintergrund-Tint |
| In Next Up | Blaue Hintergrund-Tint oder "Next Up" Badge |

### Art-Icons (Vorschlag)

| Art | Icon | Farbe |
|-----|------|-------|
| Geld verdienen (`income`) | 💰 oder `dollarsign.circle` | Gruen |
| Energie aufladen (`recharge`) | 🔋 oder `battery.100.bolt` | Orange |
| Lernen (`learning`) | 📚 oder `book.fill` | Blau |
| Weitergeben (`giving_back`) | 🤝 oder `person.2.fill` | Lila |
| Maintenance | 🔧 oder `wrench.fill` | Grau |
| Deep Work | 🧠 oder `brain.head.profile` | Dunkelblau |

---

## Prioritaet vs. Dringlichkeit

### Unterscheidung (Eisenhower-Matrix)

| Begriff | Bedeutung | Beispiel |
|---------|-----------|----------|
| **Prioritaet** | Wichtigkeit (Impact) | Steuererklärung = Hoch |
| **Dringlichkeit** | Zeitdruck (Deadline) | Muss heute erledigt werden |

### Empfehlung fuer BacklogRow

- **Dringlichkeit IMMER anzeigen** wenn `urgent` - das ist die primaere Entscheidungshilfe
- **Prioritaet NICHT anzeigen** in der Row - verwirrt nur
- Prioritaet kann in Detail-View/Edit bleiben fuer Sortierung

**Grund:** Die Frage im Backlog ist "Was mache ich JETZT?" -
dafuer ist Dringlichkeit + Deadline relevanter als abstrakte Wichtigkeit.

---

## Mockup (ASCII)

### Aktuell (problematisch)
```
🟦 Task Title Here ⚠️       ↑    [25m]
   #tag1 #tag2  📅 Heute
```
- Kryptische Farb-Emojis
- Tags prominent (aber unwichtig)
- "Art" fehlt komplett
- Button mittendrin (kein Affordance)

### Neu (empfohlen)
```
○  Steuererklärung fertigstellen               >
   💰 Geld verdienen  •  Dringend  •  Heute   25m
```

### Variante: Nicht dringend, keine Deadline
```
○  Swift Concurrency Kurs weitermachen         >
   📚 Lernen                                   45m
```

### Variante: Dringend aber keine Deadline
```
○  Schneeschaufeln                             >
   🔋 Energie  •  Dringend                     15m
```

### Mit Checkbox gecheckt
```
●  Task Title Here (strikethrough)             >
   ✓ Erledigt
```

---

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `BacklogRow.swift` | Komplettes Layout-Refactoring, Art + Dringlichkeit anzeigen |
| `DurationBadge.swift` | Vereinfachtes Design (nur eine Farbe) |
| `BacklogView.swift` | Swipe Actions hinzufuegen |
| `TaskDetailSheet.swift` | "Kategorie" → "Art" umbenennen |
| `EditTaskSheet.swift` | "Typ" → "Art" umbenennen, Section "Kategorisierung" → "Einordnung" |

**Geschaetzter Aufwand:** ~150-200 LoC Aenderungen

---

## Separates Problem: Tags

Die Tags sind aktuell als **Freitext** implementiert (komma-separiert).
Das fuehrt zu Chaos und inkonsistenten Eintraegen.

**Empfehlung:** Separates Feature fuer saubere Tag-Implementierung:
- Vordefinierte Tags oder
- Tag-Autovervollstaendigung oder
- Komplett entfernen und durch "Art" ersetzen

**NICHT Teil dieses Redesigns** - nur dokumentiert fuer spaeter.

---

## Abhaengigkeiten

- **Feature "Tasks als erledigt markieren"** muss zuerst implementiert werden (oder zusammen)
- Erfordert API-Call zu EventKit/Reminders um Task zu komplettieren

---

## Quellen

- [Apple Human Interface Guidelines - Lists](https://developer.apple.com/design/human-interface-guidelines/components/layout-and-organization/lists-and-tables/)
- [Apple Support - Use Reminders](https://support.apple.com/en-us/102484)
- [iOS Design Guidelines 2025](https://www.learnui.design/blog/ios-design-guidelines-templates.html)

---

## Naechste Schritte

1. Henning reviewed Konzept
2. Bei Freigabe: Spec erstellen
3. TDD RED: UI Tests schreiben
4. Implementation
5. Validation
