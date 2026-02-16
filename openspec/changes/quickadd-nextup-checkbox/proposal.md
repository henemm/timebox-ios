# Feature: QuickAdd "Next Up" Checkbox

## Zusammenfassung

Alle 3 Quick-Add-Flows um eine "Next Up"-Option erweitern, damit Tasks direkt beim Erstellen als "Next Up" markiert werden koennen - ohne Umweg ueber den Backlog.

---

## Ist-Zustand

### 3 Quick-Add-Stellen

| Stelle | Datei | Platform | Task-Erstellung |
|--------|-------|----------|-----------------|
| QuickCaptureView (Control Center) | `Sources/Views/QuickCaptureView.swift` | iOS | Via `LocalTaskSource.createTask()` mit Metadaten |
| QuickCapturePanel (Floating Panel) | `FocusBloxMac/QuickCapturePanel.swift` | macOS | Direkt `LocalTask(title:)` - nur Titel |
| MenuBarView (Menu Bar) | `FocusBloxMac/MenuBarView.swift` | macOS | Direkt `LocalTask(title:)` - nur Titel |

**Keine der 3 Stellen setzt `isNextUp` bei Task-Erstellung.**

### LocalTask Default
```swift
var isNextUp: Bool = false  // Sources/Models/LocalTask.swift:54
```

### LocalTaskSource.createTask()
Hat keinen `isNextUp` Parameter. Setzt es nicht.

---

## Soll-Zustand

### 1. iOS QuickCaptureView

Neuer Toggle-Button in der Metadata-Leiste (neben Importance, Urgency, Category, Duration):

```
[!] [⚡] [📁] [⏱] [▲ Next Up]
```

- Icon: `arrow.up.circle` (inaktiv) / `arrow.up.circle.fill` (aktiv)
- Farbe: `.blue` wenn aktiv, `.gray` wenn inaktiv
- Style: Identisch zu den bestehenden Metadata-Buttons (gleiche Hoehe, Material-Background)
- Default: **aus** (wie bisher)

Nach `saveTask()` wird `isNextUp` auf dem erstellten Task gesetzt.

### 2. macOS QuickCapturePanel (Floating Panel)

Kompakter Toggle rechts neben dem Textfeld:

```
[🔷] [Add task...________________] [▲] [↵]
```

- Icon: `arrow.up.circle` / `arrow.up.circle.fill`
- Tooltip: "Next Up"
- Default: **aus**

Nach `addTask()` wird `task.isNextUp = true` gesetzt wenn aktiviert.

### 3. macOS MenuBarView

Toggle im expanded Quick-Add-Bereich:

```
[New Task_______________] [▲] [+] [✕]
```

- Icon: `arrow.up.circle` / `arrow.up.circle.fill`
- Tooltip: "Next Up"
- Default: **aus**

Nach `addTask()` wird `task.isNextUp = true` gesetzt wenn aktiviert.

---

## Technischer Plan

### Dateien (3 Dateien, ~30 LoC netto)

| Datei | Aenderung | LoC |
|-------|-----------|-----|
| `Sources/Views/QuickCaptureView.swift` | `@State isNextUp`, Toggle-Button, `task.isNextUp` nach save | ~12 LoC |
| `FocusBloxMac/QuickCapturePanel.swift` | `@State isNextUp`, Toggle-Button, `task.isNextUp` nach add | ~8 LoC |
| `FocusBloxMac/MenuBarView.swift` | `@State isNextUp`, Toggle-Button, `task.isNextUp` nach add | ~8 LoC |

### Implementierung pro Stelle

**State:**
```swift
@State private var isNextUp = false
```

**UI (macOS - kompakt):**
```swift
Button(action: { isNextUp.toggle() }) {
    Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
        .foregroundStyle(isNextUp ? .blue : .secondary)
}
.buttonStyle(.borderless)
.help("Next Up")
```

**UI (iOS - wie bestehende Metadata-Buttons):**
```swift
Button { isNextUp.toggle() } label: {
    Image(systemName: isNextUp ? "arrow.up.circle.fill" : "arrow.up.circle")
        .font(.title3)
        .foregroundStyle(isNextUp ? .blue : .gray)
        .frame(height: 40)
        .frame(minWidth: 40)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((isNextUp ? Color.blue : Color.gray).opacity(0.2))
        )
}
.buttonStyle(.plain)
```

**Task-Erstellung (nach insert/save):**
```swift
if isNextUp {
    task.isNextUp = true
}
```

### Reset nach Erstellung

`isNextUp` wird nach erfolgreicher Task-Erstellung auf `false` zurueckgesetzt (wie alle anderen Felder).

---

## Abgrenzung (Out of Scope)

- Kein neuer Parameter fuer `LocalTaskSource.createTask()` - wir setzen `isNextUp` direkt nach der Erstellung
- Keine Aenderung am `LocalTask` Model
- Keine Aenderung am `TaskSource` Protocol

---

## Acceptance Criteria

1. iOS QuickCaptureView: Toggle-Button "Next Up" in Metadata-Leiste
2. macOS QuickCapturePanel: Toggle-Button neben Textfeld
3. macOS MenuBarView: Toggle-Button im Quick-Add-Bereich
4. Task mit aktiviertem Toggle wird mit `isNextUp = true` erstellt
5. Task ohne Toggle bleibt `isNextUp = false` (Default, wie bisher)
6. Toggle wird nach Task-Erstellung zurueckgesetzt
