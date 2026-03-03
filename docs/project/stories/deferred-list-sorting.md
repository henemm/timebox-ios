# User Story: Deferred List Sorting

> Erstellt: 2026-03-03
> Status: Approved
> Produkt: FocusBlox

## JTBD Statement

**When** ich Tasks in einer sortierten ListView bearbeite und Attribute aendere (z.B. Dringlichkeit/Wichtigkeit per Karussell), die die Sortierposition beeinflussen,
**I want to** dass der Task an Ort und Stelle bleibt und visuell als "geaendert" markiert wird,
**So that** ich die Kontrolle behalte, weitere Aenderungen vornehmen kann (z.B. Karussell mehrfach tippen), und die Liste nicht bei jedem Tap herumspringt.

## Kontext

### Die Situation
Der Nutzer ist in einer sortierten ListView (z.B. Backlog, Today) und will ein Task-Attribut aendern, das die Sortierposition beeinflusst. Besonders bei Karussell-Steuerelementen (Dringlichkeit, Wichtigkeit) muss er mehrfach tippen, um den gewuenschten Wert zu erreichen.

### Das Problem heute
Bei jedem Tap auf ein sortierrelevantes Attribut wird der Task **sofort** umsortiert und "verschwindet" aus dem Sichtfeld. Um den naechsten Wert im Karussell zu waehlen, muss der Nutzer den Task erst wieder in der Liste suchen. Das macht Karussell-Steuerungen praktisch unbenutzbar und fuehrt zu Frustration.

### Alternativen
- Alternative 1: Task suchen und erneut antippen (aktuelle Loesung - muehsam und fehleranfaellig)
- Alternative 2: Task in Detail-View oeffnen und dort aendern (umstaendlich, bricht den Flow)

## Dimensionen

### Funktional
- Attribut-Aenderungen in sortierten ListViews loesen keine sofortige Umsortierung aus
- Geaenderte Items bekommen einen visuellen Rahmen ("pending re-sort")
- 3-Sekunden-Timer nach letzter Aenderung, dann Umsortierung
- Timer wird bei jeder weiteren Aenderung (am selben oder anderen Item) zurueckgesetzt
- Mehrere Items koennen gleichzeitig "pending" sein
- Nach Timeout: Rahmen fadet aus → kurze Pause → sanfte Umsortierung

### Emotional
- **Kontrolle:** Ich sehe was ich gerade getan habe - nichts verschwindet ploetzlich
- **Sicherheit:** Ich kann Fehler sofort korrigieren bevor das Item "weg" ist
- **Ueberblick:** Ich kann mehrere Tasks hintereinander aendern ohne Chaos in der Liste

### Sozial
Nicht relevant (persoenliches Produktivitaetstool).

## Erfolgskriterien

- [ ] Attribut-Aenderung loest KEINE sofortige Umsortierung aus
- [ ] Geaendertes Item bekommt sichtbaren Rahmen
- [ ] Timer (3 Sek.) wird bei jeder weiteren Aenderung zurueckgesetzt
- [ ] Mehrere Items koennen gleichzeitig "pending" sein (je mit Rahmen)
- [ ] Nach Timeout: Rahmen fadet aus, dann Umsortierung mit kurzer Verzoegerung
- [ ] Karussell-Steuerung (Dringlichkeit/Wichtigkeit) ist damit fluessig benutzbar
- [ ] Gilt fuer alle sortierten ListViews (nicht nur Backlog)
- [ ] Beide Plattformen: iOS und macOS

## Abgeleitete Features

| Feature | Prioritaet | Status |
|---------|------------|--------|
| Deferred Sort Engine (Timer + State-Tracking) | Must | Backlog |
| Visueller "Pending"-Rahmen mit Fade-Animation | Must | Backlog |
| Karussell-Kompatibilitaet (mehrfach tippen) | Must | Backlog |
| Anwendung auf alle sortierten ListViews | Must | Backlog |

---
*Ermittelt im JTBD-Dialog am 2026-03-03*
