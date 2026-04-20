---
entity_id: sprint-wording-batch1
type: bugfix
created: 2026-04-20
status: draft
version: "1.0"
tags: [wording, terminology, ux]
---

# Sprint → FocusBlox Wording (Batch 1/3, Bug #224)

## Approval

- [ ] Approved

## Purpose

"Sprint" ist Scrum-Jargon den normale User nicht verstehen. Alle User-sichtbaren Vorkommen werden durch "FocusBlox" ersetzt.

## Replacements (Batch 1)

| Datei | Vorher | Nachher |
|-------|--------|---------|
| FocusLiveView.swift:515 | "Sprint beendet" | "FocusBlox beendet" |
| FocusLiveView.swift:520 | "starte Sprint Review" | "starte FocusBlox Review" |
| FocusLiveView.swift:529 | "Sprint Review starten" | "FocusBlox Review starten" |
| DailyReviewView.swift:566 | "Ohne Sprint erledigt" | "Ohne FocusBlox erledigt" |
| DailyReviewView.swift:569 | (count label, kein Sprint-Text) | — |
| DailyReviewView.swift:595 | "Ohne Sprint erledigt" | "Ohne FocusBlox erledigt" |
| SprintReviewSheet.swift:81 | "Sprint Review" | "FocusBlox Review" |
| SprintReviewSheet.swift:313 | "Sprint Review beenden" | "FocusBlox Review beenden" |
| SprintPickerSheet.swift:26 | "Sprint starten" | "FocusBlox starten" |
| SprintPickerSheet.swift:32 | "Sprint läuft bereits" | "FocusBlox läuft bereits" |
| CoachView.swift:792 | "Focus Sprint" | "FocusBlox" |
| CoachView.swift:976 | "Focus Sprint blockiert" | "FocusBlox blockiert" |
| CoachView.swift:979 | "Focus Sprint konnte nicht gestartet werden." | "FocusBlox konnte nicht gestartet werden." |

## Acceptance Criteria

1. Kein User-sichtbarer "Sprint"-String mehr in den 5 betroffenen Dateien
2. Build erfolgreich (iOS + macOS)
3. Keine Logik-Änderungen — NUR Strings

## Known Limitations

- Variablennamen (focusSprint...) bleiben unverändert (kein Refactoring)
- Batch 2+3 folgen separat
