# Bug-Analyse: Day-Review nicht spezifisch genug

## Symptom
Der Abend-Text im "Mein Tag"-Tab ist zu generisch. Er hebt nicht hervor, was zur Tages-Intention passt. Zu viel allgemeines "Bla bla".

## Agenten-Ergebnisse Zusammenfassung

### Agent 1 (History): Keine bisherigen Beschwerden zu generischen Texten. Feature erst seit 2 Tagen live.
### Agent 2 (Datenfluss): Intention wird im Prompt NAMENTLICH erwaehnt, aber Tasks werden UNGEFILTERT uebergeben.
### Agent 3 (Schreiber): buildPrompt() Zeile 104 holt ALLE erledigten Tasks, keine Discipline-Filterung.
### Agent 4 (Szenarien): 6 Szenarien identifiziert — Hauptproblem: Tasks nicht nach Intention-Relevanz gefiltert + keine intention-spezifischen Prompt-Anweisungen.
### Agent 5 (Blast Radius): macOS hat KEINEN Abend-Spiegel. MacReviewView ignoriert Coach-Features komplett.

---

## Hypothesen

### Hypothese 1: Tasks werden NICHT nach Intention-Relevanz gefiltert (HOCH)

**Beweis DAFUER:**
- `buildPrompt()` (EveningReflectionTextService.swift:104) ruft `completedToday()` auf
- `completedToday()` (IntentionEvaluationService.swift:190-196) filtert NUR nach Datum, NICHT nach Discipline
- Wenn User "BHAG" waehlt und 10 Tasks erledigt (1x importance=3, 9x Admin), bekommt die AI die ersten 5 Tasks — moeglicherweise OHNE den BHAG-Task
- Die AI hat keine Chance den BHAG-Task hervorzuheben wenn er gar nicht im Prompt ist

**Beweis DAGEGEN:**
- Die Intention wird namentlich im Prompt erwaehnt (Zeile 110)
- importance=3 Tasks bekommen "[Wichtigkeit: hoch]" Marker (Zeile 117)
- Die AI KOENNTE theoretisch daraus schliessen — aber nur wenn der Task ueberhaupt in den Top 5 ist

**Wahrscheinlichkeit:** HOCH

---

### Hypothese 2: System-Prompt gibt keine intention-spezifischen Anweisungen (HOCH)

**Beweis DAFUER:**
- System-Prompt (Zeile 147-157): "Schreib 2-3 persoenliche Saetze ueber seinen heutigen Tag"
- KEINE Anweisung wie: "Fokussiere dich auf Tasks die zur Intention passen"
- KEINE Anweisung wie: "Bei BHAG-Intention: Betone den wichtigsten Task"
- KEINE Anweisung wie: "Bei Fokus-Intention: Kommentiere ob Tasks in Blocks waren"
- Die AI weiss nicht WIE sie die Intention-Info interpretieren soll

**Beweis DAGEGEN:**
- Die Intention steht im User-Prompt, ein gutes Sprachmodell koennte das selbst ableiten
- Foundation Models (Apple Intelligence) sind aber weniger leistungsfaehig als grosse Cloud-Modelle

**Wahrscheinlichkeit:** HOCH

---

### Hypothese 3: Fallback-Templates sind zu generisch (MITTEL)

**Beweis DAFUER:**
- fallbackTemplate() (IntentionEvaluationService.swift:166-185) liefert 1-Satz-Templates
- "Du bist bei der Sache geblieben. Stark." — kein Bezug zu konkreten Tasks
- Werden angezeigt wenn AI nicht verfuegbar oder AI disabled

**Beweis DAGEGEN:**
- Fallback-Templates SIND bereits pro Intention unterschiedlich (18 Varianten)
- Sie sind BEWUSST kurz und statisch — als Fallback gedacht, nicht als Haupterlebnis
- Auf iOS 26+ sollte normalerweise der AI-Text erscheinen, nicht der Fallback

**Wahrscheinlichkeit:** MITTEL (relevant fuer aeltere Geraete oder wenn AI deaktiviert)

---

### Hypothese 4: macOS hat gar keinen Abend-Spiegel (HOCH — separates Problem)

**Beweis DAFUER:**
- MacReviewView.swift hat 0 Referenzen zu EveningReflectionCard
- Kein Import von EveningReflectionTextService
- Kein Coach-Mode-Toggle im Tab-Label ("Review" statt "Mein Tag")
- macOS zeigt NUR Stats (Completion Ring, Category Time, Planning Accuracy)

**Beweis DAGEGEN:**
- Keiner. Feature fehlt komplett.

**Wahrscheinlichkeit:** SICHER (aber separates Ticket empfohlen)

---

## Wahrscheinlichste Ursache(n)

**Kombination von Hypothese 1 + 2:**

Der Abend-Text ist generisch weil:
1. **Tasks nicht priorisiert/gefiltert werden:** ALLE erledigten Tasks fliessen gleich in den Prompt, statt die zur Intention passenden hervorzuheben
2. **Die AI keine intention-spezifischen Anweisungen bekommt:** Sie weiss nicht, WORAUF sie sich fokussieren soll

**Warum die anderen weniger wahrscheinlich:**
- H3 (Fallback-Templates): Auf iOS 26+ Geraeten sollte AI-Text erscheinen. Aber: Falls AI-Text auch generisch ist, liegt es an H1+H2, nicht an Templates.
- H4 (macOS fehlt): Echt, aber ein separates Feature-Ticket. Nicht der Grund warum der iOS-Text generisch ist.

---

## Debugging-Plan

### Bestaetigung von H1+H2:
- **Logging in buildPrompt():** Ausgeben WELCHE Tasks in den Prompt fliessen. Pruefe: Sind intentionsrelevante Tasks dabei oder nur zufaellige Top-5?
- **Logging des AI-Outputs:** Was generiert die AI mit dem aktuellen Prompt?
- **Plattform:** iOS (macOS hat das Feature nicht)

### Widerlegung:
- Wenn der Prompt IMMER die relevanten Tasks enthaelt UND die AI trotzdem generisch antwortet → Problem liegt bei Apple Intelligence, nicht bei unserem Code.

---

## Blast Radius

### Direkt betroffen:
- EveningReflectionTextService.buildPrompt() — Kern-Aenderung
- System-Prompt in performGeneration() — Anweisungen anpassen

### Indirekt betroffen:
- GetEveningSummaryIntent (Siri) — nutzt nur fallbackTemplate(), kein AI
- EveningReflectionCard — keine Aenderung noetig (zeigt nur an was kommt)

### Separates Ticket:
- macOS Review-Paritaet (MacReviewView hat kein Coach-Feature)
- Siri Intent koennte auch spezifischere Texte nutzen

---

### Hypothese 5: @Guide-Beschreibung ist intentionsblind (HOCH — vom Challenger)

**Beweis DAFUER:**
- @Guide (EveningReflectionTextService.swift:30): "2-3 persoenliche Saetze ueber den Tag des Users"
- KEIN Bezug zur Intention im @Guide — und bei Apple Intelligence steuert der @Guide den Output staerker als der System-Prompt
- Foundation Models (On-Device) sind schwaecher als Cloud-Modelle — sie brauchen explizitere Constraints

**Beweis DAGEGEN:**
- System-Prompt sagt "Bezieh dich auf konkrete Task-Titel" — aber das ist nicht dasselbe wie "bezieh dich auf die Intention"

**Wahrscheinlichkeit:** HOCH (moeglicherweise der einfachste Fix)

---

### Hypothese 6: Silent Fallback — AI laeuft gar nicht (MITTEL — vom Challenger)

**Beweis DAFUER:**
- performGeneration() hat einen catch-Block (Zeile 176) der nur `print()` macht — kein Retry, kein User-Feedback
- Wenn Foundation Models nicht verfuegbar/ueberlastet: aiReflectionTexts bleibt `[:]` → Card zeigt IMMER Fallback
- Es gibt KEIN Logging das beweist dass die AI jemals erfolgreich Text generiert hat

**Beweis DAGEGEN:**
- Auf iOS 26.2 sollte Foundation Models verfuegbar sein
- 11 Unit Tests fuer den Service sind gruen

**Wahrscheinlichkeit:** MITTEL — muesste per Logging verifiziert werden

---

## Wahrscheinlichste Ursache(n) (aktualisiert nach Challenge)

**Kombination von H1 + H2 + H5:**

1. **Tasks nicht nach Relevanz sortiert** (H1): `.prefix(5)` ohne Sortierung = zufaellige Tasks
2. **Keine intention-spezifischen Prompt-Anweisungen** (H2): AI weiss nicht WORAUF sie achten soll
3. **@Guide ist intentionsblind** (H5): Der staerkste Constraint fuer Apple Intelligence erwaehnt die Intention nicht

**Offene Frage (H6):** Laeuft die AI ueberhaupt oder sieht Henning immer den Fallback? Muesste per Logging geklaert werden.

---

## Debugging-Plan

### Bestaetigung von H1+H2+H5:
- **Logging in buildPrompt():** Welche Tasks fliessen in den Prompt? Sind relevante dabei?
- **Logging in performGeneration():** Wird die AI aufgerufen? Was kommt zurueck?
- **Plattform:** iOS

### Widerlegung von H6:
- **Logging nach generateTexts():** Ist das Dict leer oder befuellt?
- Wenn IMMER leer → Problem ist Foundation Models Verfuegbarkeit, nicht Prompt-Qualitaet

---

## Blast Radius

### Direkt betroffen:
- EveningReflectionTextService.buildPrompt() — Tasks nach Relevanz sortieren
- EveningReflectionTextService.performGeneration() — System-Prompt + @Guide anpassen

### Indirekt betroffen:
- GetEveningSummaryIntent (Siri) — nutzt nur fallbackTemplate(), kein AI
- EveningReflectionCard — keine Aenderung noetig (zeigt nur an was kommt)

### Separates Ticket:
- macOS Review-Paritaet (MacReviewView hat kein Coach-Feature)
- Siri Intent koennte auch spezifischere Texte nutzen

---

## Fix-Ansatz (Vorschlag — 3 Massnahmen)

### 1. Tasks nach Intention-Relevanz SORTIEREN in buildPrompt()
Intentions-relevante Tasks ZUERST in den Prompt, dann Rest. Nicht blindes `.prefix(5)`.

| Intention | Relevante Tasks zuerst |
|-----------|----------------------|
| BHAG | importance == 3 |
| Fokus | assignedFocusBlockID != nil |
| Growth | taskType == "learning" |
| Connection | taskType == "giving_back" |
| Balance | Diverse taskTypes bevorzugen |
| Survival | Alle gleich |

Zusaetzlich: assignedFocusBlockID im Task-String erwaehnen (fuer Fokus-Intention).

### 2. @Guide UND System-Prompt intentionsspezifisch machen
- @Guide: "Bezogen auf die Intention [X] des Users" einbauen
- System-Prompt: Intention-spezifische Hints hinzufuegen
- FulfillmentLevel mit BEGRUENDUNG statt nur "Erfuellt/Nicht erfuellt"

### 3. (Separat) macOS Paritaet
MacReviewView braucht EveningReflectionCard — eigenes Ticket.
