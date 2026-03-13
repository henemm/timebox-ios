# CTC-4: Clipboard → Task Flow

> Erstellt: 2026-03-02
> Status: Geplant
> Bundle: H — Contextual Task Capture

---

## Was und Warum

### Problem

Der Nutzer kopiert Text in einer anderen App (E-Mail-Betreff, Notiz, Website-Snippet) und will daraus schnell eine Task in FocusBlox erstellen. Aktuell muss er:
1. App wechseln
2. Task manuell tippen
3. Dabei den kopierten Text verlieren oder erneut einfügen

Der Clipboard-Inhalt ist der kürzeste Weg von "ich habe etwas gesehen" zu "Task erfasst".

### Lösung

Ein dedizierter "Aus Zwischenablage einfügen" Button in der bestehenden `QuickCaptureView`. Wenn der Nutzer Quick Capture öffnet (iOS: Toolbar-Button im Backlog / macOS: Cmd+Shift+Space), kann er mit einem Tap den Clipboard-Inhalt als Task-Titel übernehmen. `needsTitleImprovement = true` wird gesetzt, die `TaskTitleEngine` verbessert den Titel asynchron im Hintergrund.

### Warum KEIN neues UI-Element

Die `QuickCaptureView` existiert bereits und ist der etablierte Eingangsweg für schnelle Task-Erfassung. Sie unterstützt bereits `initialTitle` (für den CC-Widget-Flow). Es braucht nur einen "Aus Clipboard einfügen"-Button in dieser View — kein neuer Screen, kein neues Sheet.

---

## Umfang (Scope)

**Betroffene Plattformen:** iOS + macOS (QuickCaptureView ist Shared Code in `Sources/`)

**Betroffene Dateien:**

| Datei | Änderung | LoC |
|-------|----------|-----|
| `Sources/Views/QuickCaptureView.swift` | Clipboard-Button + Paste-Logik | +30 |
| `FocusBloxUITests/ClipboardTaskFlowTests.swift` | UI Tests (TDD RED zuerst) | +50 |

**Gesamt: 2 Dateien, ~80 LoC** — deutlich unter dem Limit von 4-5 Dateien / ±250 LoC.

---

## Technische Entscheidungen

### Clipboard-Zugriff

- **iOS:** `UIPasteboard.general.string` — kein Privacy-Permission-Dialog nötig (nur Lesen)
- **macOS:** `NSPasteboard.general.string(forType: .string)` — ebenfalls kein Dialog
- Cross-Platform via `#if os(macOS)` Guard in der View (da `QuickCaptureView` im Shared Code liegt)

### UX-Flow

1. Nutzer öffnet Quick Capture (Toolbar-Button oder Cmd+Shift+Space)
2. Text-Feld ist leer (Standard)
3. Clipboard-Button erscheint unterhalb des Textfelds (nur wenn Clipboard nicht leer UND Textfeld leer)
4. Tap auf Button: Clipboard-Inhalt wird in `title`-State übernommen, Button verschwindet
5. `needsTitleImprovement = true` wird beim Speichern gesetzt (identisch zum Share Extension Flow)
6. `TaskTitleEngine` verbessert den Titel asynchron beim nächsten App-Start

### Sichtbarkeit des Clipboard-Buttons

- Button wird nur angezeigt wenn: `title.isEmpty && clipboardHasContent`
- Evaluiert beim `.onAppear` der View und bei `title`-Änderungen
- Verhindert, dass der Button einen bereits eingetippten Titel überschreibt

### needsTitleImprovement Flag

- Wird auf `true` gesetzt wenn Clipboard-Inhalt übernommen wird (analog Share Extension)
- `TaskTitleEngine.improveAllPendingTitles()` läuft bereits beim App-Start (in `FocusBloxApp.onAppear`)
- Keine neue Infrastruktur nötig — der bestehende Batch-Mechanismus übernimmt die Arbeit

---

## Abgrenzung (Was NICHT in diesem Feature)

- Kein automatisches Erkennen von Clipboard-Änderungen im Hintergrund
- Kein "Clipboard-Watcher" (würde Privacy-Dialog auslösen auf iOS 16+)
- Keine URL-Extraktion aus Clipboard (das ist Share Extension Territory)
- Kein separates "Clipboard-Task"-Icon in der Tab-Bar

---

## Risiken / Seiteneffekte

- **Keiner.** Die `QuickCaptureView` wird nur erweitert, nicht umgebaut.
- `needsTitleImprovement` wird bereits von der bestehenden Share Extension verwendet — gleicher Mechanismus.
- Kein neues Modell-Feld, keine Migration, keine neue Permission.

---

## Erfolgskriterien

- [ ] Clipboard-Button erscheint in QuickCaptureView wenn Clipboard Text enthält und Titel-Feld leer ist
- [ ] Tap auf Button übernimmt Clipboard-Inhalt in Titel-Feld
- [ ] Gespeicherte Task hat `needsTitleImprovement = true`
- [ ] Funktioniert auf iOS UND macOS (gleicher Shared Code)
- [ ] UI Tests grün (TDD)
