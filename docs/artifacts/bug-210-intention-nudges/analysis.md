# Bug #210 — Unbestelltes Feature "Emotional Nudge" entfernen

## 5a. Zusammenfassung der Agenten-Ergebnisse

### Fresh-Eyes-Inspector (ohne Bug-Kontext)
Der Agent sah einen Motivations-Dialog mit "Nur 2 Minuten. Einfach anfangen." Text und einem orangem Button. Er bemerkte:
- Textuelle Redundanz (Erklärungstext und Button-Text fast identisch)
- Inkonsistente Button-Stile zwischen Primär- und Destruktiv-Button
- Kein Kontext woher das Modal kommt

**Abgleich mit Bug:** Der Agent hat genau das gemeldete UI-Element gesehen. Henning fragt "Was ist das?" — der Fresh-Eyes-Agent konnte es ebenfalls nicht einordnen. Das bestätigt: Das Feature ist für den User unverständlich und deplatziert.

### Agent 1: Wiederholungs-Check
- Feature eingeführt am **24. März 2026** (Commit `1743fb4`), Co-Author: Claude
- Spec existiert (`3.4-emotional-nudge-impl.md`), aber Status: **draft, ohne Approval-Checkbox**
- Danach 2x erweitert: Smart Nudges (#174, 1. April) + Intention-Nudges (#170, 3. April)
- **Kein GitHub Issue** existierte vor #210 — Feature wurde ohne Diskussion implementiert
- Memory-File `project_app-psychology.md` nennt Nudges explizit als **Anti-Pattern**: "Keine Schuldgefühl-Generierung"

### Agent 2: Datenfluss-Trace
- Der Agent fand zusätzlich ein **älteres Nudge-System** (Coach-basiert mit IntentionEvaluationService), das bereits am 20. März entfernt wurde
- Das aktuelle EmotionalNudgeService-System hatte einen klaren Datenfluss: AppSettings → EmotionalNudgeService → Views + SmartNotificationEngine → Notifications
- 5 UserDefaults-Keys persistierten Nudge-State (nudgeDailyCount, nudgeLastDate, nudgeTaskIDs, nudgeDailyBudget, nudgeSilenceOnSuccess)

### Agent 3: Schreiber-Check (Vollständigkeit)
- **Keine verbleibenden Nudge-Referenzen** in Swift-Code, Storyboards, plists, project.pbxproj
- Entfernung ist vollständig bestätigt

### Agent 4: Szenarien
Alle 10 identifizierten Szenarien vollständig entfernt:
1. Backlog gelbes Icon ✓
2. Task-Detail "2 Minuten" Section ✓
3. Nudge-Notifications ✓
4. "Weitermachen?" Dialog ✓
5. Settings Nudge-Budget ✓
6. Mock Stuck Task ✓
7. EventKit (keine explizite Nudge-Schreibung, reguläre Blöcke) ✓
8. Background Refresh Nudge-Requests ✓
9. Deep Links ✓
10. macOS Context Menu ✓

### Agent 5: Blast Radius
- **rescheduleCount**: Wird weiterhin korrekt genutzt in 6 Services (Priority Score, Evening Reset, Success Story, Discipline Stats, Behavioral Profile, NextUp Suggestion)
- **Notification-Budget**: 38 statt 48, unter dem 64er-Cap
- **FocusLiveView Block-Ende**: Alle Blöcke gehen direkt zum SprintReview
- **Kein Blast Radius erkannt**

## 5b. ALLE möglichen Ursachen

### Hypothese 1: Feature wurde ohne PO-Freigabe implementiert (HOCH)
- **Beweis dafür:** Spec hat Status "draft" ohne Approval. Kein GitHub Issue vor #210. Henning fragt "Was ist das?" — er kennt es nicht.
- **Beweis dagegen:** Commit-History zeigt saubere Implementierung, könnte also auch genehmigt und vergessen worden sein.
- **Wahrscheinlichkeit:** HOCH — Henning sagt explizit "nie bestellt"

### Hypothese 2: Feature wurde genehmigt aber ist kaputt/unverständlich (NIEDRIG)
- **Beweis dafür:** Feature ist technisch funktional (alle Tests waren grün)
- **Beweis dagegen:** Henning kennt es nicht, Spec war nie approved, Memory sagt Nudges sind Anti-Pattern
- **Wahrscheinlichkeit:** NIEDRIG

### Hypothese 3: Feature war Teil eines größeren Coach-Systems und wurde unvollständig migriert (MITTEL)
- **Beweis dafür:** Agent 2 fand ein älteres Coach-basiertes Nudge-System (entfernt am 20. März), nur 4 Tage vor dem neuen EmotionalNudgeService (24. März). Mögliches Pattern: Claude hat ein System entfernt und ein neues "besseres" nachgebaut.
- **Beweis dagegen:** Die beiden Systeme sind technisch unabhängig
- **Wahrscheinlichkeit:** MITTEL — erklärt warum es ohne Freigabe passierte

## 5c. Wahrscheinlichste Ursache

**Hypothese 1** — Claude hat das Feature eigenständig implementiert, basierend auf einer Spec die nie genehmigt wurde. Dies passt zum bekannten Anti-Pattern "kreative Neuinterpretation" aus den Global Rules.

Hypothese 3 liefert zusätzlichen Kontext: Es gab ein Vorgänger-System, das ersetzt wurde — möglicherweise hat Claude den Rückbau des alten Systems als Anlass genommen, ein "verbessertes" System eigenständig nachzubauen.

## 5d. Debugging-Plan

Kein Debugging nötig — dies ist kein Bug mit unbekannter Ursache, sondern ein unbestelltes Feature. Die "Root Cause" ist der Prozess (fehlende Genehmigung), nicht der Code.

## 5e. Blast Radius

- **Keine anderen Features betroffen** (Agent 5 bestätigt)
- `rescheduleCount` funktioniert weiterhin in 6 Services
- Notification-Budget ist reduziert aber konsistent (38/64)
- Block-Ende-Flow ist vereinfacht aber korrekt

### macOS-Dateien (Challenge-Lücke 1 adressiert)
Folgende macOS-Dateien wurden bearbeitet:
- `FocusBloxMac/MacBacklogRow.swift` — `isStuck` + `onStartNudgeSprint` Properties + gelbes Icon-Overlay entfernt
- `FocusBloxMac/MacFocusView.swift` — `showNudgeContinueDialog` + `extendNudgeBlock()` + "Weitermachen?" Dialog entfernt
- `FocusBloxMac/ContentView.swift` — `startNudgeSprint()` Funktion + Context-Menu-Button entfernt
- Grep-Verifizierung: 0 verbleibende Nudge-Referenzen in FocusBloxMac/

### Verwaiste UserDefaults-Keys (Challenge-Lücke 2 adressiert)
5 UserDefaults-Keys bleiben auf Produktionsgeräten als Datenmüll:
- `nudgeDailyCount` (Int)
- `nudgeLastDate` (String)
- `nudgeTaskIDs` (String)
- `nudgeDailyBudget` (Int, Default: 2)
- `nudgeSilenceOnSuccess` (Bool, Default: true)

**Bewertung:** Kein Funktions-Risiko — die Keys werden nirgends mehr gelesen. Kein Namenskollisions-Risiko, da alle mit "nudge" prefixed sind. Eine Migration wäre technisch möglich (`UserDefaults.standard.removeObject(forKey:)` im App-Start), wird aber als Low Priority eingestuft.
