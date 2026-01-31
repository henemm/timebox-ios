# Edit Redesign Spec

> **Status:** Spec Ready
> **Priorität:** Hoch
> **Bereich:** BacklogRow, TaskFormSheet

---

## Übersicht

Das Edit-System wird vereinfacht und visuell vereinheitlicht:

1. **Inline Edit entfernen** - Die aktuelle Expansion mit Duration-Buttons wird entfernt
2. **Doppel-Tap Titel-Edit** - Nur der Titel wird inline editierbar
3. **Full Edit im Backlog-Style** - Chips statt Picker, gleicher Look wie BacklogRow Badges

---

## Anforderungen

### 1. Inline Edit Entfernen (BacklogRow)

**Aktueller Zustand:**
- Single-Tap auf Row → `isExpanded.toggle()` → zeigt `inlineEditSection`
- `inlineEditSection` enthält: TextField + Duration-Buttons + Cancel/Save

**Neuer Zustand:**
- Single-Tap auf Row → Keine Expansion mehr
- `isExpanded` State entfernen
- `inlineEditSection` komplett entfernen
- `onSaveInline` Callback entfernen

### 2. Doppel-Tap Titel-Edit (BacklogRow)

**Neues Verhalten:**
- Doppel-Tap auf `titleView` → Inline TextField für Titel
- Nur Titel editierbar (keine Duration, keine anderen Felder)
- Enter/Return → Speichern
- Tap außerhalb → Speichern (Focus-Loss = Save)
- Kein Abbrechen-Button nötig

**Implementation:**
```swift
@State private var isEditingTitle = false
@FocusState private var titleFieldFocused: Bool

// In titleView:
if isEditingTitle {
    TextField("Titel", text: $editableTitle)
        .focused($titleFieldFocused)
        .onSubmit { saveTitle() }
        .onChange(of: titleFieldFocused) { _, focused in
            if !focused { saveTitle() }
        }
} else {
    Text(item.title)
        .onTapGesture(count: 2) {
            editableTitle = item.title
            isEditingTitle = true
            titleFieldFocused = true
        }
}
```

**Neuer Callback:**
```swift
var onTitleSave: ((String) -> Void)?
```

### 3. Full Edit Sheet im Backlog-Style (TaskFormSheet)

**Änderungen an TaskFormSheet:**

#### 3.1 Urgency: Flammen-Toggle statt Segmented Picker

**Aktuell (Zeile 119-131):**
```swift
Picker("Dringlichkeit", selection: $urgency)
    .pickerStyle(.segmented)
```

**Neu:** Wie `urgencyBadge` in BacklogRow
```swift
Button {
    urgency = (urgency == "urgent") ? "not_urgent" : "urgent"
} label: {
    HStack(spacing: 8) {
        Image(systemName: urgency == "urgent" ? "flame.fill" : "flame")
            .font(.system(size: 20))
            .foregroundStyle(urgency == "urgent" ? .orange : .gray)
        Text(urgency == "urgent" ? "Dringend" : "Nicht dringend")
            .foregroundStyle(urgency == "urgent" ? .orange : .secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
        RoundedRectangle(cornerRadius: 10)
            .fill(urgency == "urgent" ? .orange.opacity(0.2) : Color(.secondarySystemFill))
    )
}
```

#### 3.2 Task Type: Chip-Row statt Grid

**Aktuell (Zeile 134-162):**
```swift
LazyVGrid(columns: [...]) {
    ForEach(taskTypeOptions, ...) { ... }
}
```

**Neu:** Horizontale ScrollView mit Chips wie `categoryBadge`
```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 8) {
        ForEach(taskTypeOptions, id: \.0) { value, label, icon in
            Button {
                taskType = value
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                    Text(label)
                }
                .font(.caption)
                .foregroundStyle(categoryColor(for: value))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor(for: value).opacity(taskType == value ? 0.3 : 0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(taskType == value ? categoryColor(for: value) : .clear, lineWidth: 2)
                )
            }
        }
    }
}
```

**Farben (aus BacklogRow übernehmen):**
```swift
private func categoryColor(for type: String) -> Color {
    switch type {
    case "income": return .green
    case "maintenance": return .orange
    case "recharge": return .cyan
    case "learning": return .purple
    case "giving_back": return .pink
    default: return .gray
    }
}
```

---

## Betroffene Dateien

| Datei | Änderung | LoC |
|-------|----------|-----|
| `BacklogRow.swift` | Inline Edit entfernen, Doppel-Tap hinzufügen | -60, +40 |
| `TaskFormSheet.swift` | Urgency + Type als Chips | ~+30 (netto) |
| `BacklogView.swift` | `onSaveInline` Callbacks entfernen, `onTitleSave` hinzufügen | -20, +10 |

**Geschätzt:** 3-4 Dateien, ca. -40 LoC netto

---

## Acceptance Criteria

### AC1: Inline Edit entfernt
- [ ] Single-Tap auf BacklogRow hat keine Expansion mehr
- [ ] `inlineEditSection` existiert nicht mehr
- [ ] `isExpanded` State existiert nicht mehr

### AC2: Doppel-Tap Titel-Edit funktioniert
- [ ] Doppel-Tap auf Titel aktiviert TextField
- [ ] Enter speichert und beendet Edit
- [ ] Tap außerhalb speichert und beendet Edit
- [ ] Titel wird persistiert

### AC3: Full Edit Sheet hat Backlog-Style
- [ ] Urgency ist Flammen-Toggle (nicht Segmented Picker)
- [ ] Task Type ist horizontale Chip-Row (nicht Grid)
- [ ] Chips haben gleiche Farben wie BacklogRow Badges

---

## UI Tests (für TDD RED)

```swift
// BacklogRowEditTests.swift

func testDoubleTapTitleActivatesInlineEdit() {
    // Doppel-Tap auf Titel
    // TextField erscheint
    // Text ist editierbar
}

func testEnterSavesTitleEdit() {
    // Doppel-Tap → Edit
    // Text ändern
    // Enter drücken
    // Edit-Modus beendet, neuer Titel sichtbar
}

func testTapOutsideSavesTitleEdit() {
    // Doppel-Tap → Edit
    // Text ändern
    // Tap außerhalb
    // Edit-Modus beendet, neuer Titel sichtbar
}

func testSingleTapDoesNotExpand() {
    // Single-Tap auf Row
    // Keine Expansion (keine Duration-Buttons sichtbar)
}

// TaskFormSheetChipsTests.swift

func testUrgencyIsFlameToggle() {
    // Full Edit öffnen
    // Flame-Icon vorhanden
    // Tap togglet zwischen urgent/not_urgent
}

func testTaskTypeIsChipRow() {
    // Full Edit öffnen
    // Horizontale Chip-Row für Type
    // Chips haben korrekte Farben
}
```

---

## Risiken & Mitigations

| Risiko | Mitigation |
|--------|------------|
| Doppel-Tap kollidiert mit Single-Tap | Doppel-Tap nur auf `titleView`, nicht ganze Row |
| Focus-Loss speichert versehentlich | Standard iOS Verhalten, User erwartet das |

---

## Out of Scope

- EditTaskSheet.swift Konsolidierung (separates Ticket)
- Neue Felder im Full Edit Sheet
- Design-Änderungen an anderen Komponenten

---

*Spec erstellt: 2026-01-31*
