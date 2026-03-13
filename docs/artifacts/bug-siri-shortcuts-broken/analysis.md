# Analyse: Siri-Tipps angezeigt, Kommandos funktionieren nicht

## Bug-Beschreibung

Henning sieht Siri-Tipps in der App (z.B. "Was steht an in FocusBlox"). Er hat ein vorgeschlagenes Kommando ausprobiert ("Wie viele Tasks sind in Focus Blocks"), aber Siri antwortet mit einem generischen Fehler: "Die Anzahl der Aufgaben in den Fokusbloechen wird nicht angegeben.. Apple-Support" -- das ist NICHT unsere App-Antwort, sondern Siri's eigene generische Antwort.

## Zusammenfassung der Agenten-Ergebnisse

### Agent 1 (History)
- AppIntents seit Feb 2026 (ITB-A), massiv erweitert mit ITB-G (1. Maerz 2026)
- SiriTipView wurde in ITB-G hinzugefuegt (Commit ef8460b) — wurde NIE von Henning angefordert
- SiriTipView aus BacklogView entfernt (Commit a89d17f), aber ContentView + SettingsView haben noch SiriTipViews

### Agent 2 (Datenfluss)
- 11 Intents insgesamt, 4 davon bei Siri registriert (via FocusBloxShortcuts)
- CountOpenTasksIntent.perform() nutzt SharedModelContainer (App Group) + SwiftData Fetch
- Bei Erfolg: "Du hast X offene Tasks." — diese Antwort kam NICHT, also wurde der Intent nicht aufgerufen

### Agent 3 (Alle Intents)
- SiriTipViews aktiv in: ContentView (GetNextUpIntent), SettingsView (CompleteTaskIntent)
- FocusBloxShortcuts registriert 4 Phrases mit `.applicationName`

### Agent 4 (Failure Szenarien)
- CountOpenTasksIntent hat KEINE Tests
- Kein do/catch in perform() — Fehler werden nicht abgefangen
- SharedModelContainer.create() koennte auf Device fehlschlagen (App Group)

### Agent 5 (Blast Radius)
- 20 Dateien importieren AppIntents — tiefe Integration
- Watch App und Share Extension NICHT betroffen
- Entfernung waere Major Refactoring (800+ LoC)

## Hypothesen

### Hypothese 1: Siri hat die Shortcuts nicht indiziert (HOCH)

Siri braucht Zeit (bis zu 24-48h) um AppShortcuts zu entdecken und zu indizieren. Die Intents wurden am 1. Maerz hinzugefuegt und Henning hat sie wahrscheinlich kurz danach ausprobiert.

**Beweis DAFUER:**
- Die Siri-Antwort ist generisch ("Apple-Support"), nicht unsere Intent-Antwort ("Du hast X offene Tasks")
- Das zeigt: Siri hat den Intent GAR NICHT aufgerufen, sondern die Frage allgemein beantwortet
- SiriTipView zeigt die Phrase in der App an, aber das ist nur ein UI-Element — es registriert den Intent nicht bei Siri

**Beweis DAGEGEN:**
- AppShortcutsProvider sollte Shortcuts automatisch bei Build/Install registrieren
- Es ist 2 Tage her seit dem Commit

### Hypothese 2: Phrase-Mismatch — Henning hat falsche Worte gesagt (HOCH)

Registrierte Phrase: "Wie viele Tasks in FocusBlox" (Zeile 42 FocusBloxShortcuts.swift)
Henning hat gesagt: "Wie viele Tasks **sind** in **Focus Blocks**"

Unterschiede:
1. "sind" ist extra (nicht in der registrierten Phrase)
2. "Focus Blocks" statt "FocusBlox"

**Beweis DAFUER:**
- Siri Phrase-Matching ist in iOS 26 strenger als erwartet
- `.applicationName` sollte den App-Namen automatisch ersetzen, aber der Display-Name ist "FocusBlox", nicht "Focus Blocks"
- Das extra Wort "sind" koennte das Matching verhindern

**Beweis DAGEGEN:**
- Apple Intelligence sollte fuzzy Phrase-Matching unterstuetzen
- `.applicationName` Token sollte verschiedene Varianten des App-Namens akzeptieren

### Hypothese 3: SharedModelContainer.create() wirft Fehler auf dem Geraet (MITTEL)

Die Intent perform()-Methode hat kein do/catch. Wenn der App Group Container nicht verfuegbar ist, wirft SharedModelContainer.create() einen Fehler und Siri zeigt eine generische Fehlermeldung.

**Beweis DAFUER:**
- Kein Test fuer CountOpenTasksIntent
- Keine Error-Recovery in perform()
- App Group Container ist auf Device anders konfiguriert als auf Simulator

**Beweis DAGEGEN:**
- Andere Intents (GetNextUpIntent, CompleteTaskIntent) nutzen den gleichen Container
- App Group Entitlements sind korrekt konfiguriert
- Die Antwort "Apple-Support" klingt nicht nach einem Intent-Error, sondern nach Siri's generischer Antwort

### Hypothese 4: SiriTipViews wurden nie angefordert — Feature-Creep (SICHER)

Die SiriTipViews in ContentView und SettingsView wurden in ITB-G (Commit ef8460b) hinzugefuegt, ohne dass Henning sie angefordert hat. Henning fragt: "Was bedeuten diese Tipps?"

**Beweis:** Henning sagt explizit "was bedeuten sie?" und "ich kann mich nicht daran erinnern, das irgendwo spezifiziert zu haben" (vom vorherigen Bug-Report)

## Wahrscheinlichste Ursache(n)

1. **Feature-Creep:** SiriTipViews wurden ohne Anforderung hinzugefuegt — Henning weiss nicht was sie bedeuten
2. **Phrase-Mismatch + fehlende Indizierung:** Siri erkennt die Phrase nicht (zu strict, nicht indiziert, oder falscher App-Name)
3. Die eigentliche Funktionalitaet (Intents) ist moeglicherweise korrekt implementiert, aber Siri erreicht sie nicht

## Vorgeschlagene Loesung

### Option A: SiriTipViews komplett entfernen (EMPFOHLEN)

Da Henning die SiriTipViews nie angefordert hat und sie Verwirrung stiften:
1. SiriTipView aus ContentView.swift entfernen
2. SiriTipView + Section aus SettingsView.swift entfernen
3. `import AppIntents` aus ContentView entfernen (wenn nicht anderweitig benoetigt)

Die Intents selbst (Siri-Kommandos) bleiben bestehen — sie funktionieren unabhaengig von SiriTipViews. SiriTipViews sind nur UI-Elemente die dem User die Existenz der Shortcuts zeigen.

### Option B: Zusaetzlich Intent-Funktionalitaet debuggen

Wenn Henning will dass Siri-Kommandos funktionieren:
1. Phrases ueberpruefen (mehr Varianten hinzufuegen?)
2. Error Handling in Intents verbessern
3. Tests fuer CountOpenTasksIntent schreiben
4. Auf Device testen ob Siri die Shortcuts erkennt

## Blast Radius

- Entfernung der SiriTipViews: **2 Dateien** (ContentView, SettingsView), **minimal**
- Die eigentlichen Intents (Siri-Kommandos) bleiben erhalten
- Watch App, Share Extension, Control Center Widget: nicht betroffen
