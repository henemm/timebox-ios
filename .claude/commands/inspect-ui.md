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
./scripts/sim.sh test DebugHierarchyTest/testPrintAccessibilityTree 2>&1 | grep -A 1000 "=== ACCESSIBILITY TREE ===" | head -500
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
./scripts/sim.sh test DebugHierarchyTest/testPrintAfterNavigation
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

## State-Tracking

**Nach erfolgreicher Ausfuehrung** schreibe ein State-File, damit der Preflight-Hook weiss, dass `/inspect-ui` kuerzlich lief:

```bash
# State-File schreiben (nach erfolgreichem Hierarchy-Dump)
python3 .claude/hooks/preflight_gate.py main
```

Ersetze `main` durch den tatsaechlichen Screen-Namen (z.B. `backlog`, `settings`).

Dies ist **PFLICHT** nach jeder `/inspect-ui` Ausfuehrung — der Hook `ui_test_preflight.py` blockiert UI-Test-Edits wenn dieses File fehlt oder aelter als 15 Minuten ist.

---

## Anwendungsfaelle

1. **Test findet Element nicht:** `/inspect-ui` zeigt, was stattdessen da ist
2. **Unklarer UI-Zustand:** Verifiziere, welcher Screen aktiv ist
3. **Identifier-Audit:** Pruefe, ob alle interaktiven Elemente Identifier haben
4. **Debug vor Test-Schreiben:** Verstehe die Hierarchie bevor du Tests schreibst
