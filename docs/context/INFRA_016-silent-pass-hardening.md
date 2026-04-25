# Context: INFRA_016 — Silent-Pass-Hardening

## Auslöser

Bug #287 (macOS MenuBar Checkbox-Swap). Der Workflow `bug-mac-checkbox-swap` durchlief alle Phasen — TDD RED, Implementation, Adversary VERIFIED, 2/2 UI-Tests GREEN — ohne dass irgendein Agent bemerkte: **der UI-Test berührte den Bug nie.**

Konkretes Pattern im Test:

```swift
guard let popover = ... else { return }
// Assertions hier
```

Wenn das MenuBar-Popover nicht erscheint (was der eigentliche Bug ist), beendet der Test sich still mit Status PASSED. Der Test bewies nicht, dass der Bug gefixt wurde — er bewies nur, dass der Code kompiliert.

## Symptom-Klasse: "Silent-Pass-Tests"

Tests, die GREEN melden ohne den Code-Pfad zu testen, der den Bug enthält. Drei typische Patterns:

1. **Early Return bei fehlender Voraussetzung:** `guard let x = ... else { return }`
2. **Implizites Skip:** `if let x = ... { /* assertions */ }` ohne `else { XCTFail(...) }`
3. **Optional-Chaining ohne Failure:** `view?.button?.tap()` — wenn `view` nil ist, passiert nichts und der Test "besteht"

Der gemeinsame Nenner: der Test misst etwas, aber wenn das Etwas gar nicht existiert, ist das Ergebnis "PASSED" statt "FAILED".

## Warum der bestehende Workflow das nicht fängt

Aus der Bestandsaufnahme:

- **`edit_gate.py`** prüft Phase und Datei-Pfad — kennt aber keinen Test-Inhalt. Ein Silent-Pass-Test ist syntaktisch ein gültiger Test.
- **`qa_gate.py`** existiert und validiert XCTest-Output — ist aber **nicht als Hook registriert**, läuft nur als Utility, wird vom Orchestrator ad-hoc aufgerufen oder gar nicht.
- **`post_bash.py`** warnt bei Phase-Mismatch (Tests passen in RED-Phase), blockiert aber nicht.
- **`adversary.md`** verlangt vom Adversary "Code-Beleg für jedes Finding" — verlangt aber nicht, dass der Adversary beweist, dass die Tests den Bug erkennen würden.
- **`qa-writer.md`** verbietet Tautologien und `sleep(N)` — kennt das Silent-Pass-Pattern nicht.

## Was als gegeben angenommen wird

- Workflow-Schema v6 (`phase1_context` ... `phase7_done`, `checkpoint1/2/3`)
- Hook-Infrastruktur stabil (settings.json, edit_gate, bash_gate, post_bash, phase_listener)
- Adversary läuft bewusst NICHT im Worktree (Test in `test_finding_resolution.py` enforced) — sieht uncommitted Files, kann also `git stash`/`git stash pop` durchführen
- Override-Token-Mechanik (`__infra__`-Token) für Edits an `.claude/hooks/` und `.claude/agents/` funktioniert

## Vorhaben (in 2 Sätzen)

Wir bauen einen Hook, der Silent-Pass-Patterns in Test-Dateien beim Schreiben blockiert, aktivieren `qa_gate.py` als echten Hook, und erweitern den Adversary so, dass er beweisen muss: der Test failt gegen den unveränderten Code. Die Agent-Prompts werden ergänzt, damit Developer/QA/Adversary das Anti-Pattern explizit kennen.

## Out of Scope

- Komplette Re-Architektur des Workflow-Systems
- Tools für andere Test-Frameworks als XCTest und Python unittest
- Statische Code-Analyse jenseits der genannten 3 Patterns (kein vollständiger AST-Parser)
- Änderungen an bestehenden Tests im Repo (wir härten nur **zukünftige** Tests)

## Erwartetes Ergebnis (Beweisbar)

1. Eine Test-Datei mit `guard let ... else { return }` kann **nicht mehr geschrieben** werden — `edit_gate` blockiert.
2. `mark-red` / `mark-green` schlagen fehl, wenn der Bash-Output keinen echten XCTest-Output enthält.
3. Adversary-Skill enthält eine **Pflicht-Phase** "Pre-Fix-Test-Validation" mit konkreten Bash-Schritten.
4. Bug #287 als Test-Replay würde der neue Hook + Adversary-Mechanik fangen.
