# User Story: Monster Coach — Dein sympathischer Trainingspartner

> Erstellt: 2026-03-11
> Status: Approved
> Produkt: FocusBlox

## JTBD Statement

**When** ich morgens meinen Tag beginne und abends zurückschaue,
**I want to** eine App die mich fragt wie ich mich abends fühlen will, mich mit einem sympathischen Monster als Trainingspartner durch den Tag begleitet, und abends den Spiegel hochhält,
**So that** ich nicht nur produktiv bin, sondern bewusst an mir wachse — und das am Ende des Tages auch FÜHLE.

## Kontext

### Die Situation
FocusBlox funktioniert gut als Produktivitäts-Tool: Backlog, Planung, Timer, Gong. Aber es ist **nüchtern und technisch**. Es sagt "Task erledigt" — nicht "Starke Session heute!" Es gibt keine emotionale Verbindung, kein Morgen-Ritual, keine Abend-Feier. Die App hilft beim MACHEN, aber nicht beim FÜHLEN und WACHSEN.

### Das Problem heute
- Tasks sind Zeilen in einer Liste — kein emotionaler Bezug
- Kein bewusstes Morgen-Ritual das den Tag intentional startet
- Kein Abend-Moment der Reflexion und Stolz erzeugt
- Keine Sichtbarkeit darüber, an welchen persönlichen Fähigkeiten man wächst
- Keine Balance-Perspektive über Lebensbereiche hinweg

### Alternativen
- Habitica: Gamification (XP, Levels), aber mechanisch statt emotional
- Finch: Virtuelles Wesen, aber niedlich statt herausfordernd
- Journaling-Apps: Reflexion, aber keine Integration mit Task-Management
- **Keine App verbindet:** Intention → Herausforderung → Reflexion → Wachstum

## Die Morgen-Frage (Herzstück)

> "Wenn du heute Abend auf diesen Tag zurückblickst — was möchtest du dann sehen?"

| Option | Intention | Monster | Monster-Verhalten |
|--------|-----------|---------|-------------------|
| "Egal, Tag überleben" | Survival | Golem (Ausdauer) | Sanft, beschützend |
| "Stolz: nicht verzettelt" | Fokus | Eule (Fokus) | Aufmerksam, wachsam |
| "Das große hässliche Ding geschafft" | BHAG | Feuer (Mut) | Energisch, fordernd |
| "In allen Bereichen gelebt" | Balance (Haug) | Golem (Ausdauer) | Ausgleichend, erinnernd |
| "Etwas Neues gelernt" | Wachstum | Eule (Fokus) | Neugierig, ermutigend |
| "Für andere da gewesen" | Verbundenheit | Troll (Konsequenz) | Warm, dankbar |

Die Morgen-Frage dreht die Logik um: Nicht "Was tust du heute?" sondern "Wie willst du dich abends fühlen?" — und die App arbeitet rückwärts davon.

## Die vier Monster (Trainingspartner)

### Monster-Grafiken (Assets)

Vier PNG-Grafiken mit transparentem Hintergrund, je eine pro Discipline:

| Asset | Discipline | Beschreibung |
|-------|-----------|--------------|
| `monsterFokus` | Fokus (Blau) | Eule mit Lupe — wachsam, analytisch |
| `monsterMut` | Mut (Orange) | Feuer-Monster — energisch, mutig |
| `monsterAusdauer` | Ausdauer (Grau) | Stein-Golem mit Hut & Stock — geduldig, beständig |
| `monsterKonsequenz` | Konsequenz (Grün) | Fels-Troll mit verschränkten Armen — diszipliniert, stark |

### Einsatzorte der Monster-Grafiken

- **Morgen-Dialog:** Das Monster passend zur gewählten Intention (siehe Mapping-Tabelle oben)
- **Abend-Spiegel:** Das Monster der stärksten Discipline des Tages
- **Push-Notifications:** Als Rich Notification Bild (optional)
- **Task-Zeilen:** Farbiger Abhak-Kreis in der Discipline-Farbe des Tasks

## Mein Monster (Trainingspartner)

- **EIN persönliches, sympathisches Monster** pro User
- Nicht Gegner, nicht Coach — **Trainingspartner** der herausfordert damit man wächst
- Passt sein Verhalten an die Morgen-Intention an
- Wächst und entwickelt sich mit dem User über die Zeit
- Tiefe emotionale Bindung durch Konstanz und Persönlichkeit

**Charakter-Prinzip:** Das Monster fordert heraus wie ein Sparring-Partner im Sport. Es geht nicht ums Kämpfen oder Besiegen, sondern um die Gelegenheit, besser zu werden und an persönlichen Skills zu arbeiten.

## Trainings-Disziplinen (Task-Ebene)

Ergänzend zur Morgen-Intention kategorisieren die Disziplinen die einzelnen Tasks nach Art des Widerstands:

| Disziplin | Farbe | Monster | Trainiert | Typische Tasks |
|-----------|-------|---------|-----------|----------------|
| Konsequenz | Grün | Troll (Fels-Troll, verschränkte Arme) | Disziplin & Durchhaltevermögen | Das Aufgeschobene endlich anpacken |
| Ausdauer | Grau | Golem (Stein-Golem mit Hut & Stock) | Geduld & Beharrlichkeit | Das Langweilige durchziehen |
| Mut | Orange/Rot | Feuer (Feuer-Monster, energisch) | Emotionale Stärke | Das Unangenehme angehen |
| Fokus | Blau | Eule (Eule mit Lupe, wachsam) | Zeitmanagement & Klarheit | Sich nicht verzetteln |

## Der komplette Tagesbogen

Die Morgen-Frage allein reicht nicht. Ohne Brücke zum Rest des Tages verpufft die Intention. Der Tagesbogen verbindet Morgen, Tag und Abend zu einem durchgängigen Erlebnis.

### Drei Beispiel-Tage

**Tag 1: BHAG — "Das große hässliche Ding geschafft"**

*Morgens:* Anna wählt BHAG. Das Monster wird energisch: "Na dann zeig mal." Die App wechselt zum Backlog, gefiltert auf Tasks mit Wichtigkeit 3 und lang verschobene Tasks. Anna sieht die Steuererklärung ganz oben. Sie markiert sie als NextUp.

*Tagsüber:* Um 11 Uhr hat Anna drei kleine Tasks erledigt, aber die Steuererklärung nicht angefasst. Die App merkt: kein Focus Block mit dem BHAG-Task erstellt. Eine Notification: "Du wolltest das große Ding anpacken. Wann legst du los?" Anna erstellt einen 90-Minuten-Block.

*Abends:* Um 15:23 war die Steuererklärung erledigt. Ab 18 Uhr zeigt der Review-Tab eine leuchtende Karte. Das Monster (via Foundation Models): "Du hast dir heute Morgen vorgenommen, das große Ding anzupacken — die Steuererklärung. Um 15:23 war sie erledigt. Das war der schwerste Task seit zwei Wochen. Stark."

**Tag 2: Fokus — "Stolz: nicht verzettelt"**

*Morgens:* Ben wählt Fokus. Das Monster wird wachsam. Die App zeigt den Backlog gefiltert auf seine aktuellen NextUp-Tasks: "Bleib bei deinem Plan." Ben sieht seine drei geplanten Tasks und erstellt Focus Blocks dafür.

*Tagsüber:* Ben erledigt zwei Blocks sauber. Ein dritter Task kommt dazwischen, ohne Block. Notification: "Tasks ohne Block erledigt. Willst du einen erstellen?" Ben ignoriert es — er weiß was er tut. Keine weitere Notification (Stille-Regel).

*Abends:* Block-Completion bei 75%. Gedämpft-warme Karte: "Drei Blocks geplant, zwei durchgezogen. Der dritte kam dazwischen — passiert. 75% Fokus ist ein solider Tag."

**Tag 3: Balance — "In allen Bereichen gelebt"**

*Morgens:* Clara wählt Balance. Die App zeigt den Backlog gruppiert nach Kategorie und hebt hervor wo Lücken sind. Clara sieht: viel Arbeit, wenig für sich selbst. Sie markiert einen Yoga-Task und einen Anruf bei ihrer Mutter als NextUp.

*Tagsüber:* Bis 15 Uhr hat Clara nur Arbeits-Tasks erledigt. Notification: "Bisher nur Arbeit. Wie wär's mit was für dich?" Clara macht ihren Yoga-Block.

*Abends:* Tasks in 3 Kategorien erledigt (Arbeit, Selbstfürsorge, Soziales). Warme, ausgewogene Karte: "Arbeit, Yoga, und deine Mutter angerufen — drei Farben heute. Was für ein runder Tag."

## Nach der Morgen-Auswahl: Gefilterter Backlog

Die Intention darf nicht in der Luft hängen. Direkt nach der Morgen-Auswahl wechselt die App zum Backlog-Tab — aber gefiltert passend zur Intention.

| Intention | Backlog-Filter |
|-----------|---------------|
| Survival | Kein Filter — nimm was du schaffst |
| Fokus | Zeigt aktuelle NextUp-Tasks ("Bleib bei deinem Plan") |
| BHAG | Tasks mit Wichtigkeit 3 + oft verschobene Tasks |
| Balance | Gruppiert nach Kategorie, hebt Lücken hervor |
| Wachstum | Filtert auf Kategorie "Lernen" |
| Verbundenheit | Filtert auf Kategorie "Geben" |

**Flow:** Intention wählen → App wechselt zum Backlog-Tab mit aktivem Filter-Chip → User markiert Tasks als NextUp → weiter zum Blöcke-Tab.

Der Filter-Chip ist sichtbar und abschaltbar. Der User kann jederzeit zum normalen Backlog wechseln. Die Intention ist ein Vorschlag, kein Zwang.

## Smart Notifications (Tagesbegleitung)

**Kernprinzip:** Notifications feuern nur bei LÜCKEN zwischen Intention und Handlung. Wer tut was er sich vorgenommen hat, hört nichts.

| Intention | Bedingung für Notification | Beispiel-Text |
|-----------|---------------------------|---------------|
| BHAG | Kein Focus Block mit BHAG-Task erstellt | "Du wolltest das große Ding anpacken. Wann legst du los?" |
| BHAG | BHAG-Task noch nicht begonnen (nachmittags) | "Dein BHAG wartet noch." |
| Fokus | Kein Focus Block geplant | "Kein Block geplant. Du wolltest fokussiert bleiben." |
| Fokus | Tasks außerhalb von Blocks erledigt | "Tasks ohne Block erledigt. Willst du einen erstellen?" |
| Balance | Nur 1-2 Kategorien aktiv (nachmittags) | "Bisher nur Arbeit. Wie wär's mit was für dich?" |
| Wachstum | Kein "Lernen"-Task erledigt | "Du wolltest was Neues lernen. Hast du schon was im Auge?" |
| Verbundenheit | Kein "Geben"-Task erledigt | "Du wolltest für andere da sein heute." |
| Survival | **Keine Nudges.** Survival = "Lass mich in Ruhe." | — |

**Stille-Regel:** Sobald die Intention erfüllt ist → keine weiteren Notifications. Das Monster schweigt wenn alles läuft.

**User-Konfiguration (Settings):**

| Setting | Optionen | Default |
|---------|----------|---------|
| Tages-Erinnerungen | An / Aus | An |
| Max. Erinnerungen pro Tag | 1 / 2 / 3 | 2 |
| Zeitfenster von | Time Picker | 10:00 |
| Zeitfenster bis | Time Picker | 18:00 |

Der Inhalt der Notifications wird von der Intention bestimmt, nicht vom User konfiguriert. Die Texte kommen vom Monster — sie sind persönlich, nicht generisch.

## Der Abend-Spiegel

Das Monster hält am Ende des Tages den Spiegel hoch — automatisch, ohne dass der User etwas bewerten muss.

### Wann und Wo

Ab 18 Uhr als **Karte im Review-Tab** (oberhalb der Stats). Kein Extra-Screen, kein Zwang — einfach da wenn man hinschaut.

Optional: Push-Notification um 20:00 (konfigurierbar). Nur wenn Coach-Modus aktiv UND Morgen-Intention gesetzt.

### Automatische Auswertung

Die Bewertung kommt komplett aus den Task-Daten — kein User-Input nötig:

| Intention | Erfüllt | Teilweise | Nicht erfüllt |
|-----------|---------|-----------|---------------|
| Survival | ≥1 Task erledigt | — | 0 Tasks |
| Fokus | Block-Completion ≥70% | 40-69% | <40% oder keine Blocks |
| BHAG | Task mit Wichtigkeit 3 erledigt | Tasks erledigt, aber nicht das große Ding | Nichts Nennenswertes |
| Balance | Tasks in ≥3 Kategorien | 2 Kategorien | ≤1 Kategorie |
| Wachstum | "Lernen"-Task erledigt | — | Kein "Lernen"-Task |
| Verbundenheit | "Geben"-Task erledigt | — | Kein "Geben"-Task |

### Monster-Stimme (Foundation Models)

Foundation Models (On-Device AI) generiert den persönlichen Abend-Text basierend auf:

- Gesetzte Intention
- Erledigte Tasks (mit Namen!)
- Erfüllungsgrad (erfüllt / teilweise / nicht erfüllt)
- Tageskontext (wie viele Blocks, welche Kategorien, Zeitpunkte)

**Beispiel-Prompt an Foundation Models:**
> Du bist ein sympathisches Monster, Trainingspartner des Users. Die heutige Intention war "BHAG". Der User hat die Steuererklärung (Wichtigkeit 3) um 15:23 erledigt, plus 4 weitere Tasks. Schreib 2-3 persönliche Sätze. Nie toxisch positiv, nie schuldzuweisend. Bezieh dich auf konkrete Tasks.

**Fallback** für ältere Geräte ohne Apple Intelligence: Handgeschriebene Template-Sprüche pro Intention und Erfüllungsgrad.

| Intention | Erfüllt | Monster sagt (Fallback)... |
|-----------|---------|---------------------------|
| Survival | Ja | "Du hast es geschafft. Auch das zählt." |
| Fokus | Ja | "Du bist bei der Sache geblieben. Stark." |
| BHAG | Ja | "DU HAST ES GETAN! Weißt du was das bedeutet?!" |
| Balance | Ja | "Was für ein runder Tag." |
| Wachstum | Ja | "Du bist heute klüger als gestern." |
| Verbundenheit | Ja | "Du hast jemandem den Tag besser gemacht." |

### Stimmung und Farbe der Karte

| Erfüllungsgrad | Visuell | Ton |
|----------------|---------|-----|
| Erfüllt | Warm, leuchtend, Intentionsfarbe | Stolz, feiernd |
| Teilweise | Gedämpft, sanft | Ermutigend, anerkennend |
| Nicht erfüllt | Sanft grau/blau | Verständnisvoll, nie verurteilend |

**Intensität:** Sanft bei kleinen Tagen, groß bei großen Herausforderungen. Nie toxisch positiv, nie schuldzuweisend.

**Gewünschte Emotionen:** Stolz, Zufriedenheit, Energie für morgen.

## Zwei Modi (umschaltbar)

- **Focus-Modus:** Nüchtern, technisch — wie FocusBlox heute ist. Für Tage wo man einfach nur arbeiten will.
- **Coach-Modus:** Emotional, mit Monster, Morgen-Frage, Abend-Spiegel. Für bewusstes Leben und Wachstum.

Der User wählt seinen Modus. Kein Zwang.

## Lebensbalance (Frigga Haug, 4-in-1 Perspektive)

Haugs Vier-in-einem-Perspektive teilt das Leben in gleichwertige Bereiche. FocusBlox macht beides:

1. **Sichtbar machen:** Visualisierung wie die Zeit auf Lebensbereiche verteilt ist — ohne zu urteilen
2. **Sanft erinnern:** Wenn ein Bereich zu kurz kommt, erinnert das Monster daran ("Du hast diese Woche noch nichts für dich getan")

## Apple Intelligence Integration

| Technologie | Einsatz |
|------------|---------|
| Foundation Models | Persönliche Abend-Reflexionstexte on-device generieren |
| App Intents / Siri | "Hey Siri, wie war mein Tag?" / "Setz meine Intention auf Fokus" |
| Smart Notification Timing | Interruption Levels passend zur Situation |

**Foundation Models ist der Game-Changer:** Statt generischer Template-Sprüche wie "Du hast es geschafft. Auch das zählt." schreibt das On-Device-Modell persönliche Texte die konkrete Tasks beim Namen nennen und den Tagesverlauf kennen.

**Datenschutz:** Alles on-device. Keine Task-Daten verlassen das Gerät. Foundation Models läuft lokal.

## Dimensionen

### Funktional
- Morgen-Intention-Screen mit der zentralen Frage
- Intention-basierter Backlog-Filter nach der Morgen-Auswahl
- Monster-Charakter mit kontextabhängigem Verhalten
- Task-Disziplin-Zuordnung (Konsequenz, Ausdauer, Mut, Fokus)
- Smart Notifications bei Lücken zwischen Intention und Handlung
- Abend-Spiegel mit automatischer Auswertung und AI-generiertem Text
- Modus-Toggle (Focus ↔ Coach)
- Lebensbalance-Tracking und -Visualisierung

### Emotional
- **Morgens:** Intentionalität — "Ich entscheide bewusst, was für ein Tag das wird"
- **Morgens → Backlog:** Handlung — "Ich weiß genau welche Tasks zu meiner Intention passen"
- **Tagsüber:** Begleitung — "Mein Monster meldet sich nur wenn ich Hilfe brauche"
- **Abends:** Stolz, Zufriedenheit, Energie — "Ich sehe schwarz auf weiß was ich geschafft habe"
- **Über Zeit:** Entwicklung — "Ich sehe wie mein Monster und ich zusammen gewachsen sind"

### Sozial
- Nicht primär sozial — persönlicher Begleiter
- Potential: Monster/Fortschritt teilen (optional, nicht Kern)

## Wissenschaftliches Fundament

| Theorie | Autor | Anwendung in FocusBlox |
|---------|-------|------------------------|
| Growth Mindset | Carol Dweck | Herausforderungen als Wachstumschancen, nicht Bedrohungen |
| Progress Principle | Amabile & Kramer | Kleine sichtbare Fortschritte = stärkster Alltags-Motivator |
| Self-Determination Theory | Deci & Ryan | Autonomie (ich wähle), Kompetenz (ich wachse), Verbundenheit (mein Monster) |
| 4-in-1 Perspektive | Frigga Haug | Balance über Lebensdimensionen |
| Begin with the End in Mind | Stephen Covey | Vom gewünschten Ergebnis rückwärts planen |
| ACT | Hayes et al. | Wertebasiertes Handeln statt reaktives Abarbeiten |
| Implementation Intentions | Peter Gollwitzer | Ritualisierte Wenn-Dann-Verknüpfungen (Morgen-Ritual) |

## Anti-Patterns (explizit NICHT gewollt)

- **Kein Guilt-Tripping** — "Du hast heute NICHTS geschafft" gibt es nicht
- **Kein Suchtdesign** — keine manipulativen Streaks oder FOMO
- **Keine toxische Positivität** — ehrlich, nicht aufgesetzt
- **Kein Vergleich mit anderen** — rein persönliches Wachstum
- **Kein Gamification-Overkill** — keine XP, Levels, Achievements
- **Keine Notification-Flut** — Stille-Regel, konfigurierbar, Survival = Ruhe

## Erfolgskriterien

- [ ] Morgens: Die Frage "Wie willst du dich abends fühlen?" setzt bewusst die Tages-Intention
- [ ] Nach der Intention: Der Backlog zeigt gefiltert die passenden Tasks
- [ ] Tagsüber: Smart Notifications melden sich nur bei Lücken — Stille wenn alles läuft
- [ ] Survival = absolute Ruhe — keine Nudges, keine Bewertung
- [ ] Mein Monster begleitet mich passend zur Intention durch den Tag
- [ ] Tasks fühlen sich an wie Training in einer Disziplin, nicht wie Abhaken einer Liste
- [ ] Abends: Der Spiegel zeigt automatisch ob ich bekommen habe was ich mir morgens gewünscht habe
- [ ] Abend-Text ist persönlich und nennt konkrete Tasks beim Namen (via Foundation Models)
- [ ] Ich sehe über die Zeit an welchen Disziplinen ich gewachsen bin
- [ ] Mein Monster wächst/entwickelt sich mit mir
- [ ] Die App erkennt wenn ein Lebensbereich zu kurz kommt und erinnert sanft
- [ ] Coach-Modus ist umschaltbar — Focus-Modus bleibt als Alternative
- [ ] Kein Guilt-Tripping, kein Suchtdesign, keine toxische Positivität

## Abgeleitete Features

| Feature | Prioritaet | Status |
|---------|-----------|--------|
| Morning Intention Screen | Must | ERLEDIGT (Phase 2) |
| Coach-Modus Toggle | Must | ERLEDIGT (Phase 1) |
| Task-Disziplin-Zuordnung (Konsequenz/Ausdauer/Mut/Fokus) | Must | ERLEDIGT (Phase 1) |
| **Intention-basierter Backlog-Filter** | **Must** | **ERLEDIGT (Phase 3a)** |
| **Smart Notifications (Tagesbegleitung)** | **Must** | **ERLEDIGT (Phase 3b)** |
| **Abend-Spiegel (Evaluation + Karte)** | **Must** | **ERLEDIGT (Phase 3c/3d)** |
| **Foundation Models Abend-Text** | **Must** | **ERLEDIGT (Phase 3d)** |
| **Abend Push-Notification** | **Should** | **ERLEDIGT (Phase 3e)** |
| **Siri Integration (App Intents)** | **Should** | **ERLEDIGT (Phase 3f)** |
| **Monster-Grafiken (4 Discipline-Monster)** | **Must** | **Backlog** |
| **Farbiger Discipline-Kreis in Task-Zeilen** | **Should** | **Backlog** |
| **Monster in Morgen-/Abend-Dialogen** | **Must** | **Backlog** |
| **Monster in Push-Notifications** | **Could** | **Backlog** |
| Lebensbalance-Visualisierung (Haug 4-in-1) | Should | Backlog |
| Balance-Erinnerungen | Could | Backlog |

## Implementierungs-Notizen

### Phase 1 XP/Evolution-System — ENTFERNT (2026-03-12)

Phase 1 hat ein Gamification-System implementiert (XP-Punkte pro Disziplin, Evolution-Levels Ei→Baby→Junior→Erwachsen→Meister, MonsterStatusView mit XP-Balken) das den Anti-Patterns dieser User Story direkt widerspricht ("keine XP, Levels, Achievements").

Henning hat das im Dialog korrigiert: "Es geht nicht um XP sondern darum, dass ich abends gelobt werde und worauf ich mit Stolz zurückblicken kann." Das System wurde entfernt.

**Was bleibt:** Discipline Enum (Task-Klassifizierung), Coach-Modus Toggle, Morning Intention.
**Was entfernt wurde:** MonsterCoach Model (XP/Evolution), MonsterStatusView (XP-Balken).

### Phase 3 Tagesbogen — Spezifiziert (2026-03-12)

Im Dialog mit Henning wurde der komplette Tagesbogen ausgearbeitet: Was passiert NACH der Morgen-Intention? Wie begleitet die App durch den Tag? Was passiert abends?

**Kern-Entscheidungen:**
- Abend-Bewertung ist automatisch (aus Task-Daten) — kein User-Input nötig
- Task-Kategorie dient als Proxy für schwierige Intentionen (Growth → "Lernen", Connection → "Geben")
- Notifications nur bei Lücken — wer seine Intention lebt, hört nichts
- Foundation Models für persönliche Abend-Texte — Fallback-Templates für ältere Geräte

---
*Ermittelt im JTBD-Dialog am 2026-03-11*
*Tagesbogen konkretisiert am 2026-03-12*
*Wissenschaftliche Fundierung: Dweck, Amabile, Deci & Ryan, Haug, Covey, Hayes, Gollwitzer*
