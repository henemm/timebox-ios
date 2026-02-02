# User Story: TimeBox macOS

> Erstellt: 2026-01-31
> Status: Draft
> Produkt: TimeBox macOS
> Basis: timebox-core.md

## JTBD Statement (macOS-spezifisch)

**When** ich am Mac sitze und fokussiert arbeiten, meinen Tag planen oder reviewen will,
**I want to** meine Kommandozentrale haben, die mir Übersicht gibt und schnelle Eingabe ermöglicht,
**So that** ich die Kontrolle über meine Zeit habe – plane am Mac, führe überall aus.

## Kontext

### Die Situation
Der Mac ist der Ort der bewussten Planung. Hier sitze ich mit großem Bildschirm, Tastatur und Zeit. Anders als das iPhone (immer dabei, schnelle Interaktionen) ist der Mac der Moment für:
- **Morgens:** Den Tag strukturieren, Aufgaben in Blöcke ziehen
- **Abends:** Review – was wurde geschafft, was nicht
- **Fokusarbeit:** Deep Work am Schreibtisch mit dezentem Timer

### Unterschied zum iPhone
Das iPhone ist der **Ausführungspartner** – immer dabei, zeigt den Timer prominent (Dynamic Island, Lockscreen), ermöglicht Quick Capture unterwegs.

Der Mac ist die **Kommandozentrale** – Übersicht, Planung, Review, komfortable Eingabe.

## Kernunterschiede zu iOS

| Aspekt | iOS | macOS |
|--------|-----|-------|
| Haupt-Usecase | Ausführung (unterwegs) | Planung & Review (Schreibtisch) |
| Präsenz | Aktiv (Dynamic Island, Lockscreen) | Dezent (Menü-Bar + Notifications) |
| Planung | Schnell, touch-basiert | Komfortabel (Drag&Drop, Keyboard, Übersicht) |
| Review | Kurz-Check | Ausführlich (Statistiken, Wochen-Trends) |
| Eingabe | Quick Capture Sheet | Spotlight-artige schnelle Eingabe |
| Gefühl | "Timer am Handgelenk" | "Kommandozentrale" |

## Dimensionen

### Funktional (macOS-spezifisch)

**Menü-Bar Widget:**
- Minimalistisch: Timer + aktuelle Aufgabe
- Click öffnet Quick Actions oder Haupt-App
- Dezent präsent, nicht störend

**Planung am großen Bildschirm:**
- Kalender-View mit sichtbaren freien Blöcken
- Drag & Drop: Aufgaben in Blöcke ziehen
- Keyboard Shortcuts für alles
- Multi-Selection, Bulk-Operationen

**Schnelle Eingabe:**
- Globaler Hotkey (wie Spotlight)
- Öffnet überall ein Capture-Feld
- Aufgabe tippen → Enter → weg

**Review-Dashboard:**
- Tages-/Wochen-/Monats-Übersicht
- Kategorien-Verteilung visualisiert
- Trends über Zeit

### Emotional
- **Morgens:** "Ich habe die Übersicht und plane bewusst"
- **Tagsüber:** "Der Timer läuft dezent mit, ich bin fokussiert"
- **Abends:** "Ich sehe konkret, was ich geschafft habe"

### Technisch
- Nahtloser Sync mit iPhone (kritisch!)
- Native macOS App (kein Electron)
- System-Integration (Menü-Bar, Notifications, Shortcuts)

## macOS-spezifische Features

### Must Have
1. **Menü-Bar Widget** – Timer + aktuelle Aufgabe, immer sichtbar
2. **Nahtloser Sync mit iPhone** – Änderungen sofort überall
3. **Keyboard Shortcuts** – Komplette Bedienung ohne Maus möglich
4. **Globaler Quick Capture** – Hotkey öffnet Eingabe von überall

### Should Have
5. **Drag & Drop Planung** – Aufgaben in Kalender-Blöcke ziehen
6. **Statistik-Dashboard** – Wochen-Trends, Kategorien-Verteilung
7. **Spotlight-Integration** – Aufgaben direkt aus Spotlight erfassen

### Could Have
8. **Shortcuts.app Integration** – Automationen ermöglichen
9. **Focus Modes Integration** – Timer startet automatisch Focus Mode
10. **Widget für Notification Center**

## Shared Core (identisch mit iOS)

Diese Konzepte sind plattformübergreifend identisch:

- **JTBD-Kern:** Freie Zeit für wichtige Dinge nutzen
- **Backlog-System** mit Kategorien (Schneeschaufeln, Lernen, etc.)
- **Focus-Blöcke** mit Timer und Gong
- **Apple Reminders Integration** als Datenquelle
- **Kategorien** für Rückblick (wofür wurde Zeit verwendet)
- **Ende-Handling:** "Erledigt" oder "Nicht fertig"

## Erfolgskriterien

- [ ] Ich plane meinen Tag komfortabel am Mac (Drag & Drop, Übersicht)
- [ ] Der Timer läuft dezent in der Menü-Bar mit
- [ ] Ich kann von überall mit Hotkey eine Aufgabe erfassen
- [ ] Änderungen synchen sofort mit meinem iPhone
- [ ] Ich sehe am Ende der Woche ein aussagekräftiges Review
- [ ] Die App fühlt sich wie eine native Mac-App an (keine iOS-Portierung)
- [ ] Keyboard-Power-User können alles ohne Maus bedienen

## Abgrenzung

**macOS ist NICHT:**
- Eine 1:1 Kopie der iOS App
- Der primäre Ausführungsort (das ist iPhone/Watch)
- Eine Feature-abgespeckte Version

**macOS IST:**
- Die Planungs- und Review-Zentrale
- Optimiert für Keyboard und großen Bildschirm
- Der Ort für tiefe Analyse und Übersicht

---
*Ermittelt im JTBD-Dialog am 2026-01-31*
