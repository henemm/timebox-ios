---
entity_id: coach_tag_grouping
type: feature
created: 2026-04-16
updated: 2026-04-16
status: draft
version: "1.0"
tags: [coach, tags, grouping]
---

# Coach: Tag-Gruppierung (#236)

## Approval

- [ ] Approved

## Purpose

Wenn 2+ vorgeschlagene Tasks denselben Tag teilen, zeigt der Coach sie als gebündelte Gruppe mit spezifischem Coaching-Text statt als einzelne Vorschläge. Das spart Kontext-Wechsel und fühlt sich schlauer an.

## Source

- **File:** `Sources/Views/CoachView.swift`
- **Bereich:** `morningContent`, `coachTaskSection`, `groupTasksByReason`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NextUpSuggestionService.tagClusterBonus` | Scoring | Existierender Tag-Cluster-Bonus fürs Ranking |
| `PlanItem.tags` | Model | Tag-Liste pro Task |
| `CoachView.groupTasksByReason` | View-Logik | Bestehende Reason-Gruppierung |

## Spezifikation

### Gruppierungs-Logik

1. **Eingabe:** `morningTopTasks` (max 5 Tasks, bereits nach Score sortiert)
2. **Tag-Cluster finden:** Für jeden Tag prüfen wie viele Tasks ihn haben. Tags mit >= 2 Tasks bilden einen Cluster.
3. **Priorität:** Wenn ein Tag-Cluster existiert, wird er VOR der Reason-Gruppierung angezeigt.
4. **Zuordnung:** Ein Task gehört zum größten Cluster. Bei Gleichstand: alphabetisch erster Tag. Jeder Task wird nur einmal angezeigt.
5. **Rest:** Tasks ohne Cluster-Zugehörigkeit durchlaufen die bestehende `groupTasksByReason`-Logik.

### Darstellung

**Tag-Cluster-Gruppe:**
- Section-Header: Tag-Icon (`tag.fill`) + "#tagname" als Titel, Farbe: `.blue`
- Coaching-Text: "N Aufgaben mit #tagname — erledige sie in einem Rutsch"
- Darunter: Die Tasks als Liste (wie bestehende Einzeldarstellung mit Actions)

**Fallback (kein Cluster):**
- Bestehende Darstellung bleibt unverändert (Reason-Gruppierung)

### Regeln

- **Minimum:** 2 Tasks pro Tag-Cluster (sonst kein Cluster)
- **Maximum:** 1 Tag-Cluster pro Coach-Ansicht (der größte gewinnt)
- **Coach-Headline:** Wird angepasst wenn Tag-Cluster + Reason-Gruppen koexistieren

## Expected Behavior

- **Input:** `morningTopTasks` mit 2+ Tasks die denselben Tag haben
- **Output:** Gebündelte Darstellung mit Coaching-Text der den Tag nennt
- **Fallback:** Keine Tags oder < 2 Tasks pro Tag → bestehende Darstellung

### Beispiele

**3 von 5 Tasks haben #computer:**
```
[Tag-Cluster] "3 Aufgaben mit #computer — erledige sie in einem Rutsch"
  - Task A
  - Task B  
  - Task C
[Reason-Gruppe] "Wichtiges"
  - Task D
  - Task E
```

**Keine gemeinsamen Tags:**
→ Bestehende Reason-Gruppierung (keine Änderung)

## Betroffene Dateien

| Datei | Änderung |
|-------|----------|
| `Sources/Views/CoachView.swift` | Tag-Cluster-Logik + Darstellung in `morningContent` / `coachTaskSection` |

## Known Limitations

- Maximal 1 Tag-Cluster (bei 5 Tasks realistisch)
- Tag muss exakt matchen (case-sensitive, wie bestehend)

## Changelog

- 2026-04-16: Initial spec created
