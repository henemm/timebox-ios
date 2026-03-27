# CLAUDE.md

## Platform & SDK

**Deployment Target:** iOS 26.2 / iPadOS 26.2 / watchOS 26.2 / macOS 26.2 | **Xcode:** 26.2

Apple Versionsnummern seit WWDC 2025: Version = Folgejahr (2025 → 26.x, 2026 → 27.x).

## Design-Leitbild

Minimalistisch, wenige Farben, iOS-nativ ohne Custom-Widgets. Moeglichst nah am aktuellen Design-Paradigma von Apple (Liquid Glass).

## Cross-Platform Code-Sharing (iOS + macOS)

**Prinzip: Maximales Code-Sharing, minimale Plattform-Duplikation.**

Alles was sinnvoll fuer beide Plattformen funktioniert, wird EINMAL in `Sources/` entwickelt — nicht separat pro Plattform kopiert.

- `Sources/` = Shared Code (Models, Services, Business-Logik, **und plattformuebergreifende Views**) → beide Plattformen
- `FocusBloxMac/` = **NUR** was auf macOS tatsaechlich anders aussehen/funktionieren MUSS (Sidebar-Navigation, Window-Management, macOS-spezifische UI-Patterns)
- Neue Business-Logik **immer** in `Sources/` — keine Duplikation in `FocusBloxMac/`

**Entscheidungsregel bei jedem Feature/Bug:**

1. **Kann die View shared werden?** → `Sources/Views/` mit `#if os()` nur wo noetig
2. **Braucht macOS ein anderes Layout?** → Shared ViewModel in `Sources/`, nur View in `FocusBloxMac/`
3. **Ist es rein plattformspezifisch?** (z.B. Sidebar, NSWindow) → `FocusBloxMac/`

**Pflicht-Check vor jedem Commit:**
- Gibt es Code-Duplikation zwischen `Sources/Views/` und `FocusBloxMac/`?
- Kann bestehender plattformspezifischer Code nach `Sources/` verschoben werden?
- Wenn ein iOS-Feature kein macOS-Pendant hat: Backlog-Eintrag erstellen

## Workflow

This project uses the **OpenSpec TDD Workflow**:

| Phase | Command | Purpose |
|-------|---------|---------|
| 0 | `/00-reset` | Reset workflow to idle |
| 1 | `/01-context` | Context generation |
| 2 | `/02-analyse` | Deep analysis of request |
| 3 | `/03-write-spec` | Create specification |
| 4 | User: "approved" | Spec approval |
| 5 | `/04-tdd-red` | Write failing tests (TDD RED) |
| 6 | `/05-implement` | Implement to make tests pass (TDD GREEN) |
| 7 | `/06-validate` | Validate before commit |

Hooks enforce phase progression. Edit/Write on protected files is blocked without active workflow + TDD RED artifacts.

For bug fixes: `/10-bug <description>` triggers Analysis-First → Spec → TDD RED → Implement → Validate.

## TDD & Testing Rules

- UI tests are **mandatory** for every feature/bug — written BEFORE implementation (TDD RED)
- Tests must FAIL first, then PASS after implementation — no retroactive tests
- **Never ask for manual testing** — fix the code until tests are green
- `tdd_enforcement.py` hook verifies real test artifacts with timestamps

**Build & Test Tool: `./scripts/sim.sh`**

**IMMER dieses Script benutzen** — NIEMALS `xcrun`/`xcodebuild` manuell zusammenbauen!

```bash
./scripts/sim.sh build              # App bauen
./scripts/sim.sh test TestClass     # UI Test ausfuehren
./scripts/sim.sh unit TestClass     # Unit Test ausfuehren
./scripts/sim.sh screenshot [pfad]  # Screenshot vom Simulator
./scripts/sim.sh mac-build          # macOS App bauen
./scripts/sim.sh mac-unit TestClass # macOS Unit Test
```

Bei Shared-Code-Aenderungen (`Sources/`): AUCH `mac-build` ausfuehren!

## UI Test Konventionen

**Pre-Flight (PFLICHT vor JEDEM UI Test):**
1. View-Datei lesen → alle `.accessibilityIdentifier()` notieren
2. `/inspect-ui` ausfuehren fuer den Ziel-Screen
3. Identifier-Mapping erstellen: Element → Actual ID → Type
4. Erst DANN Test schreiben — NIEMALS IDs raten oder aus Gedaechtnis

**AccessibilityIdentifier-Muster:**
- Buttons: `camelCase` + `Button` (z.B. `addTaskButton`, `saveButton`)
- Toggles: `camelCase` + `Toggle` (z.B. `remindersSyncToggle`)
- Dynamische Rows: `prefix_<uuid>` (z.B. `taskTitle_<id>`)
- Container mit ID: MUSS `.accessibilityElement(children: .contain)` haben
- Listen-Items: IMMER dynamische ID mit UUID, NIE statisch

**Tab Navigation:** `app.tabBars.buttons["Backlog"]` (Label-basiert, NICHT `app.buttons["backlogTab"]`)

**Verboten:** `sleep(N)` — stattdessen `waitForExistence(timeout:)`

## Xcode-Projekt: Dateien hinzufuegen

**NIEMALS `project.pbxproj` direkt editieren** — das Dateiformat ist fragil und manuelle Edits korrumpieren das Projekt.

**Neue `.swift`-Dateien zum Projekt hinzufuegen:**
```python
python3 -c "
from pbxproj import XcodeProject
proj = XcodeProject.load('FocusBlox.xcodeproj/project.pbxproj')
proj.add_file('Sources/Pfad/NeueDatei.swift', target_name='FocusBlox')
proj.save()
"
```

Target-Namen: `FocusBlox` (iOS App), `FocusBloxTests` (Unit Tests), `FocusBloxUITests` (UI Tests), `FocusBloxMac` (macOS App)

## Specs & Documentation

- Specs: `docs/specs/[category]/[entity].md` (Template: `docs/specs/_template.md`)
- Features: `docs/features/`
- Reference: `docs/reference/` (inkl. `learnings.md`)
- **Backlog & Roadmap:** `docs/ACTIVE-todos.md` ← **SINGLE SOURCE OF TRUTH**
- User Story: `docs/project/stories/timebox-core.md`
