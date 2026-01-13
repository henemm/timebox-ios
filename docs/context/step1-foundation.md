# Context: Step 1 - Foundation

## Request Summary
Basis-Infrastruktur für TimeBox aufbauen: Xcode-Projekt, SwiftData Model, EventKit-Integration und SyncEngine.

## Scope (aus Projekt-Spec)

**Ziel:** Beweisen, dass wir Reminders lesen und mit lokalen SortOrders verknüpfen können.

**Komponenten:**
1. Xcode-Projekt mit SwiftUI App
2. `TaskMetadata` - SwiftData Model
3. `PlanItem` - View Model (nicht persistent)
4. `EventKitRepository` - Apple EventKit Integration
5. `SyncEngine` - Merge-Logik
6. Debug-Output in Console

**Explizit NICHT in Scope:**
- UI Views (BacklogView, PlanningView)
- Drag & Drop
- Calendar Event Creation

## Technische Anforderungen

| Anforderung | Wert |
|-------------|------|
| iOS Minimum | 17.0 |
| Swift Version | 6 |
| UI Framework | SwiftUI |
| Architecture | MVVM + Repository |
| Data | SwiftData + EventKit |

## Dependencies

**Apple Frameworks:**
- SwiftUI
- SwiftData
- EventKit

**Permissions benötigt (Info.plist):**
- `NSRemindersUsageDescription`
- `NSCalendarsUsageDescription` (für später)

## Risiken & Considerations

1. **EventKit Permissions:** Müssen korrekt angefragt werden
2. **Reminder Sync:** Orphaned Metadata bei gelöschten Reminders
3. **Swift 6 Concurrency:** Strict concurrency checking beachten

## Zu erstellende Entities

| Entity | Typ | Spec benötigt |
|--------|-----|---------------|
| TaskMetadata | SwiftData Model | Ja |
| PlanItem | View Model | Ja |
| EventKitRepository | Service | Ja |
| SyncEngine | Service | Ja |
