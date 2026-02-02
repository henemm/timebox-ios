# UI Hierarchie inspizieren

Extrahiere den Accessibility Tree der laufenden App, um zu sehen, welche UI-Elemente aktuell sichtbar sind.

---

## Zweck

Da wir keine Screenshots sehen koennen, ist der Accessibility Tree unsere einzige Moeglichkeit, den UI-Zustand zu verstehen:
- Welche Elemente existieren
- Welche AccessibilityIdentifier gesetzt sind
- Ob Elemente verdeckt oder nicht hittable sind
- Hierarchie der Views

---

## Ausfuehrung

**Schritt 1: Fuehre den DebugHierarchy-Test aus**

```bash
# Simulator vorbereiten
killall "Simulator" 2>/dev/null
xcrun simctl shutdown all 2>/dev/null
xcrun simctl boot 877731AF-6250-4E23-A07E-80270C69D827 2>/dev/null
xcrun simctl bootstatus 877731AF-6250-4E23-A07E-80270C69D827 -b

# DebugHierarchy-Test ausfuehren
xcodebuild test \
  -project FocusBlox.xcodeproj \
  -scheme FocusBlox \
  -destination 'id=877731AF-6250-4E23-A07E-80270C69D827' \
  -only-testing:FocusBloxUITests/DebugHierarchyTest/testPrintAccessibilityTree \
  2>&1 | grep -A 1000 "=== ACCESSIBILITY TREE ===" | head -500
```

**Schritt 2: Analysiere den Output**

Der Test gibt aus:
- Komplette View-Hierarchie
- Alle AccessibilityIdentifier
- Element-Typen (Button, StaticText, Cell, etc.)
- Sichtbarkeitsstatus

---

## Optionale Parameter

Falls der User einen bestimmten Screen inspizieren moechte:

```bash
# Spezifischen Test fuer Navigation ausfuehren
-only-testing:FocusBloxUITests/DebugHierarchyTest/testPrintAfterNavigation
```

---

## Output-Format

Fasse die relevanten Informationen zusammen:

```
## UI Hierarchie (aktueller Screen)

**Sichtbare Buttons:**
- addTaskButton (identifier)
- settingsButton (identifier)
- "Speichern" (label)

**Sichtbare Texte:**
- "Heute" (NavigationTitle)
- "Keine Aufgaben" (Placeholder)

**Interaktive Elemente:**
- Toggle: remindersSyncToggle (value: "0")
- Picker: priorityPicker

**Probleme erkannt:**
- [Falls AccessibilityIdentifier fehlen]
- [Falls Elemente nicht hittable sind]
```

---

## Anwendungsfaelle

1. **Test findet Element nicht:** `/inspect-ui` zeigt, was stattdessen da ist
2. **Unklarer UI-Zustand:** Verifiziere, welcher Screen aktiv ist
3. **Identifier-Audit:** Pruefe, ob alle interaktiven Elemente Identifier haben
4. **Debug vor Test-Schreiben:** Verstehe die Hierarchie bevor du Tests schreibst
