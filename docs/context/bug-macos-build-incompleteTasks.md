# Context: macOS Build Fehler — incompleteTasks

## Request Summary
macOS Scheme (FocusBloxMac) kompiliert nicht: `Cannot find 'incompleteTasks' in scope` in ContentView.swift:849. Variable heißt `tasks` (Zeile 43).

## Related Files
| File | Relevance |
|------|-----------|
| FocusBloxMac/ContentView.swift | Enthält den Build-Fehler auf Zeile 849 |

## Root Cause
Beim Refactoring wurde `incompleteTasks` in `tasks` umbenannt, aber eine Stelle im Context-Menü (Zeile 849) wurde übersehen.

## Fix
`incompleteTasks` → `tasks` auf Zeile 849.
