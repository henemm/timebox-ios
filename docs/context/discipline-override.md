# Context: Discipline Override

## Request Summary
User soll per Long-Press/Context-Menu auf Tasks im CoachBacklogView die automatisch berechnete Discipline (Konsequenz/Mut/Fokus/Ausdauer) manuell ueberschreiben koennen. Die Kreisfarbe des Checkboxes aendert sich entsprechend.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/Discipline.swift` | Enum mit 4 Cases + `classifyOpen()` — muss Override-Logik bekommen |
| `Sources/Models/LocalTask.swift` | SwiftData Model — braucht neues Feld `manualDiscipline: String?` |
| `Sources/Models/PlanItem.swift` | Read-only Bridge-Struct — braucht `manualDiscipline` Mapping |
| `Sources/Views/CoachBacklogView.swift` | iOS Coach-Backlog — Context Menu + Override-Logik einfuegen |
| `Sources/Views/BacklogRow.swift` | iOS Task-Row — empfaengt bereits `disciplineColor: Color?` |
| `FocusBloxMac/MacCoachBacklogView.swift` | macOS Coach-Backlog — gleiche Context Menu Aenderung |
| `FocusBloxMac/MacBacklogRow.swift` | macOS Task-Row — empfaengt bereits `disciplineColor: Color?` |
| `Sources/Services/SyncEngine.swift` | Persistence-Layer — braucht `updateDiscipline()` Methode |
| `Sources/Views/NextUpSection.swift` | Bestehendes `.contextMenu` Pattern als Vorlage |

## Existing Patterns

- **Discipline-Berechnung:** `Discipline.classifyOpen(rescheduleCount:importance:)` — rein automatisch, kein Override
- **Discipline-Farbe:** Wird in `coachRow()` berechnet und als `disciplineColor` an BacklogRow/MacBacklogRow uebergeben
- **Context Menu:** `.contextMenu { ... } preview: { ... }` Pattern existiert in `NextUpSection.swift` (Zeile 46-65)
- **SwiftData Felder:** Alle optional-Felder haben Default `nil`, CloudKit-kompatibel
- **SyncEngine Updates:** Pattern `findTask(byID:)` → Feld setzen → `modelContext.save()`
- **PlanItem Bridge:** `init(localTask:)` mapped alle LocalTask-Felder 1:1

## Dependencies

### Upstream (was unser Code nutzt)
- `Discipline` Enum (Farben, Icons, DisplayNames)
- `LocalTask` SwiftData Model + CloudKit Sync
- `SyncEngine` fuer Persistence
- `PlanItem` als Read-Only Bridge (iOS)

### Downstream (was unseren Code nutzt)
- `CoachBacklogView` / `MacCoachBacklogView` — zeigen Discipline-Farbe
- `BacklogRow` / `MacBacklogRow` — rendern die Farbe
- `CoachBacklogViewModel` — Filter-Logik (NICHT betroffen, nutzt eigene Regeln)
- `IntentionEvaluationService` — Fulfillment-Berechnung (NICHT betroffen, nutzt eigene Metriken)

## Existing Specs
- `docs/specs/features/nextup-long-press-preview.md` — Context Menu Pattern auf Tasks

## Risks & Considerations

1. **CloudKit Migration:** Neues `manualDiscipline: String?` Feld auf SwiftData Model. CloudKit-kompatibel da optional mit Default `nil`. Lightweight Migration automatisch.
2. **PlanItem Mapping:** `PlanItem` ist ein Read-Only Struct — muss das neue Feld durchreichen fuer die Farb-Berechnung
3. **String vs Enum:** SwiftData CloudKit erfordert primitive Typen. `manualDiscipline` muss als `String?` gespeichert werden (nicht als `Discipline?`). Konvertierung via `Discipline(rawValue:)`.
4. **Coach-Filter unabhaengig:** Die Coach-Sektionszuordnung (Troll: rescheduleCount, Feuer: importance, etc.) wird NICHT veraendert. Override aendert nur die Kreisfarbe, nicht die Sektion.
5. **Scope:** 6 Produktions-Dateien, geschaetzt ~120 LoC netto. Innerhalb Scoping Limits.

---

## Analysis

### Type
Feature (Prio 7 aus ACTIVE-todos.md)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/LocalTask.swift` | MODIFY | Neues Feld `var manualDiscipline: String?` (CloudKit-kompatibel) |
| `Sources/Models/PlanItem.swift` | MODIFY | `manualDiscipline` in `init(localTask:)` mappen |
| `Sources/Models/Discipline.swift` | MODIFY | `resolveOpen()` Methode: Override hat Vorrang vor Auto-Berechnung |
| `Sources/Views/CoachBacklogView.swift` | MODIFY | Context Menu auf `coachRow()` + Override-Callback + `resolveOpen()` statt `classifyOpen()` |
| `FocusBloxMac/MacCoachBacklogView.swift` | MODIFY | Context Menu auf `coachRow()` + Override-Callback + `resolveOpen()` statt `classifyOpen()` |
| `Sources/Services/SyncEngine.swift` | MODIFY | Neue Methode `updateDiscipline(itemID:discipline:)` |

**NICHT betroffen:**
- `BacklogRow.swift` / `MacBacklogRow.swift` — empfangen bereits `disciplineColor`, kein Change noetig
- `CoachBacklogViewModel` — Filter-Logik nutzt KEINE Discipline (sondern eigene Regeln pro Coach)
- `IntentionEvaluationService` — Fulfillment nutzt eigene Metriken
- Review-Views (DailyReviewView, CoachMeinTagView) — zeigen erledigte Tasks, kein Override

### Call-Site Analyse

| Funktion | Aufrufer | Auswirkung |
|----------|----------|------------|
| `Discipline.classifyOpen()` | `CoachBacklogView.coachRow()`, `MacCoachBacklogView.coachRow()` | Wird ersetzt durch `resolveOpen()` — NUR 2 Call-Sites |
| `disciplineColor` (Parameter) | `BacklogRow`, `MacBacklogRow` | Empfangen Farbe — keine Aenderung noetig |
| `PlanItem(localTask:)` | `SyncEngine.sync()`, `SyncEngine.syncRecurring()`, `MacCoachBacklogView` | Muss neues Feld mappen |
| `CoachType.filterTasks()` | `CoachBacklogViewModel` | Nutzt NICHT Discipline — unabhaengig |

### Scope Assessment
- **Produktions-Dateien:** 6
- **Estimated LoC:** +80/-10 (netto ~70 LoC)
- **Risk Level:** LOW — rein additiv, isoliert auf Coach-Modus, keine bestehende Logik geaendert

### Technical Approach

1. **Model:** `manualDiscipline: String?` auf `LocalTask` (SwiftData, CloudKit-kompatibel)
2. **Resolution:** `Discipline.resolveOpen(manualDiscipline:rescheduleCount:importance:)` — Override > Auto
3. **Persistence:** `SyncEngine.updateDiscipline(itemID:discipline:)` — schlanke Methode, folgt bestehendem Pattern
4. **UI:** `.contextMenu` auf `coachRow()` (NICHT auf BacklogRow) — 4 Optionen + "Zuruecksetzen"
5. **Bridge:** `PlanItem.manualDiscipline` Property durchreichen

### Open Questions
- Keine — Scope und Ansatz sind klar definiert
