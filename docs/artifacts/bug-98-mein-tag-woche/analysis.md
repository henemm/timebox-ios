# Bug 98 Analyse: Mein Tag Woche — motivierende Worte + erledigte Tasks

## Bug-Beschreibung (Original)
"Mein Tag Woche zeigt nur Sprint-Tasks — ausserhalb Sprints erledigte fehlen"

## Erweiterte Anforderung (Henning 2026-03-15)
Motivierende Worte am Ende des Tages UND am Ende der Woche ueber erledigte Tasks und Termine.
Zwei Varianten: 1. Normal (ohne Coach) 2. Monster (mit Coach).

---

## 1. Zusammenfassung der Agenten-Ergebnisse

### Agent 1: Wiederholungs-Check
- Bug 98 wurde NIE angefasst — kein Commit, keine Investigation
- Weekly Review Spec existiert als DRAFT (`docs/specs/features/weekly-review.md`)
- DailyReviewView hat bereits "Heute/Diese Woche" Segmented Picker
- CoachMeinTagView hat KEINE Wochenansicht

### Agent 2: Datenfluss-Trace
- Tasks werden via `LocalTask.isCompleted` + `completedAt` getrackt
- `weekCompletedTasks` in DailyReviewView filtert KORREKT nach Datum (NICHT nach Sprint)
- CoachMeinTagView zeigt NUR `todayCompletedCount` — kein Wochen-Support
- EveningReflectionTextService generiert AI-Text NUR fuer den Tag

### Agent 3: Alle Schreiber
- 6 Completion-Pfade identifiziert (SyncEngine, FocusBlockActionService, Watch, TaskInspector, etc.)
- `LocalTaskSource.markComplete()` setzt `completedAt` NICHT — ist aber **bestaetigt Dead Code** (keine Produktions-Aufrufer, nur Protocol-Konformitaet + Tests)
- Wochen-Filterung nutzt `completedAt` — Tasks ohne dieses Feld waeren unsichtbar (aber kein aktiver Pfad produziert solche Tasks)

### Agent 4: Szenarien
- CoachMeinTagView hat KEINEN Weekly Mode (kein Picker, keine Wochen-Properties)
- Evening Reflection ist rein taeglich (AI-Text, Fallback-Templates, Fulfillment-Level)
- Kein "motivierende Worte fuer die Woche" — weder normal noch Monster-Variante

### Agent 5: Blast Radius
- ~4 Dateien betroffen, ~220 LoC
- Keine Model-Aenderungen noetig
- Reines Additive — taegliches System bleibt unberuehrt
- Wochen-Logik ist in DailyReviewView bewiesen und kann uebernommen werden

### Devil's Advocate Ergebnisse (Challenge-Runde)
- **DailyReviewView (Non-Coach) hat einen ECHTEN Bug:** Zeile 182 — `if weekBlocks.isEmpty { weeklyEmptyState }` zeigt leeren Zustand wenn keine Focus-Blocks existieren, OBWOHL Tasks ausserhalb von Blocks erledigt wurden. Die `outsideSprintSection` fehlt im Wochen-Modus.
- **macOS nutzt DailyReviewView NICHT** — macOS hat eigene MacReviewView oder shared CoachMeinTagView

---

## 2. ALLE moeglichen Ursachen (5 Hypothesen)

### Hypothese A: DailyReviewView Wochen-Modus verbirgt "ohne Sprint" Tasks
- **Beweis DAFUER:** Code Zeile 182 — `if weekBlocks.isEmpty { weeklyEmptyState }` — wenn ein User keine Focus-Blocks in einer Woche hatte aber Tasks per Checkbox erledigt hat, sieht er "Keine Blocks geplant" statt seine erledigten Tasks.
- **Beweis DAFUER:** `outsideSprintSection` existiert NUR im Tages-Modus (Zeile 175), NICHT im Wochen-Modus
- **Beweis DAGEGEN:** Tasks erscheinen im `categoryStatsSection` (Kategorie-Diagramm), aber NICHT als individuelle Liste
- **Wahrscheinlichkeit:** HOCH — das ist Bug 98 im Non-Coach-Modus

### Hypothese B: CoachMeinTagView hat KEINE Wochenansicht
- **Beweis DAFUER:** Code bestaetigt — kein `ReviewMode`, kein Picker, nur `todayCompletedCount`
- **Beweis DAGEGEN:** Keiner — das Feature existiert einfach nicht
- **Wahrscheinlichkeit:** HOCH — das ist Bug 98 im Coach-Modus

### Hypothese C: Filter-Bug — Wochen-Filter zeigt nur Sprint-Tasks
- **Beweis DAFUER:** Bug-Beschreibung sagt "nur Sprint-Tasks"
- **Beweis DAGEGEN:** `weekCompletedTasks` filtert nach `completedAt` Datum, NICHT nach Sprint. Die Filterlogik ist korrekt.
- **Wahrscheinlichkeit:** NIEDRIG — Code ist korrekt, aber das UI zeigt die Tasks nicht an (siehe Hypothese A)

### Hypothese D: Tasks ohne `completedAt` sind unsichtbar
- **Beweis DAFUER:** `LocalTaskSource.markComplete()` setzt `completedAt` NICHT
- **Beweis DAGEGEN:** Bestaetigt Dead Code (fruehere Analyse bug-dep-4b). Kein Produktions-Aufrufer.
- **Wahrscheinlichkeit:** NULL — Dead Code, keine Bedrohung

### Hypothese E: Motivierende Wochen-Texte fehlen komplett
- **Beweis DAFUER:** Kein `generateWeeklyText()`, keine Weekly-Fallback-Templates
- **Beweis DAGEGEN:** Keiner — das Feature existiert nicht
- **Wahrscheinlichkeit:** HOCH — fehlendes Feature

---

## 3. Wahrscheinlichste Ursachen

**Bug 98 hat ZWEI Root Causes:**

1. **DailyReviewView (Non-Coach):** Die Wochenansicht zeigt `weeklyEmptyState` wenn keine Blocks existieren und hat keine `outsideSprintSection`. Tasks die ohne Sprint erledigt wurden, sind nur im Kategorie-Diagramm sichtbar, nicht als individuelle Eintraege. **Das ist ein echter Code-Bug.**

2. **CoachMeinTagView (Coach-Modus):** Hat gar keine Wochenansicht. **Das ist ein fehlendes Feature.**

**Zusaetzlich:** Motivierende Texte (Hennings erweiterte Anforderung) existieren fuer die Woche weder im normalen noch im Monster-Modus.

---

## 4. Kein Debugging noetig

Die Analyse ist eindeutig:
- Bug in DailyReviewView: `weekBlocks.isEmpty` Guard ist zu restriktiv
- Fehlendes Feature in CoachMeinTagView: kein Weekly Mode
- Fehlendes Feature: keine motivierenden Wochen-Texte

---

## 5. Blast Radius

### Plattform-Matrix:
| Modus | iOS | macOS |
|-------|-----|-------|
| **Coach AN** | CoachMeinTagView (shared) — KEIN Weekly Mode | CoachMeinTagView (shared) — KEIN Weekly Mode |
| **Coach AUS** | DailyReviewView — BUG in Weekly Mode | MacReviewView — separat zu pruefen |

### Scope-Bewertung:
Hennings Anforderung umfasst eigentlich **3 Teile:**

1. **Bug-Fix:** DailyReviewView Wochenansicht zeigt auch "ohne Sprint" erledigte Tasks (kleiner Fix, ~15 LoC)
2. **Feature:** CoachMeinTagView bekommt Wochen-Ansicht mit motivierenden Coach-Texten (~120 LoC)
3. **Feature:** Motivierende Texte auch im Normal-Modus (DailyReviewView) (~80 LoC)

**Empfehlung:** Teil 1 + 2 zusammen als "Bug 98 + Coach Weekly". Teil 3 separat.
