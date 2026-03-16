# Bug-Analyse: NextUp-Section fehlt in Monster-Modus

## Symptom
Im Monster-Modus (Coach-Backlog) gibt es keine "Next Up"-Section. Tasks werden nicht nach NextUp gefiltert und nicht gesondert dargestellt. Betrifft iOS UND macOS.

## Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- Bug 99 ("Next-Up-Swipe fehlt") wurde in Phase 5a gefixt — Swipe-Geste zum Togglen existiert auf iOS
- Aber: Es wurde NIE eine eigene NextUp-SECTION eingebaut
- macOS hat weder Swipe noch Section

### Agent 2: Datenfluss-Trace
- `BacklogView` (Normal-Modus) hat dedizierte `nextUpListSection` mit gruenem Header, Count-Badge
- `CoachBacklogView` hat NUR 2 Sections: "Dein Schwerpunkt" + "Weitere Tasks"
- `MacCoachBacklogView` identisch — nur 2 Sections
- Eule-Coach filtert zwar nach `isNextUp`, zeigt sie aber in "Dein Schwerpunkt" statt eigener Section

### Agent 3: Alle Schreiber
- `isNextUp` wird geschrieben in: SyncEngine, TaskInspector, NotificationActionDelegate, MacPlanningView, QuickCaptureView
- iOS CoachBacklogView hat Swipe-Toggle (Zeile 159-167) — Schreiben funktioniert
- macOS hat KEINEN Swipe und KEIN Context-Menu fuer NextUp

### Agent 4: Szenarien
- Bei JEDEM Coach (Troll/Feuer/Eule/Golem) fehlt die NextUp-Section
- Nur Eule nutzt `isNextUp` als Filter → Tasks landen in "Dein Schwerpunkt"
- Bei Troll/Feuer/Golem: NextUp-Tasks sind unsichtbar in der Masse von "Weitere Tasks"

### Agent 5: Blast Radius
- Daten-Integritaet: SICHER — isNextUp-Feld persistiert, Siri/Services funktionieren
- iOS: Kann NextUp togglen (Swipe existiert), aber keine Section zum Anzeigen
- macOS: Kann WEDER togglen NOCH anzeigen
- Betroffene Views: CoachBacklogView (iOS), MacCoachBacklogView (macOS)

## Hypothesen

### H1: NextUp-Section wurde nie implementiert (Wahrscheinlichkeit: HOCH)
**Beweis dafuer:**
- CoachBacklogView wurde in Phase 5a mit nur 2 Sections designed
- Git-History zeigt keinen Commit der eine NextUp-Section hinzufuegt/entfernt
- Bug 99 hat nur den SWIPE gefixt, nicht die SECTION
- CoachBacklogViewModel hat nur `relevantTasks()` und `otherTasks()` — kein `nextUpTasks()`

**Beweis dagegen:**
- Keiner. Die Section existiert nachweislich nicht im Code.

### H2: NextUp-Section ging beim Coach-Redesign verloren (Wahrscheinlichkeit: NIEDRIG)
**Beweis dafuer:**
- Redesign (634e120) hat CoachType-Filterung umgebaut

**Beweis dagegen:**
- Kein Commit zeigt Entfernung einer NextUp-Section
- Auch VOR dem Redesign hatte CoachBacklogView keine NextUp-Section

### H3: NextUp soll nur ueber Eule-Coach sichtbar sein (Wahrscheinlichkeit: NIEDRIG)
**Beweis dafuer:**
- Eule filtert nach `isNextUp == true` → Tasks erscheinen in "Dein Schwerpunkt"

**Beweis dagegen:**
- Nur max 3 Tasks bei Eule — aber User koennte mehr als 3 NextUp-Tasks haben
- Bei anderen Coaches sind NextUp-Tasks komplett unsichtbar als Gruppe
- BacklogView zeigt NextUp IMMER als eigene Section, unabhaengig von Filtern

## Wahrscheinlichste Ursache: H1

Die NextUp-Section wurde in CoachBacklogView nie implementiert. Es ist ein **fehlendes Feature**, kein Regressions-Bug.

## Zusaetzliche Erkenntnisse (nach Challenge)

### NextUp-Tasks in "Weitere Tasks" unsichtbar
Bei Troll/Feuer/Golem landen NextUp-Tasks ohne Kennzeichnung in "Weitere Tasks". Der User sieht nicht, welche Tasks NextUp-Status haben. Bei Eule sieht er max 3 in "Dein Schwerpunkt" — Tasks 4+ sind ebenfalls unsichtbar.

### BacklogView separiert aktiv
BacklogView.swift filtert explizit: `nextUpTasks` (isNextUp=true) werden NICHT in `allBacklogTasks` angezeigt (Zeile 112: `!$0.isNextUp`). In CoachBacklogView gibt es diese Trennung nicht — NextUp-Tasks mischen sich unter alle Tasks.

### macOS: Kein NextUp-Toggle moeglich
MacCoachBacklogView hat weder Swipe noch Context-Menu fuer NextUp. Der User kann im macOS Monster-Modus NextUp gar nicht setzen/entfernen.

### Bewusste Design-Entscheidung?
Kein Spec, keine Story, kein Kommentar dokumentiert die Abwesenheit. Phase 5a Spec (Bug 99) behandelt nur den Swipe, nicht die Section.

## Blast Radius
- iOS CoachBacklogView: NextUp-Section fehlt, Tasks unsichtbar in der Masse
- macOS MacCoachBacklogView: NextUp-Section + Toggle komplett fehlt
- Keine anderen Features betroffen (Services, Shortcuts, Daten-Persistenz sind intakt)
