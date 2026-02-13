# Context: BACKLOG-008 - Hardcoded Category-Switches

## Request Summary
Verbleibende hardcoded category switch-Statements durch `TaskCategory(rawValue:)?.color/icon/displayName` ersetzen. MacBacklogRow's standalone `CategoryBadge` struct ebenfalls auf TaskCategory umstellen.

## Kanonische Werte (TaskCategory enum)

| Case | rawValue | displayName | icon | color |
|------|----------|-------------|------|-------|
| .income | "income" | "Earn" | "dollarsign.circle" | .green |
| .essentials | "maintenance" | "Essentials" | "wrench.and.screwdriver.fill" | .orange |
| .selfCare | "recharge" | "Self Care" | "heart.circle" | .cyan |
| .learn | "learning" | "Learn" | "book" | .purple |
| .social | "giving_back" | "Social" | "person.2" | .pink |

## Betroffene Dateien (tatsaechlich hardcoded)

### 1. TaskFormSheet.swift (Zeile 329-338)
- `categoryColor(for:)` Funktion mit hardcoded switch
- Werte stimmen mit TaskCategory.color **exakt ueberein**
- Fix: Einfacher Einzeiler-Ersatz

### 2. QuickCaptureSnippetView.swift (Zeile 121-141)
- `categoryIcon` und `categoryColor` mit hardcoded switches
- **ABWEICHENDE Werte:**

| Category | SnippetView Icon | TaskCategory Icon | SnippetView Color | TaskCategory Color |
|----------|------------------|-------------------|-------------------|--------------------|
| maintenance | "wrench" | "wrench.and.screwdriver.fill" | .blue | .orange |
| recharge | "heart" | "heart.circle" | .pink | .cyan |
| giving_back | "hand.raised" | "person.2" | .orange | .pink |

### 3. MacBacklogRow.swift → CategoryBadge struct (Zeile 326-378)
- Standalone struct mit 3 hardcoded switches (color, icon, label)
- Color: **stimmt ueberein** mit TaskCategory
- Icon: 2 Abweichungen:
  - recharge: "battery.100" statt "heart.circle"
  - giving_back: "gift" statt "person.2"
- Label: **Komplett andere Sprache** (Deutsch statt Englisch):
  - "Geld" / "Pflege" / "Energie" / "Lernen" / "Geben"
  - vs. "Earn" / "Essentials" / "Self Care" / "Learn" / "Social"
- Wird genutzt in: `MacAssignView.swift` (Z.458), `MacPlanningView.swift` (Z.539)

## Bereits korrekt (KEIN Fix noetig)

| Datei | Status |
|-------|--------|
| `Sources/Views/BacklogRow.swift` | Nutzt bereits `TaskCategory(rawValue:)` |
| `FocusBloxMac/MacBacklogRow.swift` (inline properties) | Nutzt bereits `TaskCategory(rawValue:)` |
| `Sources/Views/QuickCaptureView.swift` | Nutzt bereits `TaskCategory(rawValue:)` |
| `FocusBloxMac/MacTimelineView.swift` | Nutzt bereits `TaskCategory(rawValue:)` |
| `Sources/Views/BlockPlanningView.swift` | Nutzt bereits `TaskCategory(rawValue:)` |

## Risiken & Considerations

1. **Display-Name Sprache:** CategoryBadge nutzt deutsche Labels, TaskCategory englische. Entscheidung noetig: TaskCategory um deutsche Namen erweitern oder englische Labels akzeptieren?
2. **Icon-Inkonsistenz:** QuickCaptureSnippetView und CategoryBadge nutzen z.T. andere Icons als TaskCategory. Fix = visuelle Aenderung fuer User.
3. **Farb-Inkonsistenz:** QuickCaptureSnippetView hat 3 Farben falsch. Fix = visuelle Aenderung fuer User.
4. **AppIntents-Kontext:** QuickCaptureSnippetView laeuft in Siri/Spotlight Extension. TaskCategory muss im Extension-Target verfuegbar sein (sollte bereits der Fall sein, da in Sources/).

### 4. BacklogView.swift → localizedCategory Extension (Zeile 928-944)
- Private String-Extension mit hardcoded switch fuer Kategorie-Lokalisierung
- Enthaelt VERALTETE Kategorien (deep_work, shallow_work, meetings, creative, strategic)
- Enthaelt aktuelle Kategorien mit DRITTEN deutschen Labels ("Geld verdienen", "Energie aufladen")
- Wird nur intern in `tasksByCategory` genutzt (Z.106-112)
- **Separates Problem** — nicht in BACKLOG-008 Scope (eigenes Backlog-Item)

## Bereits korrekt mit TaskCategory (KEIN Fix noetig)

| Datei | Status |
|-------|--------|
| `Sources/Views/BacklogRow.swift` | Nutzt bereits `TaskCategory(rawValue:)` |
| `FocusBloxMac/MacBacklogRow.swift` (inline) | Nutzt bereits `TaskCategory(rawValue:)` |
| `Sources/Views/QuickCaptureView.swift` | Nutzt bereits `TaskCategory(rawValue:)` |
| `FocusBloxMac/MacTimelineView.swift` | Nutzt bereits `TaskCategory(rawValue:)` |
| `Sources/Views/BlockPlanningView.swift` | Nutzt bereits `TaskCategory(rawValue:)` |

## Dependencies

- **Upstream:** `Sources/Models/TaskCategory.swift` (enum)
- **Downstream:** `MacAssignView.swift`, `MacPlanningView.swift` (nutzen CategoryBadge)

---

## Analysis

### Type
Refactoring (Code-Deduplizierung + Konsistenz-Fix)

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Sources/Models/TaskCategory.swift` | MODIFY | Neue Property `.localizedName` fuer deutsche Labels |
| `Sources/Views/TaskFormSheet.swift` | MODIFY | `categoryColor(for:)` → TaskCategory Lookup |
| `Sources/Intents/QuickCaptureSnippetView.swift` | MODIFY | 2 Switches → TaskCategory Lookup |
| `FocusBloxMac/MacBacklogRow.swift` | MODIFY | CategoryBadge Switches → TaskCategory Lookup |
| `Tests/TaskCategoryTests.swift` | CREATE | Regressions-Tests fuer alle Properties |

### Scope Assessment
- Files: 4 MODIFY + 1 CREATE
- Estimated LoC: +40 (Tests) / -50 (hardcoded switches) ≈ netto -10
- Risk Level: **LOW** — reine Delegation an bestehendes Enum

### Technical Approach

**Empfehlung:** TaskCategory um `.localizedName` Property erweitern (deutsche Labels). Dann:

1. **TaskCategory.swift**: Neue computed property `localizedName`:
   ```
   .income → "Geld"
   .essentials → "Pflege"
   .selfCare → "Energie"
   .learn → "Lernen"
   .social → "Geben"
   ```

2. **TaskFormSheet.swift**: `categoryColor(for:)` ersetzen durch:
   `TaskCategory(rawValue: type)?.color ?? .gray`

3. **QuickCaptureSnippetView.swift**: Beide Switches ersetzen:
   - `categoryIcon` → `TaskCategory(rawValue:)?.icon ?? "folder"`
   - `categoryColor` → `TaskCategory(rawValue:)?.color ?? .gray`
   - Fixes 3 falsche Icons + 3 falsche Farben

4. **CategoryBadge (MacBacklogRow.swift)**: Alle 3 Switches ersetzen:
   - `color` → `TaskCategory(rawValue:)?.color ?? .gray`
   - `icon` → `TaskCategory(rawValue:)?.icon ?? "questionmark.circle"`
   - `label` → `TaskCategory(rawValue:)?.localizedName ?? "Typ"`
   - Fixes 2 falsche Icons, vereinheitlicht Labels

5. **Regressions-Tests**: Unit Tests die verifizieren dass:
   - Alle 5 rawValues korrekt aufgeloest werden
   - `.color`, `.icon`, `.displayName`, `.localizedName` die erwarteten Werte liefern
   - Unbekannte rawValues `nil` liefern

### Visuelle Auswirkungen (User-sichtbar)

| Stelle | Vorher | Nachher |
|--------|--------|---------|
| SnippetView maintenance | 🔵 wrench | 🟠 wrench.and.screwdriver.fill |
| SnippetView recharge | 🩷 heart | 🩵 heart.circle |
| SnippetView giving_back | 🟠 hand.raised | 🩷 person.2 |
| CategoryBadge recharge | battery.100 | heart.circle |
| CategoryBadge giving_back | gift | person.2 |

### Open Questions
- Keine — alle technischen Fragen geklaert
