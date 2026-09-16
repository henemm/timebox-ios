# Design-Briefing für Claude Design

> Erstellt: 2026-09-16
> Status: Bereit für Claude Design
> Voraussetzung: `01-user-story.md` (approved), `02-datenmodell-und-ansichten.md`

Dieses Dokument ist in sich vollständig. Es setzt die anderen Dokumente nicht voraus,
verweist aber auf sie, wo Details stehen.

## Das Produkt in drei Sätzen

Ein Textfeld, das alles annimmt: Aufgabe sagen oder tippen, fertig. Dahinter ein stiller
Sekretär, der jede Eingabe einmal in Struktur übersetzt (Titel, Fälligkeit, Wichtigkeit,
Dringlichkeit, Dauer, Energie, Kontexte, Personen, Projekt, Abhängigkeit) und jede Änderung
sichtbar und rückgängig machbar hält. Vorne wenige berechnete Ansichten, die zur Situation
passen: im Garten, fünf Minuten Zeit, wartet schon lange.

## Design-Leitbild

- Minimalistisch, wenige Farben, iOS-nativ, so nah wie möglich am aktuellen Apple-Paradigma
  (Liquid Glass). Keine Custom-Widgets, keine eigenen Controls, wo ein Systemcontrol existiert.
- Die KI ist unsichtbar, bis sie etwas verändert hat. Dann ist sie ein dezentes Zeichen, kein Banner.
- Nichts ist Pflicht. Kein Formular, kein leeres Feld, das nach Eingabe ruft.
- Die App plant nicht. Sie zeigt. Kein Timer, kein Kalender-Raster, kein Coach.
- SF Symbols, Systemschriften, Dynamic Type, Dark Mode, Englisch und Deutsch (Textlängen).

## Plattformen

| Plattform | Rolle | Layout |
|-----------|-------|--------|
| iPhone | Primär. Erfassen, Ansichten, Detail. | Ein Navigationsmodell, siehe offene Frage 1 |
| Mac | Gleichwertig, dieselben Views. | NavigationSplitView: Sidebar mit Ansichten, Liste, Detail |
| iPad | Wie Mac. | NavigationSplitView |
| Watch | Nur Erfassung per Sprache. | Ein Screen plus Bestätigung, Complication |
| Widgets | "Als nächstes" lesen, Control für Erfassung. | Small, Medium, Control-Center-Button |

Ein Code für alle: Was auf dem iPhone ein Screen ist, ist auf dem Mac eine Spalte.

## Screens und Flows

### 1. Erfassungs-Szene (Quick Capture)

Der wichtigste Screen. Erreichbar über Control Center, Action Button, App-Button, Mac-Hotkey.

- Öffnet ohne Tab, ohne Ladezustand. Mikrofon hört sofort, Wellenform zeigt es.
- Ein Textfeld, das den erkannten Text live zeigt und tippbar ist.
- Ein Button: Fertig. Kein Datum, keine Liste, keine Priorität, kein Tag.
- Nach Fertig: kurze Bestätigung, Szene schließt. Die Aufgabe erscheint in "Neu".
- Aus Mail (Teilen-Menü): dieselbe Szene, Textfeld vorbefüllt mit Betreff, Mail-Link angeheftet.
- Mac: schwebendes Panel, Hotkey öffnet, Enter sendet, Escape schließt.

### 2. Startscreen: Ansichten

Der Einstieg zeigt die Ansichten, nicht eine Aufgabenliste.

Systemansichten mit Zähler: Als nächstes, Neu, Fällig, Schnell, Alt, Wartet, Wiederkehrend.
Darunter Kontexte (Startset: Computer, Telefon, Haus, Garten, Unterwegs, Besorgung, alle löschbar)
und Projekte. Erfassungs-Button ist auf jedem Screen an derselben Stelle erreichbar.

Berechnungsregeln der Ansichten stehen in `02-datenmodell-und-ansichten.md`.

### 3. Ansicht (Aufgabenliste)

Eine Liste. Jede Zeile:

- Titel (oder Rohtext, wenn ungeprüft, dann visuell als Rohtext erkennbar).
- Höchstens drei kleine Merkmale: Fälligkeit, Dauer, ein Kontext. Der Rest ist im Detail.
- KI-Marker, wenn die KI etwas geändert hat und der Nutzer es noch nicht gesehen hat.
- Blockiert-Zeichen, wenn eine andere Aufgabe vorher erledigt werden muss.
- Wisch rechts: Erledigt. Wisch links: Zu "Als nächstes" oder daraus entfernen.
- Nur "Als nächstes" ist manuell sortierbar (Drag). Alle anderen Ansichten haben feste Sortierung.
- Leerzustand je Ansicht in einem Satz, ohne Illustration.

### 4. Aufgaben-Detail

- Oben der Titel, editierbar. Darunter, klein, der Rohtext, nicht editierbar.
- Abgeleitete Felder als kompakte Zeilen: Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Energie,
  Kontexte, Personen, Projekt, Wiederholung, "Im Kalender anzeigen".
- Jedes Feld, das die KI gesetzt hat, trägt ein kleines Zeichen. Tipp darauf: Vorher, Nachher,
  Begründung in einem Satz, Button "Zurücksetzen".
- Leere Felder sind leer, keine Platzhalter, die zur Eingabe drängen.
- Bereich "Blockiert durch": Liste der Aufgaben, die vorher erledigt sein müssen.
- Bereich "Unteraufgaben": eine Ebene, abhakbar, per Textfeld ergänzbar (siehe offene Frage 3).
- Bereich "Quelle": Link zurück zur Mail, wenn vorhanden.
- Aktion "Neu analysieren" (bewusst versteckt, im Menü), sonst passiert Veredelung nur einmal.

### 5. Revisions-Sheet

Vom KI-Marker aus: Liste aller Änderungen an dieser Aufgabe, neueste oben.
Je Eintrag: Feld, alt, neu, wer (KI oder Nutzer), wann, Begründung. Je Eintrag "Zurücksetzen".
Nach dem Öffnen gilt der Marker als gesehen.

### 6. Projekt-Ansicht

Projekte sind Listen und später die Einheit fürs Teilen. Zeigt Aufgaben des Projekts,
optional manuell sortiert, mit Unteraufgaben eingerückt oder eingeklappt.
Hier entscheidet sich, ob Hierarchie gut aussieht (offene Frage 3).

### 7. Kontexte und Projekte verwalten

Eine Liste zum Umbenennen, Löschen, Neuanlegen. Keine Farben, keine Icons je Kontext in Version 1.

### 8. Watch

Ein Screen: Mikrofon-Button, Diktat, Bestätigung. Complication öffnet direkt das Diktat.
Kein Lesen, kein Abhaken in Version 1.

### 9. Widgets und Control

- Small: die oberste Aufgabe aus "Als nächstes".
- Medium: die obersten drei.
- Control Center: ein Button, der die Erfassungs-Szene öffnet.

### 10. Onboarding

Drei Schritte, überspringbar: Siri-Zugriff, Mitteilungen, Startset der Kontexte ansehen.
Hinweis, wenn Apple Intelligence auf dem Gerät nicht verfügbar ist (dann gibt es keine Veredelung).

## Zustände, die das Design zeigen muss

| Zustand | Bedeutung | Sichtbar durch |
|---------|-----------|----------------|
| Ungeprüft | KI war sich beim Titel nicht sicher | Rohtext-Optik, in "Neu" |
| Unverarbeitet | Veredelung steht noch aus (offline, Modell nicht verfügbar) | Dezenter Hinweis, in "Neu" |
| KI hat geändert | Ungesehene KI-Revisionen | Marker an der Zeile und am Feld |
| Blockiert | Wartet auf andere Aufgabe | Zeichen an der Zeile, ausgeblendet in "Als nächstes" |
| Wiederkehrend | Rückt nach Erledigung weiter | Zeichen an der Zeile, Ansicht "Wiederkehrend" |
| Aus Mail | Hat Quell-Link | Zeichen im Detail |

## Tonalität

Ruhig, knapp, vertrauensvoll. Die App erklärt sich nicht, sie zeigt.
Texte in Englisch (Basis) und Deutsch. Keine Ausrufezeichen, keine Gamification, keine Motivationssprüche.

## Nicht gestalten

Timer, Fokusmodus, Kalender-Raster, Tagesplanung, Charts, Coach, Standortkarten,
Sharing-Flows, freie Suche in natürlicher Sprache.

## Offene Fragen an Claude Design

1. **Navigationsmodell iPhone.** Startscreen mit Ansichten wie in Erinnerungen, oder Tab-Leiste
   mit drei Tabs (Ansichten, Als nächstes, Erfassen)? Welche Variante hält die Erfassung am kürzesten?
2. **KI-Marker.** Wie sieht ein Zeichen aus, das man bemerkt, aber das nicht drängt, und das
   in der Zeile und am einzelnen Feld funktioniert?
3. **Hierarchie.** Wie zeigen wir Unteraufgaben und Projekte so, dass es eine Ebene bleibt,
   aber sich nicht nach Checkliste anfühlt? Das war die Bedingung des PO für Hierarchie überhaupt.
4. **Ungeprüft.** Wie unterscheidet sich Rohtext von Titel, ohne dass die Zeile hässlich wird?
5. **Mac.** Reicht NavigationSplitView mit Sidebar, oder braucht die Erfassung ein eigenes Panel-Design?

## Technischer Rahmen für das Design

- SwiftUI, ein Multiplattform-Target. Alles, was gezeichnet wird, muss mit Systemkomponenten gehen.
- Accessibility-Identifier folgen dem Muster `camelCaseButton`, `taskRow_<uuid>`, `contextTile_<uuid>`.
- Dynamic Type bis XXL, VoiceOver für alle Aktionen inklusive Zurücksetzen.
- Deployment Target iOS 27, macOS 27, watchOS 27. Apple Intelligence ab iPhone 15 Pro.
