# User Story: Contextual Task Capture

> Erstellt: 2026-03-02
> Status: Approved
> Produkt: FocusBlox

## JTBD Statement

**When** ich mitten in einer Taetigkeit bin (E-Mail lesen, browsen, in einer App arbeiten) und mir auffaellt "Das muss ich erledigen",
**I want to** aus dem aktuellen Kontext heraus (E-Mail, Website, Clipboard, Diktat) sofort eine Task in FocusBlox erstellen — mit einem Tap, ohne App-Wechsel,
**So that** mein Kopf frei ist, nichts verloren geht, und mein Workflow nicht unterbrochen wird.

## Kontext

### Die Situation
Der Nutzer ist in verschiedensten Kontexten unterwegs — liest E-Mails, recherchiert im Browser, arbeitet in anderen Apps, diktiert auf der Apple Watch. In jedem dieser Momente kann der Impuls entstehen, etwas als Task festzuhalten. Der Kontextwechsel zur FocusBlox App ist der Feind: Er kostet Zeit, unterbricht den Flow, und bis man in der App ist, geht Information verloren.

### Das Problem heute
- Die Share Extension (ITB-E) existiert, ist aber **nur iOS**, hat einen **CloudKit-Bug (62)**, und macht **keine intelligente Titelverarbeitung** — sie nimmt den rohen Text 1:1
- Es gibt keinen macOS Share-Weg
- Es gibt keine zentrale Engine, die aus unstrukturiertem Input einen sauberen Task-Titel macht
- Der SmartTaskEnrichmentService enriched Attribute (Wichtigkeit, Kategorie), aber **beruehrt den Titel nicht**
- E-Mail-Subjects sind oft kryptisch ("Re: Fwd: AW: Meeting") und taugen nicht direkt als Task-Titel

### Alternativen
- **Manuell:** App oeffnen, Task tippen — zu viele Schritte, Kontextverlust
- **Copy-Paste:** Text kopieren, App wechseln, einfuegen — umstaendlich
- **Gar nicht:** Task vergessen, weil der Aufwand zu hoch ist — schlimmster Fall

## Dimensionen

### Funktional
- Share Sheet als primaerer Eingangsweg (iOS + macOS)
- Intelligente Titel-Generierung aus beliebigem Raw-Input (Foundation Models, on-device)
- E-Mail-Support: Subject + Deep-Link zurueck zur Mail
- Clipboard als Task-Quelle
- Hintergrund-Verarbeitung: Task sofort mit Roh-Titel, KI verbessert asynchron
- Original-Input bleibt in Task-Beschreibung (Transparenz)

### Emotional
- **Erleichterung:** "Das ist jetzt erfasst, ich kann es vergessen und weitermachen"
- **Kontrolle:** "Ich habe alles im Griff, nichts geht verloren"
- **Effizienz:** "Das ging schnell und reibungslos — kein Bruch im Workflow"

### Sozial
- Professionelles Auftreten: Nichts faellt durch die Ritzen
- Zuverlaessigkeit: Jede Anfrage/E-Mail wird erfasst und bearbeitet

## Erfolgskriterien

- [ ] Aus Mail.app eine E-Mail teilen -> Task mit intelligentem Titel + Link zur Mail
- [ ] Aus Safari eine Seite teilen -> Task mit sinnvollem Titel + URL
- [ ] Auf iOS UND macOS funktionsfaehig (Share Sheet)
- [ ] Clipboard-Inhalt als Task-Quelle nutzbar
- [ ] KI-generierter Titel ist actionable ("Auf Herberts Mail antworten" statt "Re: Fwd: Meeting")
- [ ] Original-Text bleibt in Beschreibung erhalten
- [ ] Diktierte Tasks (Watch) profitieren von derselben Engine

## Abgeleitete Features

| Feature | Prioritaet | Status |
|---------|-----------|--------|
| Bug 62 fixen (Share Extension CloudKit) | Must | Offen |
| TaskTitleEngine Service (Foundation Models) | Must | Neu |
| E-Mail-Support in Share Extension | Must | Neu |
| macOS Share Extension | Must | Neu |
| Clipboard -> Task Flow | Should | Neu |
| Watch-Diktat Titel-Verbesserung | Nice | Neu |

## Technischer Kontext (Bestand)

### Bestehende Services (relevant)
- **SmartTaskEnrichmentService** (`Sources/Services/SmartTaskEnrichmentService.swift`): Enriched Attribute (Importance, Urgency, Category, Energy) — beruehrt Titel NICHT
- **AITaskScoringService** (`Sources/Services/AITaskScoringService.swift`): Scored Tasks 0-100 — beruehrt Titel NICHT
- **Share Extension** (`FocusBloxShareExtension/`): iOS-only, CloudKit-Bug, keine intelligente Verarbeitung

### Neuer Service: TaskTitleEngine
- Zentraler Service in `Sources/Services/` (Shared Code!)
- Foundation Models API (iOS 26+ / macOS 26+)
- Input: Raw-Text (E-Mail-Subject, URL-Titel, Diktat, Clipboard)
- Output: Actionable Task-Titel
- Graceful Degradation: Ohne Apple Intelligence wird Roh-Titel beibehalten
- Wird von allen Eingangswegen genutzt: Share Extension, Watch, manuelle Eingabe

### Architektur-Entscheidung
- TaskTitleEngine in `Sources/Services/` (cross-platform)
- macOS Share Extension als neues Target (analog zu iOS)
- Beide Share Extensions nutzen denselben Shared Code

---
*Ermittelt im JTBD-Dialog am 2026-03-02*
