# Bug-Analyse: Long-Press zeigt kein Preview ohne Faelligkeitsdatum

**Bug:** Long-Press auf Task-Titel zeigt KEIN Preview, wenn Task kein `dueDate` hat.
**Bestaetigung:** Henning verifiziert — bei Tasks MIT Faelligkeit funktioniert es, OHNE Faelligkeit passiert nichts.
**Feature-Commit:** `527f441e` (fixes #300)

---

## User-Erwartung (User Advocate)

> "Ein Task ist ein Task. Long-Press = mehr Details — egal welcher Task. Ich sehe als User keinen Unterschied zwischen Tasks mit oder ohne Faelligkeit. Wenn das Feature da ist, muss es ueberall funktionieren."

User-Frust: **Vertrauensbruch** — bei manchen Tasks passiert nichts. User weiss nicht, ob er es falsch macht oder das Feature kaputt ist. Beginnt zu raten.

---

## Root Cause (uebereinstimmend von 4 Investigatoren)

**Datei:** `Sources/Views/BacklogView.swift`
**Stellen:** Zeile 1123-1129 (NextUp-Sektion "Heute") und Zeile 1208-1214 (Backlog-Hauptliste)

```swift
.contextMenu {
    if item.dueDate != nil {
        postponeMenu(for: item)
    }
} preview: {
    TaskPreviewView(task: item)
}
```

**Mechanismus:** SwiftUI's `.contextMenu(menuItems:preview:)` deaktiviert den gesamten Modifier (inklusive `preview:`), wenn die `menuItems`-Closure eine leere View liefert. Bei `item.dueDate == nil` → leerer Body → kein Long-Press, kein Preview.

**Belegt durch:** Apple SwiftUI-API + Code-Vergleich mit funktionierenden Stellen.

---

## Stimmen der Investigatoren

### Investigator "Wiederholungs-Check"
> Kein bekannter Vor-Bug. Kein Eintrag in `learnings.md` zu diesem Edge-Case. Pattern wurde mit `527f441e` neu eingefuehrt.

### Investigator "Datenfluss"
> Zwei betroffene Stellen in BacklogView.swift (1123, 1208) — beide identisch. CoachView (819) und ScheduledTaskBlock (66) sind NICHT betroffen, weil dort immer mindestens ein unbedingter Button im menuItems steht.

### Investigator "Alle Schreiber"
> Tabelle der `.contextMenu(...preview:)` Aufrufstellen:

| Datei:Zeile | menuItems-Body | Bedingt leer? |
|---|---|---|
| BacklogView.swift:1123 | `if item.dueDate != nil { postponeMenu }` | **JA** |
| BacklogView.swift:1208 | `if item.dueDate != nil { postponeMenu }` | **JA** |
| BacklogView.swift:1581 (Erledigt) | Wiederherstellen + Loeschen — immer | nein |
| ScheduledTaskBlock.swift:80 | `Button("Entplanen")` immer | nein |
| NextUpSection.swift:82 | 3 Buttons immer | nein |
| TaskAssignmentView.swift:602 | Button immer (nur disabled) | nein |
| CoachView.swift:822 | min. 3 Buttons immer | nein |

### Investigator "Szenarien"
> **Wahrscheinlichkeit des Bug-Auftretens: sehr hoch.** FocusBlox ist Aufgaben-Manager, nicht Kalender — die Mehrheit aller Backlog-Tasks hat **kein** `dueDate`. Mock-Daten haben `backlogTask2`, `tbdTask`, `staleTask1/2`, `parkedTask` ohne dueDate.
>
> **Tests sind falsch-gruen**, weil `firstElement(withIdentifierPrefix: "taskTitle_")` zufaellig `backlogTask1` trifft — das ist die EINZIGE Task in der Hauptliste, die ein `dueDate = Date()` gesetzt hat (FocusBloxApp.swift:836).

### Investigator "Blast Radius"
> **Wichtige Folge-Erkenntnis:** Wenn man die Bedingung einfach entfernt und `postponeMenu` immer rendert — dann zeigt das Menue 4 Optionen, aber **3 davon sind stille No-Ops** fuer Tasks ohne dueDate:
>
> `LocalTask.postpone(_:byDays:context:)` Zeile 286: `guard let currentDue = task.dueDate else { return nil }` — "Morgen", "Dieses Wochenende", "Naechste Woche" tun nichts. Nur "Eigenes Datum..." funktioniert (setzt dueDate direkt).
>
> **macOS-Pendant:** `FocusBloxMac/ContentView.swift:1079` hat dasselbe `if task.dueDate != nil` Pattern fuer das Verschieben-Menue. macOS hat aber kein `.preview:`-Aequivalent — Preview ist iOS-only. Auf macOS ist nur das Verschieben-Menue betroffen, nicht das Long-Press-Preview.

---

## Spannungen / Entscheidungen

### Spannung: Wie fixen?

Drei Investigatoren schlagen unterschiedliche Fix-Ansaetze vor:

- **A:** Unbedingten Fallback-Button hinzufuegen (z.B. "Bearbeiten") → contextMenu nie leer → Preview erscheint.
- **B:** Bedingung `if dueDate != nil` entfernen, `postponeMenu` immer rendern → 3 stille No-Op-Buttons sichtbar.
- **C:** `postponeMenu` so umbauen, dass es auch fuer Tasks ohne dueDate sinnvolle Optionen liefert (z.B. "Auf heute faellig setzen") → groesserer Scope.

**Meine Empfehlung:** **A — minimal-invasiv.** Das contextMenu fuer Tasks ohne dueDate bekommt einen "Bearbeiten"-Button (oder aehnlich). Damit ist der contextMenu nie leer → Preview erscheint immer. `postponeMenu` bleibt nur bei Tasks mit dueDate (wo es Sinn macht).

C waere die UX-saubere Loesung, aber das ist eine Scope-Erweiterung — eigenes Backlog-Item.
B ist UX-haesslich (3 sichtbare Buttons die nichts tun).

---

## Synthese (fuer Henning)

**Das Problem:**
> Wenn ein Task kein Faelligkeitsdatum hat, zeigt Long-Press auf den Titel keine Preview-Karte.

**Die Ursache:**
> Das technische Konstrukt, das Long-Press zur Preview macht, wird nur aktiviert wenn auch mindestens ein Menue-Eintrag dahinterliegt. Im Backlog haengt der einzige Menue-Eintrag ("Verschieben") an einer Bedingung — bei Tasks ohne Datum ist das Menue leer und Long-Press wird komplett deaktiviert.

**Was betroffen ist:**
> - Backlog Hauptliste (Tasks ohne Faelligkeit)
> - Backlog "Heute"-Sektion (Tasks ohne Faelligkeit)
> - **NICHT betroffen:** Erledigt-Liste, Coach-Tab, Tagesplan-Block

**Mein Vorschlag:**
> Im Backlog-contextMenu einen unbedingten Button hinzufuegen ("Bearbeiten"), damit der Long-Press immer aktiv ist und die Preview-Karte fuer ALLE Tasks erscheint. Das "Verschieben"-Menue bleibt nur bei Tasks mit Faelligkeit (so wie heute).

**Tests:**
> Existierende Tests waren falsch-gruen — sie haben zufaellig immer eine Task mit Datum getroffen. Neue Tests muessen explizit eine Task OHNE Faelligkeit pruefen.
