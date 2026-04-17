# Bug-Analyse: CloudKit doppelte UUIDs (#255)

## User-Erwartung
User synchronisiert Aufgaben zwischen Geräten. Beim Tagesrückblick crasht die App. User hat nichts falsch gemacht, verliert Vertrauen.

## Status
Der CRASH ist bereits gefixt (Commit 7eb4495): Alle 4 `Dictionary(uniqueKeysWithValues:)` Stellen im Produktionscode wurden auf `uniquingKeysWith:` umgestellt. Kein Crash mehr bei Duplikaten.

Die ROOT CAUSE (Duplikate im Store) ist NICHT gefixt. Duplikate existieren weiterhin, verursachen aber keine Crashes mehr.

## Root Cause
CloudKit-Sync kann zwei LocalTask-Objekte mit identischer UUID im Store erzeugen:
- LocalTask.uuid hat kein @Attribute(.unique) — SwiftData/CloudKit unterstützt das nicht
- NSPersistentCloudKitContainer mergt nach persistentModelID, nicht nach app-definierter UUID
- Kein UUID-Dedup beim Startup (nur externalID-Dedup und Template-Dedup existieren)

## Szenarien für Duplikate
1. CloudKit-Sync: Record wird auf 2 Geräten importiert (HAUPTVERDÄCHTIGER)
2. Watch-App als paralleler Schreiber in denselben Container
3. Migration entfernt externalID → Dedup greift nicht mehr

## Fix-Empfehlung
Startup-Cleanup `cleanupUUIDDuplicates()` analog zu bestehendem `cleanupRemindersDuplicates()`:
- Alle LocalTasks nach UUID gruppieren
- Bei Duplikaten: älteren behalten, jüngeren löschen
- ~30 LoC, kein Schema-Migration nötig
