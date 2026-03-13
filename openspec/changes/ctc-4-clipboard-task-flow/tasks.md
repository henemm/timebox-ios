# CTC-4: Tasks / Implementierungs-Checkliste

> Workflow: TDD — Tests ZUERST schreiben (RED), dann implementieren (GREEN)

---

## Phase 1: TDD RED — Failing Tests schreiben

- [ ] `FocusBloxUITests/ClipboardTaskFlowTests.swift` erstellen
- [ ] Test: Clipboard-Button ist NICHT sichtbar wenn Clipboard leer
- [ ] Test: Clipboard-Button ist sichtbar wenn Clipboard Text enthält (Simulator-Trick: über `initialTitle` simulieren)
- [ ] Test: Tap auf Clipboard-Button füllt Titel-Feld mit Clipboard-Inhalt
- [ ] Test: Clipboard-Button verschwindet nachdem Titel übernommen wurde
- [ ] Tests ausführen → MÜSSEN fehlschlagen (Feature existiert noch nicht)
- [ ] Artifact in `docs/artifacts/` ablegen

## Phase 2: Implementierung

- [ ] `Sources/Views/QuickCaptureView.swift` erweitern:
  - [ ] `@State private var clipboardText: String?` hinzufügen
  - [ ] `clipboardText` bei `.onAppear` aus `UIPasteboard.general.string` (iOS) / `NSPasteboard.general.string(forType: .string)` (macOS) lesen
  - [ ] Clipboard-Button unterhalb des Textfelds einbauen (nur sichtbar wenn `title.isEmpty && clipboardText != nil`)
  - [ ] Button-Action: `title = clipboardText ?? ""` + `clipboardText = nil`
  - [ ] In `saveTask()`: wenn Clipboard-Text verwendet wurde → `needsTitleImprovement = true` beim Task setzen
  - [ ] `#if os(macOS) / #else` Guard für Pasteboard-Zugriff

## Phase 3: Validierung

- [ ] UI Tests ausführen → MÜSSEN grün sein
- [ ] Build: iOS + macOS kompiliert ohne Errors
- [ ] `docs/ACTIVE-todos.md` Status auf ERLEDIGT setzen
- [ ] Commit: `feat: CTC-4 — Clipboard → Task Flow`

---

## Betroffene Dateien

| Datei | Typ | Änderung |
|-------|-----|----------|
| `Sources/Views/QuickCaptureView.swift` | Shared Code (iOS + macOS) | Clipboard-Button + Paste-Logik |
| `FocusBloxUITests/ClipboardTaskFlowTests.swift` | UI Tests | Neu |

---

## Notizen

- `UIPasteboard.general.string` gibt `nil` zurück wenn Clipboard leer oder nicht-Text-Inhalt — kein Crash
- `NSPasteboard.general.string(forType: .string)` analog auf macOS
- `needsTitleImprovement` wird beim Task gesetzt, nicht beim Clipboard-Read — nur wenn tatsächlich gespeichert
- Der bestehende `TaskTitleEngine.improveAllPendingTitles()` Aufruf in `FocusBloxApp.onAppear` verarbeitet den Task automatisch beim nächsten App-Start
