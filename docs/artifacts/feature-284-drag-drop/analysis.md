# Feature-Analyse: Drag & Drop im Kalender-View (#284)

## User-Erwartung
- Wie Apple Kalender: Long-Press, Ziehen mit Live-Feedback, Loslassen = fertig
- Visuell klar was verschiebbar ist und was nicht (Termine = gesperrt, Focus-Blöcke = greifbar)
- Snap auf 15-Min-Grenzen, sofortiges Speichern, kein Bestätigungs-Dialog

## Technische Analyse — 6 identifizierte Barrieren

1. **ZStack-Overlay-Problem (Hauptproblem):** Timeline-Elemente liegen ÜBER dem Canvas-Drop-Delegate → Touch-Events werden abgefangen
2. **isReadOnly-Guard:** Kalender-Events mit Teilnehmern sind still nicht-draggable
3. **isFuture-Guard:** Vergangene/aktive Focus-Blöcke reagieren nicht auf Drag
4. **TimelineEventRow nicht draggable:** Im Blox-Tab fehlt .draggable komplett
5. **ScheduledTaskBlock nicht draggable:** Eingeplante Tasks können nicht per Drag verschoben werden
6. **Zwei Drop-Systeme parallel:** TimelineView vs. BlockPlanningView nutzen verschiedene Delegates

## Scope-Optionen

**MVP (empfohlen):** Barrieren 4+5 fixen (fehlende .draggable), visuelles Feedback für gesperrte Items
- ~4 Dateien, ~30 LoC
- Löst die "manche Einträge wirken wie Barrieren"-Wahrnehmung

**Full Redesign:** Einheitliches Drop-System, Live-Preview, Kollisionserkennung
- 6-8 Dateien, 300+ LoC → ÜBER Scope-Limit
