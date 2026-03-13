# Bug Analysis: + Button fehlt in Priorität-Mode (iOS)

## Bug-Beschreibung
"Priorität hat unter iOS kein + um einen neuen Task hinzuzufügen. Alle Views sollen sich gleich verhalten."

**Plattform:** iOS
**Screen:** BacklogView -> Priority View-Mode
**Symptom:** + Button zum Erstellen neuer Tasks ist im Priority-Mode nicht sichtbar, aber in anderen Modes (Zuletzt, Ueberfaellig etc.) schon.

## Root Cause (nach Challenge-Runde aktualisiert)

### Wahrscheinlichste Ursache: SiriTipView im Group-Container (H4)

**Commit `ef8460b` (1. Maerz 2026)** fuegt SiriTipView als ERSTES Kind im Group-Container ein:

```swift
NavigationStack {
    Group {
        SiriTipView(intent: CreateTaskIntent(), isVisible: $showCreateTaskTip)  // NEU!
            .padding(.horizontal)

        if isLoading { ... }
        else if planItems.isEmpty { ... }
        else { switch selectedMode { priorityView / recentView / ... } }
    }
    .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
            viewModeSwitcher
            if remindersSyncEnabled { importButton }
            Button { showCreateTask = true } label: { Image(systemName: "plus") }  // + Button
        }
    }
    .withSettingsToolbar()
}
```

**Warum Priority-spezifisch:**
1. `showCreateTaskTip = true` (Zeile 72) — SiriTipView ist beim ERSTEN Render sichtbar
2. Priority ist DEFAULT-Mode (`@AppStorage` = `.priority`)
3. Group { SiriTipView + List } erzeugt TupleView
4. `.toolbar` auf TupleView kann SwiftUI-Rendering verursachen
5. Nach Mode-Wechsel: SiriTipView eventuell dismissed/re-layouted -> Toolbar korrekt

**Zeitliche Korrelation:** Commit ef8460b = 1. Maerz 2026, Bug-Report = 2. Maerz 2026

## Fix-Vorschlag

SiriTipView aus dem Group herausnehmen und in eine VStack-Struktur einbetten:

```swift
NavigationStack {
    VStack(spacing: 0) {
        SiriTipView(intent: CreateTaskIntent(), isVisible: $showCreateTaskTip)
            .padding(.horizontal)

        Group {
            if isLoading { ... }
            else if planItems.isEmpty { ... }
            else { switch selectedMode { ... } }
        }
    }
    .toolbar { ... }
    .withSettingsToolbar()
}
```

Oder die SiriTipView als `safeAreaInset(edge: .top)` implementieren.

## Betroffene Dateien
- `Sources/Views/BacklogView.swift` (nur 1 Datei, ~5 Zeilen Aenderung)

## Blast Radius
- Andere Tabs unabhaengig (kein + Button dort)
- macOS unabhaengig (eigener Quick Add Bar)
- Fix betrifft NUR das Layout der SiriTipView-Einbettung

## Challenge-Verdict: SOLIDE (nach Luecken-Behebung)
- SiriTipView als Verursacher zeitlich stark korreliert
- Einfacher, minimal-invasiver Fix
- Kein Risiko fuer andere Flows
