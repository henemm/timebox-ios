# Spec: App Icon — Liquid Glass (iOS 26)

> Status: IN ARBEIT — Liquid Glass Rendering funktioniert technisch, Feintuning der Sichtbarkeit ausstehend

## Ziel

Das FocusBlox App Icon als iOS 26 Liquid Glass Icon (.icon Format) umsetzen.

## Design-Konzept (V10b — genehmigt)

- **Dunkler Hintergrund** mit **Cyan-Block** (abgerundetes Rechteck, zentral)
- **3 konzentrische weisse Ringe** — zentriert, ueber Block-Rand hinausragend (B3 Overflow)
- **Mittelpunkt** (weiss, solide)
- **Opacity-Gradient nach aussen:** innerer Ring am sichtbarsten, aeusserer am transparentesten
- **globalScale:** 1.18 (minimaler dunkler Rand)

## Aktueller Stand

### Was funktioniert
- icon.json Format korrekt (validiert mit ictool + Icon Composer GUI)
- 2-Gruppen-Struktur (Background-Gruppe + Foreground-Gruppe)
- `glass: true` auf Foreground-Layer erzeugt 3D Liquid Glass Effekt
- Block + Ringe sichtbar im ictool-Export und Icon Composer
- Alle Plattformen (iOS, watchOS, macOS) exportieren fehlerfrei

### Was noch nicht stimmt
- **Ringe auf Cyan-Block zu subtil:** Weisse Foreground-Elemente werden durch Liquid Glass Material transluzent — auf hellem Cyan-Hintergrund entsteht zu wenig Kontrast
- **Moegliche Loesungen (noch nicht abschliessend getestet):**
  1. Block-Farbe verdunkeln (mehr Kontrast zu weissen Ringen)
  2. Ringe dicker machen + Anzahl reduzieren (z.B. 2 statt 3)
  3. Komplettes Design in Background-Layer backen (kein Liquid Glass auf Ringen, aber Liquid Glass Icon-Form)
  4. Design mit Icon Composer GUI interaktiv anpassen (Translucency, Specular, Shadow-Werte)

## Technische Erkenntnisse

### icon.json Format (verifiziert)

```json
{
  "fill" : "system-light",
  "groups" : [
    {
      "layers" : [
        {
          "image-name" : "background.png",
          "name" : "Background"
        }
      ]
    },
    {
      "layers" : [
        {
          "glass" : true,
          "image-name" : "foreground.png",
          "name" : "Rings"
        }
      ],
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.5
      },
      "translucency" : {
        "enabled" : true,
        "value" : 0.5
      }
    }
  ],
  "supported-platforms" : {
    "circles" : ["watchOS"],
    "squares" : "shared"
  }
}
```

### Kritische Regeln

| Richtig | Falsch |
|---------|--------|
| `"glass": true` | `"is-glass": true` |
| 2 separate Gruppen | Alle Layer in 1 Gruppe |
| `"fill": "system-light"` auf Top-Level | Kein fill |
| `image-name` MIT Extension (.png) | Ohne Extension |
| Foreground: transparenter Hintergrund | Foreground: weisser Hintergrund |
| Weisse Foreground-Shapes | Dunkle Shapes (werden unsichtbar) |

### ictool (CLI-Testing)

```bash
# Pfad
/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool

# Light Mode Export
ictool AppIcon.icon --export-image --output-file out.png \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 2

# Dark Mode Export
ictool AppIcon.icon --export-image --output-file out.png \
  --platform iOS --rendition TintedDark --width 1024 --height 1024 --scale 2 \
  --tint-color 0.5 --tint-strength 0.5
```

**Achtung:** `Default` rendition zeigt IMMER helles/weisses Glass — das ist normal. Kein Bug.

### Icon Composer GUI Screenshot (automatisiert)

```bash
open -a "Icon Composer" AppIcon.icon && sleep 5 && screencapture -x screenshot.png
```

### Referenz-Icon (funktionierend)

Grammarly: `/Applications/Grammarly Desktop.app/Contents/Library/LoginItems/GRLoginHelper.app/Contents/Resources/Resources/AppIcon.icon/`

### Apple Design Guidelines (WWDC25 Sessions 220 + 361)

- **Keine duennen Linien:** "Sharp edges and thin lines should be avoided"
- **Fette Formen:** "Bolder line weights preserve details at smaller scale"
- **Opake Source Art:** "Flat, opaque, and easy to control"
- **Farben trennen:** Verschiedene Farben in separate Layer
- **Specular ausschalten** bei komplexen/engen Formen (werden sonst "pillowy")

## Dateien

| Datei | Zweck |
|-------|-------|
| `AppIcon.icon/icon.json` | Liquid Glass Layer-Definition |
| `AppIcon.icon/Assets/background.png` | 1024x1024, Dark BG + Cyan Block |
| `AppIcon.icon/Assets/foreground.png` | 1024x1024, Weisse Ringe + Dot (RGBA) |
| `scripts/GenerateIcon.swift` | Swift/CoreGraphics Generator |

## Naechste Schritte

1. Icon in Icon Composer GUI interaktiv anpassen (Translucency, Specular, Farben)
2. Ringe-Sichtbarkeit auf Cyan-Block loesen (Kontrast erhoehen oder Design anpassen)
3. Alle Plattform-Icons aktualisieren
4. Statische Fallback-Icons fuer aeltere Plattformen
