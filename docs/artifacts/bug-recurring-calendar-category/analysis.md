# Bug-Analyse: Kategorie-Zuweisung bei wiederkehrenden Kalender-Events mit Gaesten

## Symptom
Wiederkehrende Kalender-Events mit Gaesten (z.B. Weekly Standup) koennen weder auf iOS noch macOS kategorisiert werden. Mindestens 3 Fix-Versuche sind gescheitert.

## Bisherige Fix-Versuche (3 Stueck)

### Versuch 1: Notes-basiert mit `.thisEvent` (Commit 0b0aaa0)
- Kategorie als `category:xxx` in `event.notes` gespeichert
- `.thisEvent` Span → nur aktuelle Occurrence betroffen
- **Gescheitert:** Events mit Gaesten sind read-only → `eventStore.save()` wirft Fehler

### Versuch 2: Try-Catch + iCloud KV Store Fallback (Commits 4a5eafe, ebae017)
- Bei Fehler: Fallback auf `NSUbiquitousKeyValueStore` mit Key `eventCat_{eventID}`
- **Teilweise gescheitert:** Funktioniert fuer einzelne Events mit Gaesten, aber nicht stabil fuer recurring

### Versuch 3: `.futureEvents` Span + explizite Read-Only-Erkennung (Commit dcc5b3a)
- `hasAttendees` wird explizit geprueft statt Error-basiert
- `.futureEvents` fuer recurring Events ohne Gaeste → funktioniert
- Recurring MIT Gaeste → weiterhin KV Store mit `eventIdentifier` als Key
- **Gescheitert:** Grundproblem nicht geloest

## Root-Cause-Analyse: 3 Hypothesen

### Hypothese 1: `eventStore.event(withIdentifier:)` gibt nil zurueck (HOCH)

**Code:** `EventKitRepository.swift:249`
```swift
guard let event = eventStore.event(withIdentifier: eventID) else {
    return // Silent fail if event not found
}
```

**Mechanismus:**
- `events(matching: predicate)` gibt Occurrences eines recurring Events zurueck
- Die `eventIdentifier` einer einzelnen Occurrence ist NICHT garantiert identisch mit dem Master-Event
- `eventStore.event(withIdentifier:)` gibt laut Apple-Doku "the first occurrence of an event" zurueck
- Wenn die Occurrence-ID nicht auf den Master mappt → `nil` → **stille Rueckkehr ohne Aktion**
- Kein Error wird geworfen → UI zeigt keinen Fehler → User denkt es hat funktioniert

**Beweis dafuer:**
- Die Methode hat keinen Return-Wert und wirft keinen Fehler bei `nil`
- In der UI wird nach dem Aufruf sofort `loadData()` aufgerufen → Events werden neu geladen
- Die Kategorie war nie gespeichert → nicht sichtbar

**Beweis dagegen:**
- Apple-Doku sagt `eventIdentifier` sollte fuer alle Occurrences gleich sein
- ABER: "A recurring event may also have different identifiers for each occurrence" (Apple-Doku)
- Verhalten haengt vom Calendar-Provider ab (iCloud vs Google vs Exchange)

### Hypothese 2: `eventIdentifier` aendert sich pro Occurrence (HOCH)

**Code:** `CalendarEvent.swift:16` und `CalendarEvent.swift:57`
```swift
// WRITE-Seite:
self.id = event.eventIdentifier  // Occurrence-spezifische ID

// READ-Seite:
return NSUbiquitousKeyValueStore.default.string(forKey: "eventCat_\(id)")
```

**Mechanismus:**
- Montag: User kategorisiert Event → KV Store: `eventCat_MON_ID = "income"`
- Dienstag: App laedt Occurrence → `self.id = TUE_ID` → KV Store Lookup: `eventCat_TUE_ID` → nicht gefunden
- Kategorie ist "verschwunden"

**Beweis dafuer:**
- Apple-Doku: "A recurring event may also have different identifiers for each occurrence"
- `calendarItemIdentifier` (stabil ueber alle Occurrences) wird NIRGENDS im Code verwendet
- Unterschiedliche Calendar-Provider (Google, Exchange) verhalten sich unterschiedlich

**Beweis dagegen:**
- Bei iCloud-Kalendern koennte `eventIdentifier` stabil sein
- Henning sagt es geht SOFORT nicht (nicht erst am naechsten Tag) → andere Ursache?

### Hypothese 3: Architektur-Problem — Notes-Feld ist der falsche Speicherort (MITTEL-HOCH)

**Problem:**
- EventKit hat KEINE Custom-Metadata-Felder
- `event.notes` ist user-sichtbar und wird vom Server ueberschrieben
- Events mit Gaesten sind generell read-only (organisator-seitig verwaltet)
- Kein Calendar-Provider garantiert, dass `notes` nach Sync erhalten bleibt

**Apple Best Practice:**
- Metadata in eigener lokaler Datenbank speichern (CoreData/SwiftData)
- Mapping: `calendarItemIdentifier` → Metadata
- `calendarItemIdentifier` ist stabil ueber ALLE Occurrences eines recurring Events
- KEIN Schreiben auf EventKit-Objekte fuer App-interne Daten

**Beweis dafuer:**
- 3 gescheiterte Versuche zeigen: EventKit-basierte Speicherung ist fragil
- Apple empfiehlt lokale Mappings statt Notes-Hacks
- `calendarItemIdentifier` existiert genau fuer diesen Zweck

## Wahrscheinlichste Ursache

**Kombination aus Hypothese 1 + 2 + 3:**

Das Grundproblem ist die gesamte Architektur. Notes-basierte Speicherung und KV-Store mit `eventIdentifier` sind beide fragil. Jeder Einzelfix adressiert nur ein Symptom.

**Best-Practice-Loesung (Hypothese 3):**
1. Kategorie-Mapping in **lokaler Datenbank** (UserDefaults Dict oder SwiftData) speichern
2. Key: `calendarItemIdentifier` (stabil ueber alle Occurrences)
3. **Kein Schreiben auf EventKit** — nur lokales Mapping
4. Funktioniert fuer ALLE Event-Typen: mit/ohne Gaeste, recurring/einmalig, read-only/editable

## Debugging-Plan (falls Verifizierung gewuenscht)

**Logging an 3 Stellen:**
1. `CalendarEvent.init(from:)` — logge `eventIdentifier` und `calendarItemIdentifier` fuer recurring Events
2. `updateEventCategory()` — logge ob `eventStore.event(withIdentifier:)` nil ist
3. `CalendarEvent.category` getter — logge ob Notes-Pfad oder KV-Store-Pfad genommen wird

**Erwartetes Ergebnis bei Hypothese 1:** Log zeigt `event(withIdentifier:) returned nil`
**Erwartetes Ergebnis bei Hypothese 2:** Log zeigt unterschiedliche IDs pro Occurrence

## Fix-Empfehlung: Lokales Kategorie-Mapping

### Ansatz
- **UserDefaults Dictionary** statt Notes oder KV Store
- Key: `calendarItemIdentifier` (nicht `eventIdentifier`!)
- Format: `[calendarItemIdentifier: categoryRawValue]`
- Funktioniert fuer ALLE Event-Typen ohne Unterscheidung

### Aenderungen (3 Dateien, ~40 LoC)

1. **CalendarEvent.swift:**
   - Neues Property: `calendarItemIdentifier` im init speichern
   - `category` getter: aus UserDefaults Dict lesen statt Notes/KV Store

2. **EventKitRepository.swift:**
   - `updateEventCategory()`: in UserDefaults Dict schreiben statt Notes/KV Store
   - Komplette isReadOnly-Logik + Notes-Manipulation + KV Store entfaellt

3. **Views (iOS + macOS):**
   - `calendarItemIdentifier` statt `id` beim Aufruf von `updateEventCategory()` uebergeben

### Vorteile
- Funktioniert fuer ALLE Event-Typen (mit/ohne Gaeste, recurring/einmalig)
- Keine EventKit-Schreibzugriffe noetig
- `calendarItemIdentifier` ist stabil ueber alle Occurrences
- Kein Sync-Delay, kein KV Store, keine Notes-Korruption
- Eliminiert 3 bisherige Fehlermuster

### Nachteil
- Kategorien nur auf diesem Geraet (kein Cross-Device Sync via Notes)
- Kann spaeter durch iCloud Sync ergaenzt werden (KV Store mit `calendarItemIdentifier` als Key)

## Blast Radius

- **12 Views** zeigen Kategorien an (iOS + macOS) — lesen alle `event.category`
- **ReviewStatsCalculator** aggregiert Minuten nach Kategorie
- **Andere Notes-Properties** (focusBlock, reminderID) sind NICHT betroffen (anderer Pfad)
- **Test-Files:** CalendarEventCategoryTests, CalendarEventReadOnlyTests, CalendarCategoryUITests, MacEventCategoryUITests

## Plattform-Check
- `EventKitRepository` ist Shared Code (Sources/) → Fix gilt fuer iOS UND macOS
- `CalendarEvent` ist Shared Code → Property-Aenderung gilt fuer beide
- Views (iOS + macOS) rufen identische Methode auf → beide profitieren
