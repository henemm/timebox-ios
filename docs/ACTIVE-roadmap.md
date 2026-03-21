# ACTIVE Roadmap

> Zentraler Einstiegspunkt fuer alle geplanten Features.
> Features werden hier zuerst eingetragen, bevor eine OpenSpec erstellt wird.
>
> **Rework-Specs:** `docs/specs/rework/` | **Epic Overview:** `docs/specs/rework/0.0-epic-overview.md`

---

## Rework: FocusBlox Neuausrichtung

Reihenfolge: Epic 0 → 1 → 3 → 2 → 4 (siehe [Epic Overview](specs/rework/0.0-epic-overview.md))

### Epic 0: Infrastruktur

| Story | Titel | Status | Aufwand | Spec |
|-------|-------|--------|---------|------|
| 0.1 | Smart Notification Engine | Backlog | M | [Spec](specs/rework/0.1-smart-notification-engine.md) |
| 0.2 | BehavioralProfileService | Backlog | M | [Spec](specs/rework/0.2-behavioral-profile-service.md) |

### Epic 1: Reibungslose Erfassung & Smarte Veredelung

| Story | Titel | Status | Aufwand | Spec |
|-------|-------|--------|---------|------|
| 1.1 | Quick Dump | Backlog | M | [Spec](specs/rework/1.1-quick-dump.md) |
| 1.2 | AI Context Extraction | Backlog | L | [Spec](specs/rework/1.2-ai-context-extraction.md) |
| 1.3 | The Refiner | Backlog | L | [Spec](specs/rework/1.3-the-refiner.md) |

### Epic 3: Fokussierte Ausfuehrung

| Story | Titel | Status | Aufwand | Spec |
|-------|-------|--------|---------|------|
| 3.1 | Task direkt auf Kalender droppen | Backlog | L | [Spec](specs/rework/3.1-calendar-task-drop.md) |
| 3.2 | Focus Sprint ("Los"-Button) | Backlog | M | [Spec](specs/rework/3.2-focus-sprint.md) |
| 3.3 | Follow-up Logic | Backlog | S | [Spec](specs/rework/3.3-follow-up-logic.md) |
| 3.4 | Emotional Nudge (Micro-Tasks) | Backlog | M | [Spec](specs/rework/3.4-emotional-nudge.md) |

### Epic 2: Adaptive Tagesplanung

| Story | Titel | Status | Aufwand | Spec |
|-------|-------|--------|---------|------|
| 2.1 | Tagesansicht ("Dein Tag") | Backlog | XL | [Spec](specs/rework/2.1-day-view.md) |
| 2.2 | KI-gestuetzte Tagesvorschlaege | Backlog | L | [Spec](specs/rework/2.2-next-up-suggestions.md) |
| 2.3 | Limitation Guard | Backlog | S | [Spec](specs/rework/2.3-limitation-guard.md) |
| 2.4 | Backlog UX Rework | Backlog | L | [Spec](specs/rework/2.4-backlog-ux-rework.md) |

### Epic 4: Tagesabschluss & Reflexion

| Story | Titel | Status | Aufwand | Spec |
|-------|-------|--------|---------|------|
| 4.1 | Soft Evening Reset | Backlog | M | [Spec](specs/rework/4.1-soft-evening-reset.md) |
| 4.2 | Success Story Generator | Backlog | L | [Spec](specs/rework/4.2-success-story-generator.md) |
| 4.3 | Failure Protocol | Backlog | M | [Spec](specs/rework/4.3-failure-protocol.md) |
| 4.4 | Morning Widget | Backlog | M | [Spec](specs/rework/4.4-morning-widget.md) |

---

## Legacy Backlog (vor Rework)

> Die folgenden Items stammen aus der Zeit vor dem Rework.
> Sie werden nach Abschluss des Reworks bewertet — einige werden obsolet,
> andere koennen in Rework-Stories aufgehen.

### Sub-Tasks

**Status:** Geplant
**Prioritaet:** Mittel
**Kategorie:** Primary Feature
**Aufwand:** Gross (2 Phasen)

**Kurzbeschreibung:**
Tasks koennen Sub-Tasks bekommen. Parent-Tasks werden durch Sub-Tasks hoeher gerankt. Sub-Tasks erscheinen eingerueckt unterhalb des uebergeordneten Tasks im Backlog.

**Offene Fragen:**
- Wie erstellt der User einen Sub-Task? (Swipe-Action / Long-Press / Bearbeitungs-Dialog)
- Maximale Tiefe: 1 Ebene oder mehr?
- Was passiert wenn Parent erledigt wird?
- Was passiert wenn Sub-Task zu Next Up hinzugefuegt wird?

---
