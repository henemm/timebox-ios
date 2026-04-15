# Bug #223: Count Badge unklar — Analyse

## Zusammenfassung

Das Tab-Badge am Backlog zeigt eine Zahl (z.B. "7"), aber der User kann nicht erkennen, WELCHE Tasks dahinterstecken. Im Backlog selbst haben die gezählten Tasks keine visuelle Kennzeichnung.

## Was der Badge tatsächlich zählt

**"Stale Tasks"** — Tasks die Aufmerksamkeit brauchen, weil sie:
- >= 14 Tage alt sind (seit Erstellung), ODER
- >= 3x verschoben wurden (`rescheduleCount >= 3`)

Ausgenommen: erledigte, geparkte, Template-Tasks, und Tasks mit Hygiene-Review innerhalb der letzten 14 Tage.

**Code:** `MainTabView.swift:19-22` → `BacklogHealthService.findStaleTasks()`

## Root Cause

**Zwei Probleme:**

1. **Fehlende visuelle Markierung:** Die stale Tasks im Backlog-Liste sind nicht visuell hervorgehoben. Der User sieht "(7)" am Tab, aber im Backlog sehen alle Tasks gleich aus. Es gibt zwar einen Hygiene-Banner ("X Tasks liegen seit Wochen rum"), aber die einzelnen Tasks selbst sind nicht markiert.

2. **Inkonsistenz Badge vs. Hygiene-Sheet:** `MainTabView` nutzt Default-Werte (14 Tage / 3x), `BacklogView` nutzt `AppSettings`-Werte. Wenn der User die Schwellwerte ändert, stimmen Badge und Hygiene-Sheet nicht mehr überein.

3. **macOS hat kein Badge:** Kein Tab-Badge, kein Sidebar-Badge — Feature fehlt komplett.

## Hypothesen

| # | Hypothese | Wahrscheinlichkeit |
|---|-----------|-------------------|
| 1 | Stale Tasks brauchen visuelle Kennzeichnung in der Liste | **HOCH** — Kernproblem |
| 2 | Badge-Zahl stimmt nicht mit sichtbaren Stale-Tasks überein (Inkonsistenz) | MITTEL — latenter Bug |
| 3 | Badge-Konzept "stale" ist dem User nicht erklärt | MITTEL — kein Tooltip/Erklärung |

## Blast Radius

- `BacklogHealthService.findStaleTasks()` wird genutzt von: Tab-Badge, Hygiene-Sheet, SmartNotificationEngine
- App-Icon-Badge (iOS) hat separate Logik (überfällige Tasks, nicht stale)
- macOS: kein Badge implementiert
- Änderungen an der Stale-Logik betreffen alle drei Verbraucher
