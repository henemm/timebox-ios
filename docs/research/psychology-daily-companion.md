# Psychologische Grundlagen: KI-gestützter Tagesbegleiter

> Erstellt: 2026-03-31
> Zweck: Wissenschaftliches Fundament für alle Features rund um den FocusBlox-Tagesbegleiter
> Status: Aktiv — Referenzdokument für Notification-Content, DayView, Reflexion

## Leitidee

FocusBlox ist kein Aufgabenmanager. Es ist ein Werkzeug für **bewusstes Leben**: Morgens intentional starten, tagsüber fokussiert bleiben, abends mit Zufriedenheit zurückblicken. Die KI ist der ruhige, aufmerksame Begleiter — nicht der Chef.

---

## Kern-Theorien

### 1. Implementation Intentions (Gollwitzer, 1999)

**Erkenntnis:** "Wenn-Dann"-Pläne verdoppeln bis verdreifachen die Umsetzungswahrscheinlichkeit (Meta-Analyse: d = 0.65).

**Anwendung Morgens:** Die App hilft, aus vagen Absichten ("Ich will produktiv sein") konkrete Pläne zu machen ("Steuererklärung, 10:00-11:30, Focus Block"). Die Intention muss VOM USER kommen — die KI liefert nur die Struktur und den Kontext.

**Konkret:** Morning Notification nennt den längst überfälligen Task + freien Zeitslot. User entscheidet, KI drängt nicht auf.

### 2. Progress Principle (Amabile & Kramer, 2011)

**Erkenntnis:** Der stärkste Einzelfaktor für Motivation und Wohlbefinden ist das Erleben von KLEINEN Fortschritten bei bedeutungsvoller Arbeit. Aus 12.000 Tagebucheinträgen: Nicht Lob, nicht Geld — kleiner, sichtbarer Fortschritt.

**Anwendung Abends:** Die App macht Fortschritte SICHTBAR, die der User sonst vergessen würde (negativity bias). "Was hat sich heute bewegt?" statt "Hast du alles geschafft?"

**Konkret:** Evening Notification nennt konkrete erledigte Tasks beim Namen. Fokus auf das Geschaffte, nie auf das Fehlende.

### 3. Self-Determination Theory (Deci & Ryan, 2000)

**Erkenntnis:** Drei Grundbedürfnisse treiben intrinsische Motivation:
- **Autonomie:** Ich entscheide selbst. Jede Kontrolle von außen (auch von einer App) untergräbt Motivation.
- **Kompetenz:** Ich wachse und werde besser. Fortschritte sichtbar machen nährt das.
- **Verbundenheit:** Ich bin nicht allein. Die KI als wohlwollender Begleiter (nicht Aufseher).

**Anwendung überall:** Jede Notification wird gegen diese 3 Bedürfnisse geprüft. "Du solltest..." verletzt Autonomie. "Du hast heute 3 Tasks erledigt" nährt Kompetenz. Die warme Stimme der KI nährt Verbundenheit.

**Konkret:** Formulierung immer als Frage oder Angebot, nie als Anweisung. Konfigurierbar, abschaltbar, respektvoll.

### 4. ACT — Acceptance and Commitment Therapy (Hayes et al., 2006)

**Erkenntnis:** Wertebasiertes Handeln statt Produktivitäts-Optimierung. Die Frage ist nicht "Wie viel?" sondern "War es im Einklang mit dem, was mir wichtig ist?"

**Anwendung in der Haltung:** Die KI bewertet nie Quantität. "Du hast nur 2 Tasks erledigt" gibt es nicht. Stattdessen: "Die Steuererklärung war seit 3 Wochen offen — heute erledigt. Das zählt."

---

## Anti-Patterns (VERBOTEN)

| Anti-Pattern | Warum schädlich | Stattdessen |
|---|---|---|
| **Guilt-Tripping** | "Du hast gestern nicht reflektiert" erzeugt Vermeidung | "Du bist wieder hier" (Self-Compassion, Neff) |
| **Toxische Positivität** | "Jeder Tag ist ein Geschenk!" invalidiert echte Probleme | "Das klingt nach einem schwierigen Tag" (Emotional Validation) |
| **Gamification-Overkill** | Streaks/Punkte verschieben Motivation von intrinsisch zu extrinsisch | Fortschritte als Beobachtung zeigen, nicht als Ziel |
| **Notification-Fatigue** | >3/Tag → Ignorieren oder Deinstallation | Max 2-3/Tag, jede muss wertvoll sein |
| **Generische Phrasen** | "Plane deinen Tag!" wird nach 1 Woche ignoriert | Kontextuell + variabel: konkrete Tasks, Zeitslots, Muster |
| **Over-Tracking** | Zu viele Metriken → Fokus auf Messen statt Erleben | Wenige, bedeutungsvolle Datenpunkte |
| **"Du solltest..."** | Verletzt Autonomie (SDT), wird langfristig abgelehnt | "Was wäre, wenn...?" / "Könnte passen:" |

---

## Die drei Tagesmomente

### Morgens: Intention-Setting (60-90 Sekunden)

**Forschung:**
- Implementation Intentions (Gollwitzer): Konkrete Wenn-Dann-Pläne verdoppeln Umsetzung
- "Best Possible Self" (King, 2001): Kurze Visualisierung des gewünschten Tagesergebnisses steigert Zielverfolgung
- Morning Affect (Rothbard & Wilk, 2011): Stimmung am Morgen beeinflusst den ganzen Tag überproportional
- Temporal Landmarks (Dai et al., 2014): "Frische Starts" (Montag, nach Urlaub) verstärken Intention-Setting

**Optimaler Zeitpunkt:** 15-30 Min nach typischem Aufwachen (lernbar). Nicht beim Aufwachen (zu früh), nicht zu spät (Tag hat schon begonnen).

**Gestaltung:**
- Reflexionsfrage (variierend) + konkreter Task-Vorschlag
- "Steuererklärung liegt seit 3 Wochen rum — 90 Min frei ab 10. Heute anpacken?"
- Action-Button: "Übernehmen" → Task sofort als NextUp, kein Formular
- Rückbezug auf gestern (wenn Daten da): "Gestern hattest du X geschafft — wie knüpfst du an?"

### Tagsüber: Begleitende Impulse (0-1 Notifications)

**Forschung:**
- Interruption Science (Gloria Mark): Jede Notification = 23 Min Refokussierung. TAGSÜBER grundsätzlich problematisch.
- Just-in-Time Adaptive Interventions (JITAI): Kurze (30-120 Sek), kontextsensitive Impulse zeigen moderate Effekte (d = 0.3-0.5)
- Micro-Recovery (Zacher et al., 2014): Bewusste Aufmerksamkeitslenkung in Pausen reduziert Erschöpfung

**Optimale Frequenz:** 0-1 pro Tag. Standardmäßig AUS (nur Profil "Aktiv"). Nur an natürlichen Übergangspunkten (nach Focus Block, Mittagspause). NIE während laufendem Focus Block.

**Gestaltung:**
- Konkret: "Freier Slot ab 14:00. Steuererklärung könnte reinpassen."
- Action-Button: "Focus Block starten" → Block wird direkt erstellt
- Einmal zeigen, dann Ruhe. Kein Snooze, kein Wiederholen.

### Abends: Geführte Reflexion (2-3 Minuten)

**Forschung:**
- "Three Good Things" (Seligman, 2005): Drei positive Erlebnisse notieren — Effekt hält bis 6 Monate
- Expressive Writing (Pennebaker): Schreiben erzwingt Kohärenz → reduziert Stress
- Reflexion vs. Rumination: STRUKTUR ist entscheidend. Unstrukturiertes Grübeln schadet, strukturierte Reflexion hilft.
- Self-Distancing (Kross et al., 2014): Reflexion aus Beobachterperspektive verbessert Lernfähigkeit
- Recency Bias: Ohne Reflexion dominiert das letzte Ereignis. Stressiges Meeting um 17:00 überschattet 7h gute Arbeit.

**Optimaler Zeitpunkt:** 1-2h vor Schlafenszeit. Nicht direkt vor dem Schlafen (Grübel-Risiko), nicht direkt nach Feierabend (noch im "Machen"-Modus).

**Gestaltung:**
- Fortschritte sichtbar machen: "Das hast du heute geschafft:" (automatisch aus Tasks)
- Konkreter Task beim Namen: "Steuererklärung um 15:23 erledigt — seit 3 Wochen offen. Das zählt."
- Ehrlich aber warm: Bei schwachem Tag anerkennend, nie vorwurfsvoll
- Deep-Link zu DayView Evening für ausführlichere Reflexion

---

## Notification-Architektur

| Tageszeit | Frequenz | Standardmäßig | Inhalt |
|---|---|---|---|
| Morgens (08:00) | 1x | AN (Profil Ausgeglichen+Aktiv) | Reflexionsfrage + konkreter Task-Vorschlag |
| Tagsüber | 0-1x | AUS (nur Profil Aktiv) | Konkreter Vorschlag an Übergangspunkt |
| Abends (20:00) | 1x | AN (Profil Ausgeglichen+Aktiv) | Positiver Tagesrückblick |
| **Gesamt** | **Max 3** | | |

**Kernregel:** Pull > Push. Variable Inhalte. Jede Notification muss es wert sein, gelesen zu werden.

---

## Neuere Erkenntnisse (2024-2026)

### KI als Scaffolding-Coach
- KI-Coaches die Fragen stellen (sokratisch) > KI die Ratschläge gibt
- Konsistenz > Brillanz: Mittelmäßiger Impuls täglich > brillanter Impuls monatlich
- Personalisierung durch Kontext ("Letzte Woche hattest du...") = Gefühl, "gesehen" zu werden
- Emotional Validation korreliert stärker mit Zufriedenheit als faktische Korrektheit

### Notification-Psychologie (Gloria Mark u.a.)
- 5-8 App-Notifications/Tag → Fatigue-Schwelle. Für eine Einzelapp: 1-3/Tag.
- Notifications an natürlichen Übergangspunkten: 3-4x höhere Öffnungsrate, weniger störend
- Variable Inhalte bleiben wirksam, repetitive werden nach 2 Wochen ignoriert

### Positive Activity Interventions
- Wirken am besten wenn SELBSTGEWÄHLT und VARIIEREND
- Tägliche Dankbarkeit verliert nach 4-6 Wochen, wöchentlich nachhaltiger
- Sättigungseffekt: Pool von Reflexionsfragen > immer dieselbe Frage

---

## Quellen

- Gollwitzer, P. M. (1999). Implementation intentions: Strong effects of simple plans. American Psychologist.
- Amabile, T. M., & Kramer, S. J. (2011). The Progress Principle. Harvard Business Review Press.
- Deci, E. L., & Ryan, R. M. (2000). Self-Determination Theory. American Psychologist.
- Hayes, S. C. et al. (2006). ACT. Behaviour Research and Therapy.
- Dweck, C. S. (2006). Mindset: The New Psychology of Success.
- Covey, S. R. (1989). The 7 Habits of Highly Effective People.
- Gollwitzer, P. M., & Sheeran, P. (2006). Implementation Intentions and Goal Achievement: Meta-Analysis.
- Seligman, M. E. P. et al. (2005). Positive Psychology Progress. American Psychologist.
- Mark, G. et al. (2008). The Cost of Interrupted Work. CHI.
- Neff, K. D. (2003). Self-Compassion: An Alternative Conceptualization. Self and Identity.
- Kross, E. et al. (2014). Self-Distancing. Journal of Personality and Social Psychology.
- Rothbard, N. P., & Wilk, S. L. (2011). Waking Up on the Right or Wrong Side of the Bed. Academy of Management Journal.
- Dai, H., Milkman, K. L., & Riis, J. (2014). The Fresh Start Effect. Management Science.
