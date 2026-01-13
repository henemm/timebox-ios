# Spec: Step 2 - BacklogView

**Status:** Draft
**Workflow:** step2-backlogview
**Created:** 2026-01-13

---

## 1. Ziel

Sortierbare Liste aller Tasks mit Drag & Drop Reordering. Benutzer kann Tasks priorisieren durch Verschieben.

---

## 2. Komponenten

### 2.1 BacklogView

**Zweck:** Hauptview mit sortierbarer Liste.

```swift
struct BacklogView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var planItems: [PlanItem] = []
    @State private var draggedItem: PlanItem?

    var body: some View {
        NavigationStack {
            List {
                ForEach(planItems) { item in
                    BacklogRow(item: item)
                }
                .onMove(perform: moveItems)
            }
            .listStyle(.plain)
            .navigationTitle("Backlog")
            .toolbar {
                EditButton()
            }
        }
    }
}
```

**Verhalten:**
- Lädt PlanItems beim Erscheinen via SyncEngine
- Drag & Drop über `.onMove`
- Speichert neue Reihenfolge sofort in SwiftData

---

### 2.2 BacklogRow

**Zweck:** Einzelne Zeile mit Titel und Duration Badge.

```swift
struct BacklogRow: View {
    let item: PlanItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.body)
            }
            Spacer()
            DurationBadge(minutes: item.effectiveDuration, isDefault: item.durationSource == .default)
        }
    }
}
```

---

### 2.3 DurationBadge

**Zweck:** Kapsel-Badge für Dauer. Gelb wenn Default (15min).

```swift
struct DurationBadge: View {
    let minutes: Int
    let isDefault: Bool

    var body: some View {
        Text("\(minutes)m")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isDefault ? .yellow.opacity(0.3) : .blue.opacity(0.2))
            .clipShape(Capsule())
    }
}
```

---

### 2.4 SyncEngine Erweiterung

**Neue Funktion:** `reorder(from:to:)`

```swift
func reorder(from source: IndexSet, to destination: Int, items: inout [PlanItem]) throws {
    items.move(fromOffsets: source, toOffset: destination)

    // Update sortOrder for all items
    for (index, item) in items.enumerated() {
        if let metadata = try findMetadata(for: item.id) {
            metadata.sortOrder = index
        }
    }

    try modelContext.save()
}
```

---

## 3. PlanItem Anpassung

**durationSource** muss korrekt berechnet werden:

```swift
var durationSource: DurationSource {
    if manualDuration != nil {
        return .manual
    }
    if Self.parseDurationFromTitle(title) != nil {
        return .parsed
    }
    return .default
}
```

---

## 4. Haptisches Feedback

Bei erfolgreichem Drop:

```swift
.sensoryFeedback(.impact(weight: .medium), trigger: reorderTrigger)
```

---

## 5. Dateien

| Datei | Aktion | LoC (ca.) |
|-------|--------|-----------|
| Views/BacklogView.swift | Neu | 60 |
| Views/BacklogRow.swift | Neu | 25 |
| Views/DurationBadge.swift | Neu | 20 |
| Models/PlanItem.swift | Ändern | +10 |
| Services/SyncEngine.swift | Ändern | +15 |
| ContentView.swift | Ändern | -30 |

**Gesamt:** 3 neue, 3 geändert, ~130 LoC netto

---

## 6. Test-Szenario

1. App starten
2. Mindestens 3 Reminders sollten sichtbar sein
3. Edit-Modus aktivieren (Edit Button)
4. Task von Position 2 nach Position 0 ziehen
5. **Erwartung:**
   - Task ist an neuer Position
   - Haptisches Feedback
   - Nach App-Neustart: Reihenfolge bleibt
