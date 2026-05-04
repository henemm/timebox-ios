# Analyse: macOS zeigt alle Tasks doppelt

**Bug-ID:** bug-mac-duplicate-tasks
**Gemeldet:** 2026-05-04, Henning
**Plattform:** macOS Client (FocusBloxMac)

---

## Symptom (User-Sicht)

Beim Öffnen des Mac Clients erscheint jede Task exakt zweimal in der Liste — identische Titel, Tags, Energie, Dauer, Score. Auf iPhone-Verhalten unbekannt (offene Frage an Henning).

**User-Advocate-Sorge:** Henning weiß nicht, ob die Daten wirklich doppelt sind oder nur die Anzeige spinnt — und ob das auf iPhone auch so ist (Datenkorruption vs. Anzeigefehler).

## Hypothesen (alle gesammelten)

| # | Hypothese | Quelle | Bewertung |
|---|-----------|--------|-----------|
| H1 | **Echte DB-Duplikate durch CloudKit-Sync, weil macOS-Startup `cleanupUUIDDuplicates()` nicht aufruft** | Investigator 2, 3, 4, 5 (4 unabhängig) | **Sehr wahrscheinlich** — Beweis durch Code-Diff iOS vs. macOS klar |
| H2 | Anzeige-Bug durch ContentView-`macTierSection` + Geparkt-Filter doppelt rendern | Bug Intake Report | **Falsch** — Tier-Filter hat `!task.isParked`, Geparkt hat `isParked` — sind exklusiv |
| H3 | Reminders-Import (Commit `c83c9b0f`) erzeugt neue `recurrenceGroupID` und Migration dupliziert | Investigator 1, 3 | **Möglich aber nachrangig** — würde nur recurring Tasks treffen, nicht alle |
| H4 | `migrateToTemplateModel` + `repairOrphanedRecurringSeries` Race mit CloudKit | Investigator 3 | **Möglich aber nachrangig** — würde nur recurring Tasks treffen, nicht alle |

**Entscheidende Beobachtung:** Der Screenshot zeigt **alle** Tasks doppelt — auch Nicht-Recurring (z.B. "Termin für Hautkrebs-Früherkennungsuntersuchung machen", "Rote Fahrrad Schuhe..."). Das schließt H3/H4 als Hauptursache aus.

## Wahrscheinlichste Ursache

**macOS-App-Startup fehlt `cleanupUUIDDuplicates()` (und `cleanupRemindersDuplicates()`).**

### Code-Beweis

**iOS (`Sources/FocusBloxApp.swift:360-361`):**
```swift
Self.cleanupRemindersDuplicates(in: container.mainContext)
Self.cleanupUUIDDuplicates(in: container.mainContext)
```

**macOS (`FocusBloxMac/FocusBloxMacApp.swift:378-381`):**
```swift
RecurrenceService.deduplicateTemplates(in: container.mainContext)
RecurrenceService.deduplicateChildInstances(in: container.mainContext)
// ❌ cleanupUUIDDuplicates fehlt
// ❌ cleanupRemindersDuplicates fehlt
```

### Warum entstehen Duplikate?

`LocalTask` (`Sources/Models/LocalTask.swift:22`) hat **keinen `#Unique`-Constraint auf `uuid`**. CloudKit kann bei Sync-Konflikten denselben Record zweimal einspielen — iOS bereinigt das beim App-Start, macOS nicht. Vergleichbarer historischer Bug: Issue zu UUID-Duplikaten aus CloudKit-Sync (Commit `1bb9f2be`, `7a265839`).

### Warum jetzt aufgetreten?

Henning hat heute den Mac Client geöffnet. Wenn dieser längere Zeit nicht offen war, hat sich CloudKit-Drift zwischen iOS und macOS aufgebaut. Beim ersten Öffnen importiert macOS alle pending Records — die Cleanup-Funktion fehlt → Duplikate bleiben.

## Blast Radius

| Bereich | Betroffen? | Auswirkung |
|---------|-----------|-----------|
| Backlog-Liste (sichtbar im Screenshot) | Ja | Doppelte Anzeige |
| Sidebar-Badges (`doNowCount`, `completedCount`, `recurringCount`) | Ja | Verdoppelte Zahlen |
| Coach / Tagesbogen-Statistik | Ja | Verfälschte Empfehlungen |
| Streak / SuccessStory | Ja | Verdoppelte Erfolgs-Zahlen |
| iPhone (über CloudKit) | **Wahrscheinlich auch betroffen** | Sync teilt denselben Store |
| Reminders.app | Nein | One-way-Sync, kein Write-Back |
| Daten-Sicherheit | OK | Time Machine + CloudKit-Recovery vorhanden |

## Fix-Pfad (Vorschlag)

1. **`cleanupUUIDDuplicates()` in macOS-Startup-Block aufrufen** (analog iOS, in `FocusBloxMacApp.swift:378-381` ergänzen).
2. Ggf. `cleanupRemindersDuplicates()` ebenfalls.
3. Unit-Test: `cleanupUUIDDuplicates` mit zwei `LocalTask` gleicher UUID → genau 1 bleibt übrig.

**Scope:** ~2 Dateien (`FocusBloxMacApp.swift`, neuer Unit-Test), <30 LoC. Innerhalb Limits.

## Diagnose-Bestätigung (vor Fix)

Schneller Beweis ob H1 stimmt — ohne Code-Änderung:

```bash
find ~/Library/Group\ Containers/group.com.henning.focusblox -name "default.store"
sqlite3 <pfad> "SELECT ZTITLE, COUNT(*) FROM ZLOCALTASK GROUP BY ZUUID HAVING COUNT(*)>1 LIMIT 10;"
```

Wenn Output > 0 Zeilen: **H1 bestätigt** — echte DB-Duplikate.

## Offene Fragen an Henning

1. Sind die Tasks auf iPhone auch doppelt? (entscheidet ob Bug nur macOS-Anzeige oder DB-weit)
2. Soll die Diagnose-SQL-Abfrage zuerst laufen, oder direkt Fix implementieren?

---

**Status:** Analyse fertig, bereit für Checkpoint 1.
