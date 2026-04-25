# CLAUDE.md

## Platform & SDK

**Deployment Target:** iOS 26.2 / iPadOS 26.2 / watchOS 26.2 / macOS 26.2 | **Xcode:** 26.2

Apple Versionsnummern seit WWDC 2025: Version = Folgejahr (2025 → 26.x, 2026 → 27.x).

## Design-Leitbild

Minimalistisch, wenige Farben, iOS-nativ ohne Custom-Widgets. Möglichst nah am aktuellen Design-Paradigma von Apple (Liquid Glass).

## Cross-Platform Code-Sharing (iOS + macOS)

**Prinzip: Maximales Code-Sharing, minimale Plattform-Duplikation.**

Alles was sinnvoll für beide Plattformen funktioniert, wird EINMAL in `Sources/` entwickelt — nicht separat pro Plattform kopiert.

- `Sources/` = Shared Code (Models, Services, Business-Logik, **und plattformübergreifende Views**) → beide Plattformen
- `FocusBloxMac/` = **NUR** was auf macOS tatsächlich anders aussehen/funktionieren MUSS (Sidebar-Navigation, Window-Management, macOS-spezifische UI-Patterns)
- Neue Business-Logik **immer** in `Sources/` — keine Duplikation in `FocusBloxMac/`

**Entscheidungsregel bei jedem Feature/Bug:**

1. **Kann die View shared werden?** → `Sources/Views/` mit `#if os()` nur wo nötig
2. **Braucht macOS ein anderes Layout?** → Shared ViewModel in `Sources/`, nur View in `FocusBloxMac/`
3. **Ist es rein plattformspezifisch?** (z.B. Sidebar, NSWindow) → `FocusBloxMac/`

**Pflicht-Check vor jedem Commit:**
- Gibt es Code-Duplikation zwischen `Sources/Views/` und `FocusBloxMac/`?
- Kann bestehender plattformspezifischer Code nach `Sources/` verschoben werden?
- Wenn ein iOS-Feature kein macOS-Pendant hat: Backlog-Eintrag erstellen

**macOS Cross-View Refresh — `taskDataChanged` Notification:**
Wenn eine macOS-View Task-Daten ändert (`modelContext.save()`), MUSS sie danach
`NotificationCenter.default.post(name: .taskDataChanged, object: nil)` aufrufen,
damit `ContentView.refreshTasks()` getriggert wird. Neue macOS-Views mit Mutations
immer nach diesem Pattern implementieren. Details: `docs/reference/learnings.md`

## Workflow — Orchestrator-Pattern (v6)

| Phase | Command | Gate to leave |
|-------|---------|---------------|
| 0 | `/00-reset` | Reset |
| 1 | `/01-context` | context_file exists |
| 2 | `/02-analyse` | **Checkpoint 1** — Henning sagt "stimmt" |
| 3 | `/03-write-spec` | spec_file + Henning sagt "approved" |
| 4 | `/04-tdd-red` | RED artifacts + **Checkpoint 2** — Henning sagt "go" |
| 5 | `/05-implement` | Developer-Agent in Worktree, Tests GREEN |
| 6 | Adversary | Implementation-Validator prüft, **Checkpoint 3** — Henning sagt "commit" |
| 7 | Done | git commit erlaubt |

**Orchestrator-Pattern:** Haupttask schreibt KEINEN Code. Developer-Agent (Opus) arbeitet in Worktree-Isolation. Implementation-Validator (Sonnet) prüft unabhängig.

**3 Human Checkpoints:** Nur Henning kann Checkpoints freischalten (via phase_listener.py). Claude kann sich selbst NICHT freischalten.

**Scope-Guard:** Max 5 Code-Dateien pro Workflow (Hook enforced). Max ±250 LoC.

Hooks enforce phase progression. Edit/Write on code files is blocked without active workflow + TDD RED artifacts.

For bug fixes: `/10-bug <description>` triggers Analysis-First → Checkpoint 1 → Spec → TDD RED → Checkpoint 2 → Developer-Agent → Adversary → Checkpoint 3 → Commit.

For features: `/11-feature <description>` triggers User Advocate + Feature Planner → Checkpoint 1 → Spec → TDD RED → Checkpoint 2 → Developer-Agent → Adversary → Checkpoint 3 → Commit.

## TDD & Testing Rules

- UI tests are **mandatory** for every feature/bug — written BEFORE implementation (TDD RED)
- Tests must FAIL first, then PASS after implementation — no retroactive tests
- **Never ask for manual testing** — fix the code until tests are green
- `edit_gate.py` enforces TDD phases (tests only in phase4, code only in phase5)

### Anti-Pattern: Silent-Pass-Tests

Tests die GREEN melden ohne den Code-Pfad zu testen sind WERTLOS — auch wenn sie kompilieren.

**Verboten in Test-Dateien** (vom `test_quality_gate.py` Hook erzwungen):
- `guard let x = ... else { return }` — verwende `try XCTUnwrap(x)`
- `if let x = ... { ... }` ohne `else { XCTFail(...) }`
- `view?.button?.tap()` in UI-Test-Assertions — wenn `view` nil, passiert nichts und Test "besteht"

**"GREEN" bedeutet:** Bug ist beweisbar gefixt — nicht "Code kompiliert".
Adversary muss beweisen: Test wäre OHNE Fix rot. Sonst ist GREEN bedeutungslos.

**Build & Test Tool: `./scripts/sim.sh`**

**IMMER dieses Script benutzen** — NIEMALS `xcrun`/`xcodebuild` manuell zusammenbauen!

```bash
./scripts/sim.sh build              # App bauen
./scripts/sim.sh test TestClass     # UI Test ausführen
./scripts/sim.sh unit TestClass     # Unit Test ausführen
./scripts/sim.sh screenshot [pfad]  # Screenshot vom Simulator
./scripts/sim.sh mac-build          # macOS App bauen
./scripts/sim.sh mac-unit TestClass # macOS Unit Test
```

Bei Shared-Code-Änderungen (`Sources/`): AUCH `mac-build` ausführen!

## UI Test Konventionen

**Pre-Flight (PFLICHT vor JEDEM UI Test):**
1. View-Datei lesen → alle `.accessibilityIdentifier()` notieren
2. `/inspect-ui` ausführen für den Ziel-Screen
3. Identifier-Mapping erstellen: Element → Actual ID → Type
4. Erst DANN Test schreiben — NIEMALS IDs raten oder aus Gedächtnis

**AccessibilityIdentifier-Muster:**
- Buttons: `camelCase` + `Button` (z.B. `addTaskButton`, `saveButton`)
- Toggles: `camelCase` + `Toggle` (z.B. `remindersSyncToggle`)
- Dynamische Rows: `prefix_<uuid>` (z.B. `taskTitle_<id>`)
- Container mit ID: MUSS `.accessibilityElement(children: .contain)` haben
- Listen-Items: IMMER dynamische ID mit UUID, NIE statisch

**Tab Navigation:** `app.tabBars.buttons["Backlog"]` (Label-basiert, NICHT `app.buttons["backlogTab"]`)

**Verboten:** `sleep(N)` — stattdessen `waitForExistence(timeout:)`

## Xcode-Projekt: Dateien hinzufügen

**NIEMALS `project.pbxproj` direkt editieren** — das Dateiformat ist fragil und manuelle Edits korrumpieren das Projekt.

**Neue `.swift`-Dateien zum Projekt hinzufügen:**
```bash
python3 scripts/add_file_to_project.py Sources/Pfad/NeueDatei.swift
python3 scripts/add_file_to_project.py Sources/A.swift Sources/B.swift --target FocusBloxTests
```

**ACHTUNG:** Python-Einzeiler mit `project.pbxproj` werden vom Bash-Gate blockiert (#186). Immer das whitegelistete Script verwenden!

**WARNUNG (Bug #182):** `python-pbxproj` erzeugt Quoted IDs (`"XXXX"`) statt Hex-IDs. Das kann zu Duplicate-Warnings führen wenn Xcode dieselben Dateien mit Hex-IDs referenziert. Nach jedem `add_file()`-Aufruf: `./scripts/sim.sh build` ausführen und auf "Skipping duplicate build file"-Warnings prüfen!

Target-Namen: `FocusBlox` (iOS App), `FocusBloxTests` (Unit Tests), `FocusBloxUITests` (UI Tests), `FocusBloxMac` (macOS App)

## Specs & Documentation

- Specs: `docs/specs/[category]/[entity].md` (Template: `docs/specs/_template.md`)
- Features: `docs/features/`
- Reference: `docs/reference/` (inkl. `learnings.md`)
- **Backlog & Roadmap:** GitHub Issues (`gh issue list`) ← **SINGLE SOURCE OF TRUTH**
- **Backlog-Archiv:** `docs/ACTIVE-todos.md` (read-only Referenz fuer erledigte Items)
- User Story: `docs/project/stories/timebox-core.md`
