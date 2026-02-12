# Ticket B: macOS Review an iOS angleichen (Feature Parity)

## Problem

macOS Review Tab ist komplett anders als iOS:
- Kein Completion Ring
- Keine FocusBlock-Karten in Tagesansicht
- Kategorie nach Anzahl statt nach Zeit
- Keine Offen/Blocks Stats
- Laedt keine FocusBlocks

## Scope

- macOS: FocusBlocks laden (EventKitRepository)
- Completion Ring einbauen (wie iOS)
- Kategorie nach ZEIT statt Anzahl umstellen
- Block-Karten in Tagesansicht
- Erledigt/Offen/Blocks Stats
- ~3 Dateien, ~200 LoC

## Betroffene Dateien

- `FocusBloxMac/MacReviewView.swift` (Hauptarbeit)
- Evtl. gemeinsame Komponenten extrahieren

## Prioritaet

Mittel - Feature Parity

## Status

Backlog
