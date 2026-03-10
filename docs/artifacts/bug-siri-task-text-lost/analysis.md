# Bug: Siri "Erstelle Task" - Diktierter Text geht verloren

## Symptom
User sagt "Erstelle Task in FocusBlox". Siri fragt "In Nachrichten oder FocusBlox?".
User waehlt FocusBlox, diktiert Text. Klickt "FocusBlox oeffnen".
App oeffnet sich, aber der diktierte Text ist verschwunden.

## Plattform
iOS (nur iOS betroffen - macOS nutzt kein Siri-Intent-Handoff)

## Datenfluss (IST-Zustand)

```
Siri -> CreateTaskIntent.perform()
  -> defaults.set(true, forKey: "quickCaptureFromCC")   // Zeile 18
  -> defaults.set(taskTitle, forKey: "quickCaptureTitle") // Zeile 19
  -> KEIN defaults.synchronize()!
  -> return .result(dialog: "Oeffne FocusBlox...")

[User tippt "FocusBlox oeffnen"]

App wird aktiv -> checkCCQuickCaptureTrigger()
  -> defaults.bool(forKey: "quickCaptureFromCC")         // Zeile 369
  -> defaults.string(forKey: "quickCaptureTitle") ?? ""   // Zeile 372
  -> showQuickCapture = true
```

## Hypothesen

### H1: Fehlender `synchronize()` - Cross-Process Race Condition (HOCH)

**CreateTaskIntent** laeuft im **Intent Extension Process** (separater Prozess).
Die App laeuft in einem **anderen Prozess**.

`UserDefaults.set()` schreibt nur in den In-Memory-Buffer des Extension-Prozesses.
Ohne `synchronize()` wird der Buffer NICHT sofort auf Disk geflusht.

Wenn die App startet, erstellt sie eine EIGENE `UserDefaults(suiteName:)` Instanz
die von Disk liest. Wenn der Disk-Write noch nicht passiert ist, liest die App leere Werte.

**Beweis dafuer:**
- `CreateTaskIntent.swift:19` - kein `synchronize()` nach dem Write
- Andere Stellen im Code nutzen `synchronize()` korrekt:
  - `FocusBloxApp.swift:497` (`resetUserDefaultsIfNeeded`)
  - `SyncedSettings.swift` (Cloud-Sync)

**Beweis dagegen:**
- User muss "FocusBlox oeffnen" antippen (Sekunden Verzoegerung) - sollte reichen fuer Disk-Sync
- ABER: iOS gibt keine Timing-Garantie fuer Cross-Process UserDefaults Sync

### H2: `onOpenURL` ueberschreibt den Titel (MITTEL)

Wenn `openAppWhenRun = true` die App per URL-Scheme oeffnet statt per normalem Launch:

```swift
.onOpenURL { url in
    if url.host == "create-task" {
        quickCaptureTitle = ""  // <- RESET AUF LEER!
        showQuickCapture = true
    }
}
```

Zeile 316 setzt `quickCaptureTitle = ""`. Wenn `.onOpenURL` UND `checkCCQuickCaptureTrigger()`
beide feuern, gewinnt der letzte. `.onOpenURL` wuerde den aus UserDefaults gelesenen Titel
wieder loeschen.

**Beweis dafuer:**
- `FocusBloxApp.swift:316` setzt explizit `quickCaptureTitle = ""`
- Beide Handler setzen `showQuickCapture = true`
- Reihenfolge von SwiftUI-Event-Handlern ist nicht garantiert

**Beweis dagegen:**
- `openAppWhenRun = true` nutzt NICHT das URL-Scheme (ist normaler App-Launch)
- `.onOpenURL` sollte nur von Widgets/Deep-Links kommen
- Apple Docs sagen: openAppWhenRun oeffnet App, nicht per URL

### H3: QuickCapture oeffnet sich gar nicht (MITTEL)

Wenn BEIDE UserDefaults-Werte (Flag + Title) nicht auf Disk sind:
- `guard defaults.bool(forKey: "quickCaptureFromCC") else { return }` -> return (Guard schlaegt fehl)
- Funktion kehrt sofort zurueck
- App zeigt einfach ihren normalen Hauptbildschirm
- Kein QuickCapture-Sheet, kein Text

**Beweis dafuer:**
- Konsistent mit `synchronize()` Problem (H1)
- User sagt "App oeffnet sich aber Text ist weg" - nicht "QuickCapture ist leer"

**Beweis dagegen:**
- Wuerde bedeuten dass der Flag-Boolean auch nicht ankommt (gleicher Mechanismus)

### H4: Siri-Disambiguation verliert den Parameter (NIEDRIG)

Die "In Nachrichten oder FocusBlox?"-Disambiguierung koennte den `taskTitle`
Parameter verlieren bevor er an `CreateTaskIntent.perform()` uebergeben wird.

**Beweis dafuer:**
- User berichtet explizit von der Disambiguierung
- Das ist ein Apple-System-Level-Verhalten

**Beweis dagegen:**
- Apple's AppIntents Framework sollte Parameter durch Disambiguierung erhalten
- Der User diktiert den Text NACH der Disambiguierung

## Wahrscheinlichste Ursache

**H1 (fehlender `synchronize()`) ist die Hauptursache**, moeglicherweise verstaerkt durch H3.

Der Intent-Extension-Prozess schreibt in UserDefaults ohne Flush.
Die App liest im eigenen Prozess von Disk, wo die Daten noch nicht angekommen sind.

Ergebnis: Entweder
- Flag UND Titel fehlen -> kein QuickCapture (H3)
- Flag ist da, Titel nicht -> QuickCapture mit leerem Feld

## Debugging-Plan (zur Beweisfuehrung)

1. In `CreateTaskIntent.perform()` Zeile 19: `print("INTENT: Writing title='\(taskTitle)'")`
2. In `checkCCQuickCaptureTrigger()` Zeile 369: `print("CHECK: flag=\(defaults.bool(forKey: "quickCaptureFromCC")), title=\(defaults.string(forKey: "quickCaptureTitle") ?? "NIL")")`
3. App auf Device ausfuehren, Siri-Command triggern, Console.app Logs pruefen

Das wuerde bestaetigen:
- Ob `taskTitle` im Intent ueberhaupt gefuellt ist
- Ob der Flag/Titel beim Lesen vorhanden ist

## Blast Radius

| Flow | Betroffen? | Grund |
|------|-----------|-------|
| CreateTaskIntent (Siri) | JA | UserDefaults Race |
| QuickAddLaunchIntent (CC) | NEIN | Kein Text, nur Flag |
| CreateTaskSnippetIntent | NEIN | In-Process, kein UserDefaults |
| SaveQuickCaptureIntent | NEIN | Direkter Parameter |
| Widgets | NEIN | URL-Scheme, kein Text |
| macOS | NEIN | Eigenes QuickCapturePanel |
| Share Extension | NEIN | Direkter SwiftData-Zugriff |

**Nur CreateTaskIntent ist betroffen.** Blast Radius ist minimal.

## Vorherige verwandte Bugs

- Bug 36 (CC Quick Task): Gleicher UserDefaults-Mechanismus, Fix war Flag-basiert
- Bug 87 (QuickCapture Dialog): Anderes Problem (dismiss Timing)
- Siri-Shortcuts-Broken: Indexing-Problem, nicht Daten-Verlust
- Kein vorheriger Bug mit exakt diesem Symptom (Text-Verlust bei Siri)
