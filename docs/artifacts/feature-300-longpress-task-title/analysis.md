# Analysis: Feature #300 — Long Press auf Task Title

**Hennings Wunsch:** "Long press auf Task Title — Zeigt Karte mit allen Eigenschaften und vollständigen Titel"

## User-Erwartung (User Advocate)

- **Was passiert:** Karte poppt direkt über/unter dem Task auf (kein Screen-Wechsel). Vollständiger Titel + alle Eigenschaften (Dauer, Datum, Priorität, Notizen, etc.). Read-only.
- **Gefühl:** "Schnell nachschauen ohne irgendwo hinnavigieren." Lese-Modus, nicht Arbeits-Modus.
- **Schließen:** Finger weg = Karte weg. Kein X-Button.
- **Read-only:** Kein Edit auf der Karte. Tipp auf Eigenschaft = nichts passiert.
- **Wo:** Überall wo Tasks angezeigt werden — Backlog UND Tagesplan. Wenn nur an einer Stelle = wirkt wie Bug.
- **macOS:** Right-Click. Hover wäre zu subtil.
- **Rückfrage:** Karte sollte nicht halb-leer aussehen wenn viele Felder leer sind.

## Technische Analyse (Feature Planner)

**Wichtige Entdeckung:** `TaskPreviewView` (`Sources/Views/TaskPreviewView.swift`) existiert bereits. Das `.contextMenu(preview:)`-Pattern ist auf 2 Stellen aktiv:

| Stelle | Datei |
|---|---|
| NextUpRow | `Sources/Views/NextUpSection.swift:57` |
| DraggableTaskRow | `Sources/Views/TaskAssignmentView.swift:595` |

**Fehlt** (kein Preview):

| Stelle | Datei | Bemerkung |
|---|---|---|
| BacklogRow (Hauptliste) | `Sources/Views/BacklogView.swift:1112` | Hat `.contextMenu`, aber kein `preview:` |
| BacklogRow (Abgeschlossen) | `Sources/Views/BacklogView.swift:1469` | Hat `.contextMenu`, aber kein `preview:` |
| BacklogRow (CoachView) | `Sources/Views/CoachView.swift:798` | Hat `.contextMenu`, aber kein `preview:` |
| ScheduledTaskBlock (Tagesplan) | `Sources/Views/ScheduledTaskBlock.swift:46` | Bekommt nur `title:String`, nicht das `PlanItem` |
| MacBacklogRow | `FocusBloxMac/ContentView.swift:622` | macOS — Inspector existiert |

**TaskPreviewView zeigt bereits:** Titel, Wichtigkeit, Dringlichkeit, Kategorie, Dauer, Wiederholung, Tags, Fälligkeitsdatum, Beschreibung.

**iOS vs. macOS:** `.contextMenu(preview:)` funktioniert auf beiden, der `preview:`-Block wird auf macOS aber ignoriert (kein Thumbnail). macOS hat bereits Inspector für Details.

## Spannung

**User Advocate** erwartet das Feature **überall** (Backlog + Tagesplan). **Feature Planner** empfiehlt `ScheduledTaskBlock` auszuklammern, weil dort nur `title:String` übergeben wird (Mehraufwand).

**Meine Einschätzung:** User Advocate hat recht — wenn der User im Tagesplan keinen Long Press hat, wirkt es inkonsistent. Aber das erhöht Scope (PlanItem in `ScheduledTaskBlock` reichen + Preview einhängen). Frage an Henning: Ist Tagesplan-Block Teil des MVPs?

**macOS:** Beide sind sich einig — Inspector deckt's ab, kein Handlungsbedarf.

## Scope-Schätzung

| Variante | Dateien | LoC |
|---|---|---|
| **MVP (nur Backlog/Coach)** | 3 (`BacklogView.swift`, `CoachView.swift`, evtl. `TaskPreviewView.swift`) | ~20 |
| **Voll (inkl. Tagesplan)** | +2 (`ScheduledTaskBlock.swift` + Aufrufer) | +30 |

Beide deutlich unter Scope-Limit (4-5 Dateien, ±250 LoC).

## Empfehlung

**Voll-Variante** umsetzen — User-Erwartung "überall" gewichten höher als der kleine Mehraufwand. Pattern ist etabliert (`TaskPreviewView` + `.contextMenu(preview:)`), Risiko gering.
