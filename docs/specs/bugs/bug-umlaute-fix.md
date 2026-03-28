# BUG: Falsche Umlaute im gesamten Projekt

## Problem
Deutsche Texte verwenden systematisch "ae/oe/ue" statt echte Umlaute (ä/ö/ü/ß).
Betrifft user-facing Strings (Notifications, Siri Intents, Accessibility Labels) und Code-Kommentare.

## Root Cause
Die CLAUDE.md und Memory-Dateien des Projekts waren selbst ohne Umlaute geschrieben.
Claude hat den Schreibstil übernommen und in allen generierten Texten reproduziert.

## Fix
1. **CLAUDE.md** — Umlaute korrigiert (Root Cause beseitigt)
2. **Memory-Dateien** — Alle 8 Dateien korrigiert (Root Cause beseitigt)
3. **User-facing Strings** — SmartNotificationEngine, QuickCaptureSubIntents, EventKitRepository, AccessibilityLabels
4. **Code-Kommentare** — In Sources/ und FocusBloxMac/ die häufigsten Patterns korrigiert
5. **Neues Feedback-Memory** — `feedback_umlaute.md` verhindert Wiederholung

## Betroffene Dateien
- CLAUDE.md
- Sources/Services/SmartNotificationEngine.swift
- Sources/Intents/QuickCaptureSubIntents.swift
- Sources/Services/EventKitRepository.swift
- Sources/Views/BlockPlanningView.swift
- FocusBloxMac/MacTimelineView.swift
- Sources/Services/TaskTitleEngine.swift
- Sources/Services/SmartTaskEnrichmentService.swift
- + Kommentare in ~10 weiteren Dateien
