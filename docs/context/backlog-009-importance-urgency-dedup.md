# Context: BACKLOG-009 - Importance/Urgency Badge-Logik

## Request Summary
`importanceSFSymbol`/`importanceColor`/`importanceLabel` und `urgencyIcon`/`urgencyColor`/`urgencyLabel` sind in 5 Dateien identisch hardcoded. Shared Helper erstellen.

## Kanonische Werte

### Importance (Int? → Icon/Color/Label)

| Level | Icon | Color | Label |
|-------|------|-------|-------|
| 3 | "exclamationmark.3" | .red | "Hoch" |
| 2 | "exclamationmark.2" | .yellow | "Mittel" |
| 1 | "exclamationmark" | .blue | "Niedrig" |
| nil/0 | "questionmark" | .gray | "Nicht gesetzt" |

### Urgency (String? → Icon/Color/Label)

| Value | Icon | Color | Label |
|-------|------|-------|-------|
| "urgent" | "flame.fill" | .orange | "Dringend" |
| "not_urgent" | "flame" | .gray | "Nicht dringend" |
| nil/default | "questionmark" | .gray | "Nicht gesetzt" |

**Alle 5 Dateien nutzen exakt dieselben Werte — keine Abweichungen.**

## Betroffene Dateien

### 1. BacklogRow.swift (~6 Properties)
- `importanceSFSymbol`, `importanceColor`, `importanceLabel` (Z.195-219)
- `urgencyIcon`, `urgencyColor`, `urgencyAccessibilityLabel` (Z.261-283)

### 2. MacBacklogRow.swift (~4 Properties)
- `importanceSFSymbol`, `importanceColor` (Z.131-145)
- `urgencyIcon`, `urgencyColor` (Z.178-191)

### 3. QuickCaptureView.swift (~6 Properties)
- `importanceIcon`, `importanceColor`, `importanceLabel` (Z.149-173)
- `urgencyIcon`, `urgencyColor`, `urgencyLabel` (Z.206-228)

### 4. QuickCaptureSnippetView.swift (~4 Properties)
- `importanceIcon`, `importanceColor` (Z.55-70)
- `urgencyIcon`, `urgencyColor` (Z.89-102)

### 5. TaskFormSheet.swift (~3 Properties)
- `urgencyIcon`, `urgencyColor`, `urgencyLabel` (Z.303-325)
- (Keine Importance-Properties — nutzt TaskInspector-aehnliche Chips)

### Bonus (nicht im Ticket, aber gleiche Logik):
- `TaskInspector.swift` — inline in importanceChip/urgencyChip
- `CreateTaskView.swift` — sfSymbol in lokaler Subview

## Dependencies

- **Upstream:** Keins (reine Display-Logik)
- **Downstream:** Alle genannten Views nutzen die Properties fuer Badge-Darstellung

## Risiken
- Rein kosmetisches Refactoring — keine Logik-Aenderung
- Alle Werte identisch — kein Inkonsistenz-Risiko
