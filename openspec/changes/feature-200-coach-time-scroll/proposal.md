# FEATURE_200 — Coach-Tab: Tageszeitbasiertes Auto-Scroll

**GitHub Issue:** #200 (neu erstellen)
**Status:** Spec approved
**Modus:** ÄNDERUNG (bestehende CoachView erweitern)

---

## Was und Warum

### Problem (IST-Zustand)

Der Coach-Tab zeigt alle 3 Sektionen (Morgen, Tag, Abend) gleichzeitig sichtbar.
- Morgens sieht der User "Tagesrückblick" (irrelevant)
- Abends sieht der User "Guten Morgen" ganz oben (irrelevant)
- `scrollToCurrentPhase()` scrollt zwar `onAppear`, aber ohne Einrast-Mechanismus
- `morningEndHour` Default ist 12 (zu spät — User will 10)

### Lösung (SOLL)

Die View rastet an der tageszeitrelevanten Sektion ein:

1. **View-Aligned Scrolling:** Jede Section füllt den Viewport. Scrollen rastet an Section-Grenzen ein ("Widerstandsgefühl")
2. **Auto-Scroll bei Öffnen:** Scrollt zur aktuellen Phase
3. **Intention-Trigger:** Nach Intention-Auswahl → sanft zu "Dein Tag" scrollen
4. **Peek-Effekt:** Angrenzende Sektionen sind am Rand angedeutet sichtbar
5. **Phasen-Logik:**
   - Morning: bis 10:00 ODER bis Intention gesetzt (was zuerst kommt)
   - Daytime: ab 10:00 (oder nach Intention) bis eveningStartHour
   - Evening: ab eveningStartHour (aus Settings)

### User-Erwartung

- Eine Sektion im Fokus, andere nur angedeutet
- Scrollen möglich aber mit "Widerstands"-Gefühl (Einrasten)
- Nach Intention-Auswahl: kurze Bestätigung, dann sanft zu "Dein Tag"
- Morgens/Mittags/Abends immer die richtige Sektion im Fokus

---

## Aktueller Zustand (Delta-Basis)

### CoachView.swift — Zeile 59-76

```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            morningSection.id("morning")
            daytimeSection.id("daytime")
            eveningSection.id("evening")
        }
        .padding()
    }
    .onAppear { scrollToCurrentPhase(proxy: proxy) }
}
```

- `morningEndHour` Default = 12 (Zeile 8)
- `scrollToCurrentPhase()` scrollt nur `onAppear` (Zeile 441-451)
- `selectIntention()` scrollt nicht weiter (Zeile 245-253)
- currentPhase nutzt `morningEndHour` / `eveningStartHour` (Zeile 43-46)

---

## Implementierungsplan

### Scope: 1 Source-Datei + 1 Test-Datei, ~60 LoC

#### Datei 1: `Sources/Views/CoachView.swift` (~50 LoC Änderungen)

**Änderung 1:** `morningEndHour` Default 12 → 10 (Zeile 8)

**Änderung 2:** Intention-basierte Phase-Logik (currentPhase erweitern)
```swift
private var currentPhase: DayPhase {
    let hour = Calendar.current.component(.hour, from: Date())
    // Morning bleibt aktiv wenn VOR morningEndHour UND keine Intention gesetzt
    if hour < morningEndHour && todayIntention == nil {
        return .morning
    }
    return DayPhase.from(hour: hour, morningEnd: morningEndHour, eveningStart: eveningStartHour)
}
```

**Änderung 3:** ScrollView → View-Aligned Paging
```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {  // spacing: 0 statt 32
            morningSection
                .id("morning")
                .containerRelativeFrame(.vertical)
            daytimeSection
                .id("daytime")
                .containerRelativeFrame(.vertical)
            eveningSection
                .id("evening")
                .containerRelativeFrame(.vertical)
        }
        .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .onAppear { scrollToCurrentPhase(proxy: proxy) }
}
```

**Änderung 4:** `selectIntention()` — nach Auswahl zu "daytime" scrollen
- ScrollViewProxy als @State speichern
- Nach `selectIntention()`: 0.8s Delay → `proxy.scrollTo("daytime")`

#### Datei 2: `FocusBloxTests/CoachPhaseLogicTests.swift` (~40 LoC)

Unit Tests für die Phase-Logik:
- `test_morning_beforeEnd_noIntention_isMorning`
- `test_morning_beforeEnd_withIntention_isDaytime`
- `test_afterMorningEnd_isDaytime`
- `test_afterEveningStart_isEvening`

---

## Was NICHT in diesem Scope

- Abgedunkelte/Blur-Effekte auf nicht-aktive Sektionen (visuell nice-to-have, separates Ticket)
- Timer der automatisch scrollt wenn die Uhrzeit wechselt (App wird sowieso bei Öffnen refresht)
- macOS-spezifische Anpassungen (Shared Code, wirkt automatisch)
- SettingsView-Änderungen (morningEndHour/eveningStartHour existieren bereits)

---

## Plattform-Parität

CoachView ist Shared Code in `Sources/Views/`. Änderungen wirken auf iOS + macOS.
`containerRelativeFrame` und `scrollTargetBehavior` sind ab iOS 17/macOS 14 verfügbar (wir targeten 26).

**Pflicht:** Nach Implementation `./scripts/sim.sh build` UND `./scripts/sim.sh mac-build` ausführen.
