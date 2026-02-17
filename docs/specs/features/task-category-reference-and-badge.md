---
entity_id: task_category_reference_and_badge
type: feature
created: 2026-02-15
updated: 2026-02-15
status: draft
version: "1.0"
tags: [category, badge, calendar, cross-platform, shared-code]
supersedes: [categories-expansion]
---

# TaskCategory Referenz & Kategorie-Badge auf Kalendereintraegen

## Approval

- [ ] Approved

## Purpose

1. **Referenz-Dokumentation:** Definitive Zuordnung aller TaskCategory-Werte zu Icons, Farben und Namen (Single Source of Truth)
2. **Kategorie-Badge:** Kalendereintraege zeigen die zugewiesene Kategorie als spezifisches Icon-Badge rechts oben an - konsistent auf iOS und macOS, mit geteilter Implementierung

## TaskCategory Referenz (Single Source of Truth)

Quelle: `Sources/Models/TaskCategory.swift`

| rawValue | Enum Case | Icon (SF Symbol) | Farbe | displayName | localizedName |
|----------|-----------|-------------------|-------|-------------|---------------|
| `income` | `.income` | `dollarsign.circle` | `.green` | Earn | Geld |
| `maintenance` | `.essentials` | `wrench.and.screwdriver.fill` | `.orange` | Essentials | Pflege |
| `recharge` | `.selfCare` | `heart.circle` | `.cyan` | Self Care | Energie |
| `learning` | `.learn` | `book` | `.purple` | Learn | Lernen |
| `giving_back` | `.social` | `person.2` | `.pink` | Social | Geben |

**Hinweis:** Die Spec `categories-expansion.md` ist veraltet (andere Icons) und wird durch diese Spec ersetzt.

## Ist-Zustand: Kategorie-Darstellung auf Kalendereintraegen

### iOS (`Sources/Views/EventBlock.swift`)
- Gesamter Block eingefaerbt mit Kategorie-Farbe (30% Opacity)
- Kategorie-Icon **inline vor dem Titel** (klein, caption2)
- Lock-Icon als Overlay rechts oben (nur bei read-only)

### macOS (`FocusBloxMac/MacTimelineView.swift` EventBlockView)
- Gesamter Block eingefaerbt mit Kategorie-Farbe (85% Opacity)
- 4px Farbstreifen am linken Rand
- Kategorie-Icon **inline vor dem Titel** (10pt)
- Lock-Icon als Overlay rechts oben (nur bei read-only)

### Problem
- Beide Plattformen zeigen das Kategorie-Icon unterschiedlich an
- Kein deutlich sichtbares Badge rechts
- Kategorie-Darstellungslogik ist in beiden Views dupliziert

## Soll-Zustand

### Gemeinsames Kategorie-Badge
- **Position:** Rechts oben auf dem Kalendereintrag (`.overlay(alignment: .topTrailing)`)
- **Darstellung:** Kategorie-spezifisches SF Symbol Icon in kleinem farbigen Kreis
- **Geteilte Implementierung:** Ein View `CategoryIconBadge` in `Sources/Views/` - wird von iOS und macOS importiert
- **Koexistenz mit Lock-Icon:** Bei read-only Events mit Kategorie werden beide nebeneinander angezeigt (HStack)

### Aenderungen an bestehender Darstellung
- **Inline-Icon vor Titel:** Entfaellt auf beiden Plattformen (Badge rechts ersetzt es)
- **Farbiger Hintergrund:** Bleibt auf beiden Plattformen
- **4px Stripe (macOS):** Bleibt (liefert zusaetzliche visuelle Orientierung)

## Betroffene Dateien

| Datei | Aenderung | Beschreibung |
|-------|-----------|--------------|
| `Sources/Views/CategoryIconBadge.swift` | CREATE | Shared Badge-View |
| `Sources/Views/EventBlock.swift` | MODIFY | Inline-Icon entfernen, Badge-Overlay hinzufuegen |
| `FocusBloxMac/MacTimelineView.swift` | MODIFY | Inline-Icon entfernen, Badge-Overlay hinzufuegen |

## Implementation Details

### 1. CategoryIconBadge (NEU - Shared)

```swift
struct CategoryIconBadge: View {
    let category: TaskCategory

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(category.color)
            )
    }
}
```

### 2. EventBlock.swift (iOS) - Overlay aendern

**Vorher:** Inline-Icon im HStack + separater Lock-Overlay
**Nachher:** Kein Inline-Icon, kombinierter Overlay rechts oben

```swift
.overlay(alignment: .topTrailing) {
    HStack(spacing: 3) {
        if event.isReadOnly {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        if let config = categoryConfig {
            CategoryIconBadge(category: config)
        }
    }
    .padding(4)
}
```

### 3. EventBlockView (macOS) - Overlay aendern

Identische Overlay-Logik wie iOS (gleicher Code, da CategoryIconBadge shared ist).

## Scope Assessment

- **Files:** 1 CREATE + 2 MODIFY = 3 Dateien
- **LoC:** +25 (Badge) / -10 (Inline-Icons) = netto +15
- **Risk:** LOW - rein visuelle Aenderung, keine Logik-Aenderung

## Akzeptanzkriterien

1. Kalendereintraege mit Kategorie zeigen das spezifische Kategorie-Icon als Badge rechts oben
2. iOS und macOS sehen identisch aus (gleicher Badge)
3. `CategoryIconBadge` existiert nur einmal in `Sources/Views/`
4. Read-only Events zeigen Lock-Icon UND Kategorie-Badge nebeneinander
5. Events ohne Kategorie zeigen kein Badge

## Changelog

- 2026-02-15: Initial spec (TaskCategory Referenz + CategoryIconBadge)
- Supersedes: `categories-expansion.md` (veraltete Icon-Zuordnungen)
