---
entity_id: INFRA_004
type: infrastructure
created: 2026-03-31
updated: 2026-03-31
status: draft
version: "1.0"
tags: [github, ci, issues, hooks, workflow, infrastructure]
---

# INFRA_004: GitHub-Standards Integration

## Approval

- [ ] Approved

## Purpose

Migriert ~40% des Custom-Toolings auf GitHub-native Features (Actions CI, Issue Templates, Labels, Branch Protection, PR-Template). Ersetzt ACTIVE-todos.md als Tracking-System durch GitHub Issues und passt den `bash_gate.py`-Hook an, um Issue-Verlinkung statt Datei-Staging zu pruefen.

## Source

### Erstellen (6 Dateien)

| Datei | Beschreibung |
|-------|-------------|
| `.github/workflows/ci.yml` | GitHub Actions CI: iOS + macOS Build + Unit Tests bei Push/PR |
| `.github/ISSUE_TEMPLATE/bug-report.yml` | YAML Form fuer Bug-Reports |
| `.github/ISSUE_TEMPLATE/feature-request.yml` | YAML Form fuer Feature-Requests |
| `.github/ISSUE_TEMPLATE/config.yml` | Issue Template Konfiguration (Blank Issues deaktivieren) |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR-Template mit Summary, Test Plan, Checklist |
| `.github/CODEOWNERS` | `henemm` als Owner fuer alle Dateien |

### Aendern (5 Dateien)

| Datei | Aenderung |
|-------|-----------|
| `.claude/hooks/bash_gate.py` | Zeilen 259–276: Pruefung von "ACTIVE-todos.md staged?" → "Issue verlinkt im Commit?" |
| `.claude/commands/06-validate.md` | ACTIVE-todos Update → `gh issue close` |
| `.claude/commands/10-bug.md` | Backlog-Referenzen → `gh issue create / gh issue list` |
| `CLAUDE.md` | Single Source of Truth: ACTIVE-todos.md → GitHub Issues |
| `docs/ACTIVE-todos.md` | Wird zum Archiv-Dokument degradiert (kein aktives Tracking mehr) |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `gh` CLI | external tool | Erstellt Issues, schliesst Issues, setzt Labels via GitHub API |
| GitHub API | external service | Branch Protection, Labels, Status Checks |
| `bash_gate.py` | hook | Commit-Gate: prueft Issue-Verlinkung fuer fix:/feat: Commits |
| `workflow.py` | hook | Orchestriert Phasen — nicht direkt betroffen, aber abhaengig von bash_gate |
| `CLAUDE.md` | config | Referenziert neu GitHub Issues als Single Source of Truth |
| `docs/ACTIVE-todos.md` | document | Wird von aktivem Tracking zu Archiv-Dokument |

## Implementation Details

### Phase 2 — Rein additiv (kein Breaking Change)

```
1. .github/workflows/ci.yml erstellen
   - Trigger: push auf main, pull_request
   - Jobs: iOS build + unit tests (xcodebuild), macOS build + unit tests
   - KEINE UI Tests (zu langsam/fehleranfaellig auf GitHub Actions)
   - Secrets: Xcode-Version via matrix oder fest auf 16.x

2. .github/PULL_REQUEST_TEMPLATE.md erstellen
   - Sections: ## Summary, ## Test Plan, ## Checklist
   - Checklist: [ ] Tests gruen, [ ] Build erfolgreich, [ ] Issue verlinkt

3. .github/CODEOWNERS erstellen
   - Inhalt: * @henemm

4. Branch Protection via gh api
   - Required Status Checks: ci-ios, ci-macos
   - KEINE Required Reviews (Solo-Developer)
   - Gilt fuer main branch
```

### Phase 1 — Breaking Change: Issue-basiertes Tracking

```
1. Labels einrichten via gh label create
   Typen:   type:bug, type:feature, type:infra, type:rework
   Prio:    priority:critical, priority:high, priority:medium, priority:low
   Size:    size:XS, size:S, size:M, size:L, size:XL
   Plattform: platform:ios, platform:macos, platform:both

2. Issue Templates erstellen
   .github/ISSUE_TEMPLATE/bug-report.yml   — YAML Form
   .github/ISSUE_TEMPLATE/feature-request.yml — YAML Form
   .github/ISSUE_TEMPLATE/config.yml       — Blank Issues deaktivieren

3. Migration: ~13 offene Items aus ACTIVE-todos.md als GitHub Issues anlegen
   - Via gh issue create mit passenden Labels
   - Workflow-IDs (BUG-xxx, FEATURE-xxx) als Issues erhalten ihre GitHub-Issue-Nummer

4. bash_gate.py anpassen (Zeilen 259–276)
   VORHER: prueft ob ACTIVE-todos.md gestaged ist
   NACHHER: prueft ob Commit-Message eine Issue-Referenz enthaelt (z.B. "closes #42", "#42")
   SCOPE: Nur fix: und feat: Commits — docs:/chore:/refactor:/test: sind ausgenommen
   Pattern: r'#\d+' oder r'closes\s+#\d+' in der Commit-Message

5. CLAUDE.md aktualisieren
   - "Single Source of Truth" → GitHub Issues statt ACTIVE-todos.md
   - 10-bug und 06-validate Referenzen anpassen

6. ACTIVE-todos.md → Archiv-Dokument
   - Header-Kommentar: "ARCHIVIERT — Aktives Tracking via GitHub Issues"
   - Inhalt bleibt als historische Referenz
```

### Phase 3 — Abhaengig von Phase 1

```
1. .claude/commands/10-bug.md anpassen
   VORHER: Backlog-Eintrag in ACTIVE-todos.md anlegen
   NACHHER: gh issue create --label type:bug --label priority:medium ...

2. .claude/commands/06-validate.md anpassen
   VORHER: ACTIVE-todos.md aktualisieren (Bug-Status setzen)
   NACHHER: gh issue close <number> --comment "Geloest in <commit>"
```

### GitHub-Repo

- **Repo:** `henemm/timebox-ios` (public, main branch)
- **gh CLI:** authentifiziert, verfuegbar
- **Projects V2 Board:** manuell durch Henning in Web-UI (kein CLI-Aufwand im Scope)

## Expected Behavior

- **Input:** Push/PR auf main → CI laeuft automatisch, Status Checks werden gesetzt
- **Input:** `fix:` oder `feat:` Commit ohne `#<number>` → bash_gate.py blockiert Commit
- **Input:** `docs:`, `chore:`, `refactor:`, `test:` Commit → bash_gate.py erlaubt ohne Issue-Referenz
- **Output:** GitHub Issues als einzige Quelle fuer offene Bugs/Features
- **Output:** ACTIVE-todos.md ist read-only Archiv
- **Side effects:** Branch Protection auf main wird aktiv — Pushes ohne gruene CI-Checks werden geblockt

## Known Limitations

- UI Tests laufen NICHT in GitHub Actions (zu langsam, Simulator-Setup zu fehleranfaellig)
- Projects V2 Board wird nicht automatisiert — manueller Setup durch Henning
- Issue-Verlinkungspflicht gilt nur fuer `fix:` und `feat:` — alle anderen Commit-Typen sind ausgenommen
- Migration der ~13 offenen Items aus ACTIVE-todos.md erfordert manuelles Labeln und Priorisieren
- Branch Protection blockiert direkte Pushes auf main sobald CI konfiguriert ist — erfordert dass CI-Jobs erfolgreich laufen koennen

## Changelog

- 2026-03-31: Initial spec created
