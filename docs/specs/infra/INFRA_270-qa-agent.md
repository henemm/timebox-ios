---
entity_id: INFRA_270-qa-agent
type: module
created: 2026-04-17
updated: 2026-04-17
status: draft
version: "1.0"
tags: [agents, qa, tdd]
---

# INFRA_270 — QA-Agent als eigene Rolle

## Approval

- [ ] Approved

## Purpose

QA schreibt Tests unabhängig basierend NUR auf der Spec — ohne zu wissen wie implementiert wird. Der Orchestrator dispatcht den QA-Agent in Phase 4 statt selbst Tests zu schreiben.

## Neuer Agent: `.claude/agents/qa-writer.md`

### Identität
- **Rolle:** QA-Ingenieur der Verhalten testet, nicht Implementation
- **Model:** sonnet (braucht Code-Verständnis für Swift-Syntax)
- **Tools:** Read, Grep, Glob, Bash (nur sim.sh zum Ausführen)

### Input (was der Agent BEKOMMT)
- Spec-Datei (Pfad)
- User-Erwartung aus Phase 2 (Text)
- Projekt-Konventionen: Test-Verzeichnisse, sim.sh Nutzung, AccessibilityIdentifier-Patterns
- inspect-ui Output (falls vorhanden)

### Input (was der Agent NICHT bekommt)
- Source-Code der zu testenden Features
- Architektur-Entscheidungen
- Implementation-Details
- Wie der Developer plant es umzusetzen

### Output
- Unit-Test-Datei(en) in `FocusBloxTests/`
- UI-Test-Datei(en) in `FocusBloxUITests/`
- Alle Tests MÜSSEN FEHLSCHLAGEN (RED)
- Zusammenfassung: Was jeder Test prüft (in User-Sprache)

### Qualitätsregeln
- Tests prüfen VERHALTEN, nicht Implementation
- Jeder Test hat einen Kommentar: Was bricht wenn welche Zeile sich ändert
- Keine Tautologien, keine Property-Assignment-Tests
- Bei Business-Logik: Unit Tests PFLICHT
- Bei UI: UI Tests PFLICHT, AccessibilityIdentifier aus /inspect-ui

## Anpassung: `04-tdd-red.md`

Statt eigene Test-Anweisungen → QA-Agent dispatchen:

```
### 2. QA-Agent dispatchen

Spawne den QA-Agent mit Spec + User-Erwartung:

Agent(subagent_type: "qa-writer", model: "sonnet")

Prompt:
> Du bist QA. Schreibe Tests die beweisen dass das Feature/der Fix funktioniert.
>
> Spec: [spec_file Pfad]
> User-Erwartung: [Zusammenfassung aus Phase 2]
> inspect-ui Output: [falls vorhanden]
>
> Regeln:
> - Tests MÜSSEN FEHLSCHLAGEN (TDD RED)
> - Tests prüfen VERHALTEN, nicht Implementation
> - Du bekommst KEINEN Source-Code — nur die Spec
```

Die Schritte 3-6 (Tests ausführen, RED registrieren, Snapshot) bleiben beim Orchestrator.

## Test Plan

Da dies eine Skill/Agent-Änderung ist (keine Swift-Logik), gibt es keine automatisierten Tests. Validierung durch die nächste Session die /04-tdd-red nutzt.

## Known Limitations

- QA-Agent kann keine Tests schreiben die compile-abhängig sind (z.B. @testable import) ohne Zugang zum Source — er muss sich auf öffentliche Interfaces verlassen
- Bei reinen Infrastruktur-Änderungen (Python Hooks) ist der QA-Agent nicht sinnvoll — dort schreibt der Orchestrator weiterhin selbst
