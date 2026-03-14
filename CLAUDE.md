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
| 0 | `/reset` | Reset workflow to idle |
| 1 | `/context` | Context generation |
| 2 | `/analyse` | Deep analysis of request |
| 3 | `/write-spec` | Create specification |
| 4 | User: "approved" | Spec approval |
| 5 | `/tdd-red` | Write failing tests (TDD RED) |
| 6 | `/implement` | Implement to make tests pass (TDD GREEN) |
| 7 | `/validate` | Validate before commit |

Hooks enforce phase progression. Edit/Write on protected files is blocked without active workflow + TDD RED artifacts.

For bug fixes: `/bug <description>` triggers Analysis-First → Spec → TDD RED → Implement → Validate.

## TDD & Testing Rules

- UI tests are **mandatory** for every feature/bug — written BEFORE implementation (TDD RED)
- Tests must FAIL first, then PASS after implementation — no retroactive tests
- **Never ask for manual testing** — fix the code until tests are green
- `tdd_enforcement.py` hook verifies real test artifacts with timestamps

**Test Simulator:**
```bash
xcodebuild test -project FocusBlox.xcodeproj -scheme FocusBlox \
  -destination 'id=1EC79950-6704-47D0-BDF8-2C55236B4B40'
```

## Specs & Documentation

- Specs: `docs/specs/[category]/[entity].md` (Template: `docs/specs/_template.md`)
- Features: `docs/features/`
- Reference: `docs/reference/` (inkl. `learnings.md`)
- **Backlog & Roadmap:** `docs/ACTIVE-todos.md` ← **SINGLE SOURCE OF TRUTH**
- User Story: `docs/project/stories/timebox-core.md`
