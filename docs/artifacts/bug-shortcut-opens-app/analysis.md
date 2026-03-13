# Bug-Analyse: Apple Shortcut oeffnet FocusBlox komplett

## Plattform
**iOS only** — macOS nutzt kein Siri-Intent-Handoff fuer CreateTaskIntent.

## Symptom
Der Apple Shortcut zur Task-Erstellung oeffnete frueher nur kurz einen Textschlitz (inline in Siri/Spotlight) und erledigte alles im Hintergrund. Jetzt wird FocusBlox komplett im Vordergrund geoeffnet.

## Root Cause (bewiesen durch Git-History)

**Commit `382a5a1` (12. Feb 2026)** hat `CreateTaskIntent` bewusst umgebaut:

### VORHER (funktionierte wie gewuenscht):
```swift
static let openAppWhenRun: Bool = false

func perform() -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
    return .result(
        dialog: "Task konfigurieren:",
        snippetIntent: CreateTaskSnippetIntent(taskTitle: taskTitle)
    )
}
```
- Siri zeigte **inline** ein Interactive Snippet (iOS 26 Feature)
- User sah nur kurz Buttons fuer Titel, Wichtigkeit, Dauer etc.
- Task wurde im Hintergrund gespeichert — App blieb zu

### NACHHER (aktueller Zustand — Bug):
```swift
static let openAppWhenRun: Bool = true

func perform() -> some IntentResult & ProvidesDialog {
    defaults.set(true, forKey: "quickCaptureFromCC")
    defaults.set(taskTitle, forKey: "quickCaptureTitle")
    return .result(dialog: "Oeffne FocusBlox...")
}
```
- App wird komplett geoeffnet
- Titel wird ueber UserDefaults an die App uebergeben
- QuickCaptureView wird in der App angezeigt

### Grund fuer die Aenderung:
Commit-Message: *"Interactive Snippet (Dependency-Aufloesung unzuverlaessig)"*
- Die `@Dependency var captureState: QuickCaptureState` im SnippetIntent wurde nicht zuverlaessig aufgeloest
- Workaround: App komplett oeffnen statt Snippet nutzen

## Hypothesen

### H1: openAppWhenRun=true ist die direkte Ursache (HOCH)
- **Beweis DAFUER:** Commit 382a5a1 aendert explizit von false auf true
- **Beweis DAFUER:** Vor dem Commit funktionierte es inline
- **Beweis DAGEGEN:** Keiner — die Aenderung ist eindeutig

### H2: @Dependency-Aufloesung war das eigentliche Problem (MITTEL)
- **Beweis DAFUER:** Commit-Message nennt es als Grund
- **Beweis DAGEGEN:** Unklar ob das Problem noch besteht oder zwischenzeitlich gefixt wurde
- iOS 26.2 koennte das Dependency-Problem geloest haben
- **Offener Punkt:** Es gibt keinen Beweis dass das Problem gefixt wurde — nur Hoffnung

### H3: Der Shortcut selbst hat eine "Open App" Aktion (NIEDRIG)
- **Beweis DAGEGEN:** Das Verhalten aenderte sich mit dem Code-Commit, nicht mit dem Shortcut

## Verwandter Bug: Siri Text-Verlust

**WICHTIG:** Das App-Oeffnen via openAppWhenRun=true hat einen Folge-Bug verursacht:
Diktierter Text ging verloren, weil UserDefaults Cross-Process Race Condition hat
(fehlender `synchronize()` → Extension schreibt, App liest bevor Disk-Sync).

Dieser Bug war eine direkte FOLGE des Workarounds in 382a5a1.
**Ein Fix zurueck zu Interactive Snippets wuerde beide Bugs loesen.**

## Fix-Optionen

### Option A: Zurueck zum Interactive Snippet (empfohlen)
- `openAppWhenRun = false` setzen
- `ShowsSnippetIntent` Return-Type in `CreateTaskIntent.perform()` wiederherstellen
- `CreateTaskSnippetIntent` ist DEAD CODE (wird aktuell nicht aufgerufen) — muss wieder referenziert werden
- **Risiko:** `@Dependency var captureState: QuickCaptureState` war damals unzuverlaessig
- **Unbekannt:** Ob iOS 26.2 das Dependency-Problem geloest hat — muss getestet werden

### Option B: Direkt speichern ohne UI (einfacher + sicherer)
- `openAppWhenRun = false` setzen
- Task direkt in `perform()` via SharedModelContainer speichern (wie SaveQuickCaptureIntent es tut)
- Kein Snippet, kein App-Oeffnen — nur Titel wird gespeichert
- **Nachteil:** Keine Metadaten (Wichtigkeit, Dauer) beim Erstellen via Siri
- **Vorteil:** Kein Dependency-Problem, kein UserDefaults Race Condition

### Option C: Hybrid — Snippet mit Fallback
- Versuche Interactive Snippet (Option A)
- Falls Dependency fehlschlaegt: Speichere direkt (Option B)
- **Komplexer**, aber robust

## Blast Radius
- **CreateTaskIntent** — direkt betroffen
- **QuickAddLaunchIntent** (CC) — hat ebenfalls openAppWhenRun=true, aber das ist bei CC-Button gewollt
- **Andere Intents** (Complete, GetNextUp, Count) — nicht betroffen (openAppWhenRun=false)
- **CreateTaskSnippetIntent** — existiert noch als DEAD CODE, wird nur nicht mehr aufgerufen
- **macOS** — nicht betroffen (eigenes QuickCapturePanel, kein Siri-Intent-Handoff)

## Challenge-Ergebnis
Devil's Advocate Verdict: **LUECKEN → eingearbeitet**
- Plattform-Angabe ergaenzt (iOS only)
- Verwandter Bug (Text-Verlust) als Folge-Bug dokumentiert
- Dead-Code-Status von CreateTaskSnippetIntent klargestellt
- Dependency-Ungewissheit als offenen Punkt markiert
