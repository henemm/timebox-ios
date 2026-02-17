# Feature: Long Press Preview fuer Next Up Tasks (iOS)

## Zusammenfassung

Next Up Tasks zeigen den Titel mit `.lineLimit(1)` - bei laengeren Titeln wird er abgeschnitten und ist kaum lesbar. Ein Long Press soll ein Preview-Popup mit vollem Titel und Task-Attributen anzeigen (mit haptischem Feedback).

---

## Ist-Zustand

### NextUpRow (`Sources/Views/NextUpSection.swift:62-101`)

```swift
struct NextUpRow: View {
    let task: PlanItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(.blue).frame(width: 6, height: 6)
            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)           // ← Titel wird abgeschnitten
            Spacer()
            Text("\(task.effectiveDuration) min")
            // X-Button zum Entfernen
        }
    }
}
```

**Problem:**
- Titel mit `.lineLimit(1)` ist bei laengeren Tasks nicht lesbar
- Keine Moeglichkeit, Details zu sehen ohne den Task im Backlog zu suchen
- Kein Long Press / Context Menu vorhanden

---

## Soll-Zustand

### Long Press zeigt Preview-Popup

Beim Long Press auf eine `NextUpRow` erscheint ein natives iOS Context Menu Preview mit:

```
┌─────────────────────────────┐
│                             │
│  Meeting mit dem Team       │  ← voller Titel (kein lineLimit)
│  vorbereiten und Agenda     │
│  aufsetzen                  │
│                             │
│  📁 Maintenance  ⏱ 30 min  │  ← Kategorie + Dauer
│  ⚡ Hoch  🔴 Dringend       │  ← Importance + Urgency
│  🏷 #meeting #team          │  ← Tags (falls vorhanden)
│  📅 Fällig: 17.02.         │  ← Due Date (falls vorhanden)
│                             │
├─────────────────────────────┤
│  ✕ Aus Next Up entfernen    │  ← Context Menu Action
└─────────────────────────────┘
```

### Technischer Ansatz: `.contextMenu` mit `preview`

SwiftUI bietet `.contextMenu(menuItems:preview:)` - zeigt beim Long Press ein Custom Preview mit haptischem Feedback (iOS-nativ, kein manueller Haptic-Code noetig).

```swift
NextUpRow(task: task) { onRemoveFromNextUp(task.id) }
    .contextMenu {
        Button(role: .destructive) {
            onRemoveFromNextUp(task.id)
        } label: {
            Label("Aus Next Up entfernen", systemImage: "xmark.circle")
        }
    } preview: {
        NextUpPreview(task: task)
    }
```

### Preview-View (neue View)

```swift
struct NextUpPreview: View {
    let task: PlanItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Voller Titel
            Text(task.title)
                .font(.headline)

            // Beschreibung (falls vorhanden)
            if let desc = task.taskDescription, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Attribute-Chips
            HStack(spacing: 8) {
                if !task.taskType.isEmpty {
                    Label(TaskCategory(rawValue: task.taskType)?.displayName ?? task.taskType,
                          systemImage: TaskCategory(rawValue: task.taskType)?.icon ?? "folder")
                }
                Label("\(task.effectiveDuration) min", systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Importance + Urgency
            HStack(spacing: 8) {
                if let imp = task.importance {
                    Label(TaskPriority(rawValue: imp)?.displayName ?? "",
                          systemImage: "exclamationmark.triangle")
                }
                if let urg = task.urgency {
                    Label(urg == "urgent" ? "Dringend" : "Nicht dringend",
                          systemImage: urg == "urgent" ? "bolt.fill" : "bolt")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Tags
            if !task.tags.isEmpty {
                Text(task.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            // Due Date
            if let due = task.dueDate {
                Label(due.formatted(.dateTime.day().month()),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(due < Date() ? .red : .secondary)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
```

---

## Technischer Plan

### Dateien (1 Datei, ~50 LoC)

| Datei | Aenderung | LoC |
|-------|-----------|-----|
| `Sources/Views/NextUpSection.swift` | `NextUpPreview` View + `.contextMenu(preview:)` auf NextUpRow | ~50 LoC |

### Kein neues File noetig

`NextUpPreview` kann direkt in `NextUpSection.swift` als private View leben (wie `NextUpChip` bereits dort liegt).

### Aenderungen an NextUpSection

1. **NextUpRow** bekommt `.contextMenu(menuItems:preview:)` Modifier
2. **Neue View** `NextUpPreview` zeigt volle Task-Details
3. **Context Menu Action:** "Aus Next Up entfernen" (gleiche Aktion wie X-Button)

---

## Abgrenzung (Out of Scope)

- Keine Aenderung auf macOS (macOS hat Hover-Tooltips / Inspector-Panel)
- Kein Oeffnen einer Detail-Sheet aus dem Preview (Phase 2)
- Keine Drag-aus-Preview Geste
- Keine Aenderung am bestehenden X-Button (bleibt fuer Quick-Remove)
- Kein Edit aus dem Context Menu (Phase 2)

---

## Acceptance Criteria

1. Long Press auf NextUpRow zeigt Preview-Popup mit haptischem Feedback
2. Preview zeigt vollen Titel (kein lineLimit)
3. Preview zeigt Kategorie und Dauer
4. Preview zeigt Importance und Urgency (falls gesetzt)
5. Preview zeigt Tags (falls vorhanden)
6. Preview zeigt Due Date (falls vorhanden, rot wenn ueberfaellig)
7. Context Menu bietet "Aus Next Up entfernen" Action
8. Bestehender X-Button funktioniert weiterhin

---

## Geschaetzter Aufwand

**KLEIN** (~10-15k Tokens, 1 Datei, ~50 LoC)

Nativer `.contextMenu(preview:)` Modifier + eine neue Preview-View. Kein neuer State, keine neuen Services.
