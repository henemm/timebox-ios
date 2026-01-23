# UI Test Plan: Scrolling in Listen-Containern

## Test-Scope

Umfassende Tests für alle Views, die Listen von Items in Containern anzeigen.

---

## 1. TaskAssignmentView Tests

### 1.1 FocusBlockCard Scrolling

**Precondition:** Focus Block mit 10+ zugewiesenen Tasks

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| TASK-SCROLL-001 | Block mit 10 Tasks anzeigen | Alle 10 Tasks sichtbar durch Scrolling |
| TASK-SCROLL-002 | Block mit 20 Tasks anzeigen | Alle 20 Tasks erreichbar |
| TASK-SCROLL-003 | Letzten Task in Block antippen | Remove-Button funktioniert |
| TASK-SCROLL-004 | Tasks innerhalb Block reordern | Drag&Drop funktioniert für alle Tasks |
| TASK-SCROLL-005 | Mehrere Blocks mit vielen Tasks | Jeder Block unabhängig scrollbar |

**Mock-Daten benötigt:**
- 1 Focus Block mit 20 Tasks
- 3 Focus Blocks mit je 10 Tasks

### 1.2 Task Backlog Scrolling

**Precondition:** 15+ unassigned Tasks im Next Up

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| TASK-SCROLL-006 | 15 unassigned Tasks anzeigen | Alle Tasks erreichbar |
| TASK-SCROLL-007 | Letzten Task nach oben bewegen | Move-Up Button funktioniert |
| TASK-SCROLL-008 | Task per Drag&Drop zuordnen | Funktioniert für alle Tasks |

---

## 2. BlockPlanningView Tests

### 2.1 Existing Blocks Section

**Precondition:** 10+ Focus Blocks für einen Tag

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| BLOCK-SCROLL-001 | 10 Blocks anzeigen | Alle Blocks sichtbar |
| BLOCK-SCROLL-002 | Letzten Block antippen | Edit-Sheet öffnet sich |
| BLOCK-SCROLL-003 | Letzten Block löschen (Swipe) | Swipe-Action funktioniert |
| BLOCK-SCROLL-004 | 15 Blocks anzeigen | Alle erreichbar |

**Mock-Daten benötigt:**
- 15 Focus Blocks für einen Tag

---

## 3. BacklogView Tests

### 3.1 Next Up Section

**Precondition:** 20+ Tasks in Next Up

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| BACKLOG-SCROLL-001 | 20 Next Up Tasks anzeigen | Alle Tasks sichtbar |
| BACKLOG-SCROLL-002 | Letzten Next Up Task entfernen | Button funktioniert |
| BACKLOG-SCROLL-003 | Section scrollt unabhängig | Kein Konflikt mit Main-List |

### 3.2 Eisenhower Matrix Quadrants

**Precondition:** 10+ Tasks pro Quadrant

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| BACKLOG-SCROLL-004 | Do First mit 10 Tasks | Zeigt "5 weitere" Link |
| BACKLOG-SCROLL-005 | Alle Quadranten gefüllt | Kein Clipping |
| BACKLOG-SCROLL-006 | Main ScrollView scrollt | Alle Quadranten erreichbar |

### 3.3 Category/Duration/DueDate Views

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| BACKLOG-SCROLL-007 | 50 Tasks in Category-View | Alle Sections scrollbar |
| BACKLOG-SCROLL-008 | 50 Tasks in Duration-View | Alle Buckets erreichbar |
| BACKLOG-SCROLL-009 | 50 Tasks in DueDate-View | Alle Sections erreichbar |

---

## 4. Edge Case Tests

### 4.1 Extreme Datenmengen

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| EDGE-001 | 50 Tasks in einem Block | Alle erreichbar, Performance OK |
| EDGE-002 | 100 Tasks im Backlog | Smooth Scrolling |
| EDGE-003 | 30 Focus Blocks an einem Tag | Alle Blocks erreichbar |

### 4.2 Nested Scrolling

| Test ID | Beschreibung | Erwartetes Ergebnis |
|---------|--------------|---------------------|
| EDGE-004 | Inner-List vs Outer-ScrollView | Kein Scroll-Konflikt |
| EDGE-005 | Scroll-Velocity | Smooth, kein Ruckeln |
| EDGE-006 | Scroll-Bounce | Natürliches Verhalten |

---

## 5. Mock-Daten Anforderungen

### Für vollständige Test-Coverage benötigt:

```
Focus Blocks:
- 15 Blocks für einen Tag
- Davon mindestens 3 mit 10+ Tasks
- 1 Block mit 20+ Tasks

Tasks:
- 100 Tasks total
- 20 als "Next Up" markiert
- Verteilung über alle Kategorien
- Verteilung über alle Prioritäten/Urgencies
- Verschiedene Dauern (5-120 min)
- Verschiedene Due Dates
```

---

## 6. Automatisierte UI Tests

### Test-Datei: `ScrollingUITests.swift`

```swift
// Zu implementierende Tests:

func testFocusBlockScrollingWith10Tasks()
func testFocusBlockScrollingWith20Tasks()
func testLastTaskInBlockAccessible()
func testTaskBacklogScrolling()
func testBlockPlanningViewScrolling()
func testNextUpSectionScrolling()
func testEisenhowerMatrixScrolling()
func testCategoryViewScrolling()
func testExtremeDataPerformance()
```

---

## 7. Acceptance Criteria

Der Bug ist gefixt wenn:

1. ✅ Alle Tasks in einem Focus Block erreichbar sind (bis 50 Tasks)
2. ✅ Alle Focus Blocks in BlockPlanningView erreichbar sind (bis 30 Blocks)
3. ✅ Kein Scroll-Konflikt zwischen Inner-List und Outer-ScrollView
4. ✅ Performance bleibt akzeptabel (< 100ms Scroll-Latenz)
5. ✅ Alle UI Tests GRÜN
