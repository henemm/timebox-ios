# Context: RW_1.1 Quick Dump

## Request Summary
Neues Feld `lifecycleStatus` auf `LocalTask` (Enum: raw/refined/active). Bestehende Tasks migrieren zu `.active`. Quick Capture setzt `.raw`, Backlog filtert `.raw` raus.

## Related Files

| File | Relevance |
|------|-----------|
| `Sources/Models/LocalTask.swift` | + `TaskLifecycleStatus` Enum, + `lifecycleStatus` Property |
| `Sources/Models/PlanItem.swift` | + `lifecycleStatus` Property uebernehmen |
| `Sources/Services/TaskSources/LocalTaskSource.swift` | `createTask()` — muss `lifecycleStatus` Parameter bekommen |
| `Sources/Services/SyncEngine.swift` | `sync()` → `fetchIncompleteTasks()` → Filter-Kette, muss `.raw` ausfiltern |
| `Sources/Protocols/TaskSource.swift` | `TaskSourceData` + `TaskSourceWritable` — Protocol-Erweiterung |
| `Sources/Views/QuickCaptureView.swift` | `saveTask()` setzt `.raw` statt `.active` |
| `Sources/Views/BacklogView.swift` | Filtert auf `planItems` — muss `.raw` ausschliessen |
| `FocusBloxMac/QuickCapturePanel.swift` | macOS Quick Capture — `addTask()` setzt `.raw` |
| `Sources/Intents/CreateTaskIntent.swift` | Siri Task-Erstellung — setzt `.raw` |
| `FocusBloxShareExtension/ShareViewController.swift` | iOS Share Extension — setzt `.raw` |
| `FocusBloxMacShareExtension/ShareViewController.swift` | macOS Share Extension — setzt `.raw` |
| `FocusBloxWatch Watch App/VoiceInputSheet.swift` | watchOS Voice Input — setzt `.raw` (bypasses LocalTaskSource) |

## Existing Patterns

- **Property-Defaults:** Alle LocalTask-Properties haben CloudKit-kompatible Defaults (`= ""`, `= false`, `= 0`)
- **String-backed Enums:** `urgency` und `taskType` sind als `String` gespeichert, nicht als Enum (CloudKit-Kompatibilitaet). `lifecycleStatus` sollte dem gleichen Pattern folgen: `String`-Property + Enum mit `rawValue`
- **isVisibleInBacklog:** Computed Property auf LocalTask filtert Recurring-Tasks. Neuer Filter `lifecycleStatus == .raw` kann entweder dort oder in `fetchIncompleteTasks()` integriert werden
- **PlanItem:** Ist ein Value-Type-Mirror von LocalTask. Muss `lifecycleStatus` ebenfalls tragen
- **Keine SwiftData-Migration:** Codebase hat KEINE VersionedSchema/SchemaMigrationPlan. Neue Properties mit Default-Werten werden von SwiftData automatisch gehandhabt (Lightweight Migration)

## Dependencies

**Upstream:**
- SwiftData Schema (automatische Lightweight Migration bei neuen Properties mit Default)
- CloudKit Sync (neues Feld muss Default haben fuer CloudKit-Kompatibilitaet)

**Downstream:**
- Story 1.3 (The Refiner) benoetigt `lifecycleStatus` zum Filtern von `.raw`-Tasks
- Story 2.4 (Backlog UX Rework) baut auf dem Filter auf

## Entry Points fuer Task-Erstellung (alle muessen `.raw` setzen)

1. `LocalTaskSource.createTask()` — Parameter hinzufuegen (default: `.active` fuer Rueckwaerts-Kompatibilitaet)
2. `QuickCaptureView.saveTask()` — iOS Quick Capture → `.raw`
3. `QuickCapturePanel.addTask()` — macOS Quick Capture → `.raw`
4. `CreateTaskIntent.perform()` — Siri → `.raw`
5. `ShareViewController.saveTask()` — iOS Share Extension → `.raw`
6. `MacShareSheetView.saveTask()` — macOS Share Extension → `.raw`
7. `VoiceInputSheet` (watchOS) — direkte LocalTask-Erstellung → `.raw`
8. `TaskFormSheet` — Vollstaendiges Formular → `.active` (bewusste Erstellung mit allen Feldern)

## Existing Specs

- `docs/specs/rework/1.1-quick-dump.md` — Story Spec
- `docs/specs/rework/1.3-the-refiner.md` — Abhaengige Story (nutzt `.raw`-Filter)

## Risks & Considerations

1. **CloudKit-Kompatibilitaet:** Neues Feld braucht String-Default (`"active"`), damit bestehende CloudKit-Records migrieren
2. **Share Extensions:** Haben eigene ModelContainer-Instanzen — kein Zugriff auf LocalTaskSource. Setzen `lifecycleStatus` direkt auf LocalTask
3. **watchOS VoiceInputSheet:** Bypassed `LocalTaskSource.createTask()` — muss direkt `.raw` setzen
4. **BacklogView-Filter:** Aktuell filtert `fetchIncompleteTasks()` nur auf `isVisibleInBacklog`. Neuer Filter muss `.raw` ausschliessen
5. **Kein Refiner (Story 1.3) in diesem Ticket:** Tasks mit `.raw` werden erstellt, aber es gibt noch keinen Weg sie zu `.refined`/`.active` zu befoerdern. Fallback: TaskFormSheet-Bearbeitung setzt auf `.active`
6. **Tests:** SwiftData Lightweight Migration testet man am besten mit In-Memory-Container — bestehende Tasks bekommen automatisch den Default-Wert
