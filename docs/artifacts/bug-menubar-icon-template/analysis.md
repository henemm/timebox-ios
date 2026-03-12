# Analyse: Menubar-Icon von SF Symbol auf App-Icon umstellen

## Symptom
macOS Menuleisten-Icon zeigt SF Symbol "cube.fill" statt dem eigenen App-Icon.

## Betroffene Stellen

### 1. Idle-Icon Definition (FocusBloxMacApp.swift:35-38)
```swift
private static let idleImage = NSImage(
    systemSymbolName: "cube.fill",
    accessibilityDescription: "FocusBlox"
)
```
**Aenderung:** `NSImage(systemSymbolName:)` ersetzen durch `NSImage(named:)` mit `icon_16x16` aus dem Asset Catalog. Als Template-Image markieren (`isTemplate = true`).

### 2. Blast Radius — "cube.fill" an anderen Stellen
- **MenuBarView.swift:240** — Header-Icon im Popover (dekorativ, NICHT aendern)
- **QuickCapturePanel.swift:137** — Header-Icon im Quick Capture Panel (dekorativ, NICHT aendern)
- **MenuBarIconState.swift:6** — Nur Kommentar
- **Tests** — Nur Kommentar

**Nur Stelle 1 muss geaendert werden.** Die anderen zeigen das cube-Icon als Dekoration in Views — dort ist das SF Symbol richtig (konsistent, skalierbar).

### 3. Icon-Verfuegbarkeit
Das macOS Asset Catalog hat bereits alle Groessen:
- `icon_16x16.png` (16x16pt) — perfekt fuer Menuleiste
- `icon_16x16@2x.png` (32x32px @2x)

### 4. Template-Image Verhalten
Mit `isTemplate = true` wird das Bild von macOS automatisch:
- Im Dunkelmodus weiss dargestellt
- Im Hellmodus schwarz/dunkelgrau dargestellt
- Bei Selektion invertiert
- Das Farb-Icon wird zur Silhouette

## Fix

1 Datei, ~3 Zeilen aendern:
- `FocusBloxMacApp.swift:35-38`: `idleImage` von SF Symbol auf Asset-Bild umstellen + `isTemplate = true`

## Risiko
Minimal. Nur die visuelle Darstellung des Idle-Icons aendert sich. Kein Einfluss auf Timer, State-Machine oder andere Logik.
