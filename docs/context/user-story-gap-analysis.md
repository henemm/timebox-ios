# Context: User Story Gap Analysis

## Request Summary

Vergleich der globalen User Story (`docs/project/stories/timebox-core.md`) mit dem aktuellen Implementierungsstand. Identifikation von Lücken und fehlenden Features.

---

## User Story Anforderungen vs. Ist-Stand

### Legende
- **DONE** = Vollständig implementiert
- **PARTIAL** = Teilweise implementiert
- **MISSING** = Nicht implementiert
- **SPEC ONLY** = Spec vorhanden, nicht implementiert

---

### 1. Backlog-View (Aufgaben sortieren)

| Anforderung | Status | Details |
|-------------|--------|---------|
| Tasks aus Apple Reminders laden | DONE | `EventKitRepository.swift` |
| Manuelle Sortierung (Drag & Drop) | DONE | `BacklogView.swift` |
| Duration-Badge anzeigen | DONE | `BacklogRow.swift` |
| Kategorien sichtbar | SPEC ONLY | `backlog-categories.md` - nicht implementiert |

**Gap:** Kategorien (Reminder-Listen) werden nicht angezeigt.

---

### 2. Planning-View (Aufgaben in Blöcke ziehen)

| Anforderung | Status | Details |
|-------------|--------|---------|
| Focus Blocks erstellen | DONE | `BlockPlanningView.swift` |
| Tasks zu Blöcken zuweisen | DONE | `TaskAssignmentView.swift` |
| Freie Zeitblöcke erkennen (Smart Gaps) | PARTIAL | Spec vorhanden, UI existiert aber nicht vollständig automatisch |
| Next Up Staging Area | DONE | `NextUpSection` implementiert |

**Gap:** Smart Gaps (automatische Lückenerkennung) funktioniert, aber könnte prominenter sein.

---

### 3. Live-Fokus-Modus (Herzstück)

| Anforderung | Status | Details |
|-------------|--------|---------|
| Aktuelle Aufgabe anzeigen | DONE | `FocusLiveView.swift:152-222` |
| Ablaufender Fortschrittsbalken | DONE | Progress ring in `currentTaskView` |
| Nächste Aufgabe sehen | DONE | `upcomingTasksView` |
| Timer mit Sekunden-Updates | DONE | `timer = Timer.publish(every: 1, ...)` |
| Gong/Alarm am Ende | MISSING | Kein Sound implementiert |
| Hinweis vor Ende (konfigurierbar) | MISSING | Kein Vorwarnung implementiert |
| Lockscreen sichtbar | MISSING | Keine Live Activity |
| Dynamic Island sichtbar | MISSING | Keine Live Activity |
| "Erledigt" Button | DONE | `markTaskComplete` Funktion |
| "Nicht fertig" → zurück ins Backlog | PARTIAL | SprintReviewSheet macht das, aber nicht während des Blocks |

**Gaps:**
1. **Kein Gong/Sound** am Ende des Blocks oder Tasks
2. **Kein konfigurierbarer Hinweis** vor Block-Ende ("noch 5 min")
3. **Keine Live Activity** für Lockscreen/Dynamic Island
4. **"Nicht fertig"** nur im SprintReview, nicht während des Blocks

---

### 4. Sprint Review / Rückblick

| Anforderung | Status | Details |
|-------------|--------|---------|
| Review nach Block-Ende | DONE | `SprintReviewSheet.swift` |
| Erledigte Tasks anzeigen | DONE | `completedTasksSection` |
| Prozent-Anzeige | DONE | `completionPercentage` |
| Offene Tasks zurück ins Backlog | DONE | `moveIncompleteTasks()` |
| Tages-Rückblick | MISSING | Nur Block-Level, kein Tages-Überblick |
| Wochen-Rückblick | MISSING | Nicht implementiert |

**Gaps:**
1. **Kein Tages-Rückblick** ("Was habe ich heute alles geschafft?")
2. **Kein Wochen-Rückblick** ("Womit habe ich meine Woche verbracht?")

---

### 5. Kategorien (Bedeutung geben)

| Anforderung | Status | Details |
|-------------|--------|---------|
| Schneeschaufeln | MISSING | Nicht implementiert |
| Weitergeben | MISSING | Nicht implementiert |
| Lernen | MISSING | Nicht implementiert |
| Wertschaffend | MISSING | Nicht implementiert |
| Aufladen | MISSING | Nicht implementiert |
| Rückblick nach Kategorie | MISSING | Nicht implementiert |

**Gap:** Kategorien-System komplett nicht implementiert. Dies war ein wichtiges Feature für den Nutzer, um "womit habe ich meine Zeit verbracht" zu sehen.

---

### 6. Lockscreen / Dynamic Island

| Anforderung | Status | Details |
|-------------|--------|---------|
| Live Activity | MISSING | Kein ActivityKit Import gefunden |
| Lockscreen Widget | MISSING | `TimeBoxWidgets` enthält nur QuickAdd |
| Dynamic Island | MISSING | Nicht implementiert |

**Gap:** Komplett fehlend. Zentrale User Story Anforderung.

---

### 7. Spontan-Tausch bei "nicht fertig"

| Anforderung | Status | Details |
|-------------|--------|---------|
| Task im nächsten Block weitermachen | MISSING | Nicht implementiert |

**Gap:** Nice-to-have, aber explizit in User Story erwähnt.

---

## Zusammenfassung: Gaps nach Priorität

### MUST (Fehlt für Kern-User-Story)

| Feature | Beschreibung | Aufwand |
|---------|--------------|---------|
| **Live Activity** | Lockscreen + Dynamic Island für aktiven Focus Block | Groß |
| **End-Gong/Sound** | Akustisches Signal am Block-/Task-Ende | Klein |
| **Vorwarnung** | Konfigurierbarer Hinweis vor Block-Ende ("noch 5 min") | Mittel |
| **Kategorien-System** | 5 Kategorien für Tasks (Schneeschaufeln, etc.) | Mittel |

### SHOULD (Wichtig für vollständige Experience)

| Feature | Beschreibung | Aufwand |
|---------|--------------|---------|
| **Tages-Rückblick** | Was wurde heute alles erledigt? | Mittel |
| **Wochen-Rückblick** | Zeitverteilung über die Woche | Groß |
| **"Nicht fertig" während Block** | Option während des Blocks, nicht nur im Review | Klein |

### COULD (Nice-to-have)

| Feature | Beschreibung | Aufwand |
|---------|--------------|---------|
| **Spontan-Tausch** | Unerledigte Task direkt im nächsten Block weitermachen | Mittel |
| **Kategorien-Rückblick** | Zeit-Analyse nach Kategorie | Groß |

---

## Empfohlene Implementierungsreihenfolge

1. **End-Gong/Sound** (Klein, hoher Impact)
2. **Vorwarnung vor Block-Ende** (Mittel, hoher Impact)
3. **Live Activity** (Groß, zentrales Feature)
4. **Kategorien-System** (Mittel, wichtig für Rückblick)
5. **Tages-Rückblick** (Mittel, emotionaler Wert)
6. **Wochen-Rückblick** (Groß, Langzeit-Motivation)

---

## Related Files

| File | Relevance |
|------|-----------|
| `TimeBox/Sources/Views/FocusLiveView.swift` | Haupt-View für Live-Fokus-Modus |
| `TimeBox/Sources/Views/SprintReviewSheet.swift` | Block-Review nach Ende |
| `TimeBox/TimeBoxWidgets/` | Widget-Bundle (nur QuickAdd) |
| `docs/specs/features/backlog-categories.md` | Spec für Kategorien (nicht impl.) |
| `docs/specs/features/smart-gaps-redesign.md` | Spec für Smart Gaps |

## Existing Specs

- `docs/specs/features/backlog-categories.md` - Kategorien aus Reminders (nicht impl.)
- `docs/specs/features/smart-gaps-redesign.md` - Freie Slots erkennen (teil-impl.)
- `docs/specs/features/next-up-staging-area.md` - Next Up System (implementiert)

## Dependencies

- **ActivityKit** - Benötigt für Live Activity (Lockscreen/Dynamic Island)
- **AVFoundation** - Benötigt für End-Gong Sound
- **UserNotifications** - Benötigt für Vorwarnungen

---

## Analysis (Phase 2)

### Technische Erkenntnisse

#### 1. Kategorien-System: Teilweise vorhanden!

**Überraschung:** `LocalTask.taskType` existiert bereits mit 3 Werten:
- `income` → entspricht "Wertschaffend"
- `maintenance` → entspricht "Schneeschaufeln"
- `recharge` → entspricht "Aufladen"

**Fehlend:**
- `learning` → "Lernen"
- `giving_back` → "Weitergeben"

**Änderung:** Nur 2 neue Enum-Werte hinzufügen + UI für Auswahl/Anzeige.

#### 2. Sound-System: Keine Infrastruktur

- Kein AVFoundation Import in der App
- Kein AudioToolbox Import
- `checkBlockEnd()` in `FocusLiveView.swift:380-387` zeigt nur SprintReview, spielt keinen Sound

**Ansatz:**
- `AVAudioPlayer` für Custom-Gong-Sound
- Oder `AudioServicesPlaySystemSound` für System-Sounds

#### 3. Vorwarnung: Timer existiert, Logik fehlt

- Timer läuft bereits jede Sekunde (`FocusLiveView.swift:18`)
- `calculateRemainingMinutes()` existiert
- Nur: Keine Aktion bei "5 min verbleibend"

**Ansatz:**
- State-Variable `hasShownWarning` hinzufügen
- Bei threshold → Notification/Haptic/Sound

#### 4. Live Activity: Komplett neu

- **Info.plist:** Kein `NSSupportsLiveActivities` Key
- **Entitlements:** Nur App Sandbox, keine Push-Berechtigung
- **Kein ActivityKit Import** in der App

**Benötigt:**
- Neues Widget-Target oder Erweiterung des bestehenden
- `ActivityAttributes` für Focus Block definieren
- `ActivityContent` für Dynamic Island
- Push Token für Remote-Updates (optional)

**Aufwand:** Groß - ca. 200-300 LoC + Xcode-Konfiguration

#### 5. Rückblick: Datenstruktur fehlt

- `SprintReviewSheet` zeigt nur aktuellen Block
- Keine Persistierung von "erledigte Tasks pro Tag"
- Kein History-Modell

**Ansatz:**
- Neues SwiftData Model `CompletedTaskRecord` mit Datum
- Aggregations-Queries für Tag/Woche

---

### Affected Files (pro Feature)

#### Feature 1: End-Gong/Sound
| File | Change | Description |
|------|--------|-------------|
| `FocusLiveView.swift` | MODIFY | Sound bei Block/Task-Ende |
| `Resources/` | ADD | Gong-Sounddatei (optional) |
| `Services/SoundService.swift` | CREATE | Sound-Abstraction |

**Scope:** 2-3 Files, ~50 LoC, LOW Risk

#### Feature 2: Vorwarnung
| File | Change | Description |
|------|--------|-------------|
| `FocusLiveView.swift` | MODIFY | Warning-State + Trigger |
| `Models/Settings.swift` | MODIFY | `warningMinutes` Setting |
| `Views/SettingsView.swift` | MODIFY | UI für Konfiguration |

**Scope:** 3 Files, ~60 LoC, LOW Risk

#### Feature 3: Kategorien erweitern
| File | Change | Description |
|------|--------|-------------|
| `Models/LocalTask.swift` | MODIFY | 2 neue taskType Werte |
| `Models/TaskCategory.swift` | CREATE | Enum mit allen 5 Kategorien |
| `Views/TaskCreation/` | MODIFY | Kategorie-Picker |
| `Views/BacklogRow.swift` | MODIFY | Kategorie-Badge |

**Scope:** 4 Files, ~80 LoC, LOW Risk

#### Feature 4: Live Activity
| File | Change | Description |
|------|--------|-------------|
| `Info.plist` | MODIFY | `NSSupportsLiveActivities` |
| `Models/FocusBlockActivity.swift` | CREATE | ActivityAttributes |
| `Services/LiveActivityManager.swift` | CREATE | Start/Update/End Logic |
| `FocusLiveView.swift` | MODIFY | Live Activity starten |
| `TimeBoxWidgets/` | MODIFY | Widget für Live Activity |

**Scope:** 5+ Files, ~250 LoC, MEDIUM Risk (Xcode-Config)

#### Feature 5: Tages-Rückblick
| File | Change | Description |
|------|--------|-------------|
| `Models/CompletedTaskRecord.swift` | CREATE | History-Model |
| `Services/HistoryService.swift` | CREATE | Speichern/Laden |
| `Views/DailyReviewView.swift` | CREATE | Tages-Übersicht |
| `SprintReviewSheet.swift` | MODIFY | Tasks speichern |

**Scope:** 4 Files, ~150 LoC, LOW Risk

---

### Implementierungsplan (6 Sprints)

| Sprint | Feature | Files | LoC | Risk |
|--------|---------|-------|-----|------|
| 1 | End-Gong/Sound | 2-3 | ~50 | LOW |
| 2 | Vorwarnung | 3 | ~60 | LOW |
| 3 | Kategorien (5 statt 3) | 4 | ~80 | LOW |
| 4 | Live Activity | 5+ | ~250 | MEDIUM |
| 5 | Tages-Rückblick | 4 | ~150 | LOW |
| 6 | Wochen-Rückblick | 2 | ~100 | LOW |

**Gesamt:** ~690 LoC über 6 Sprints

---

### Open Questions (RESOLVED)

- [x] Welcher Sound für End-Gong? → **System-Sound, konfigurierbar (mit/ohne)**
- [x] Soll Vorwarnung auch Sound/Vibration haben? → **Ja, konfigurierbar**
- [x] Live Activity: Mit oder ohne Push-Updates? → **Mit Push für Background**
- [x] Kategorien: Deutsche oder englische Enum-Namen? → **Englisch (lokalisierbar)**

### Design Decisions

| Entscheidung | Wert |
|--------------|------|
| End-Gong Sound | System-Sound (AudioServices) |
| Sound konfigurierbar | Ja (Settings) |
| Vorwarnung mit Sound | Ja, konfigurierbar |
| Vorwarnung mit Haptic | Ja, konfigurierbar |
| Live Activity Push | Ja (für Background-Updates) |
| Kategorie-Enum | Englisch (`TaskCategory.learning`, etc.) |
| Lokalisierung | Später via Strings-File |

---

*Analyse abgeschlossen: 2026-01-22*
*Workflow: user-story-gap-analysis*
