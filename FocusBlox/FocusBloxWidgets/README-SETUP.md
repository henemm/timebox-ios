# Widget Extension Setup - Anleitung

## Schritte in Xcode

1. **Projekt öffnen**
   - `TimeBox.xcodeproj` in Xcode öffnen

2. **Neues Target erstellen**
   - File → New → Target...
   - Wähle: "Widget Extension"
   - Name: `TimeBoxWidgets`
   - Include Configuration App Intent: **NEIN**
   - Embed in Application: `TimeBox`

3. **Generierte Dateien ersetzen**
   - Lösche die automatisch generierten Dateien im TimeBoxWidgets Ordner
   - Nutze stattdessen die vorbereiteten Dateien:
     - `QuickAddTaskIntent.swift`
     - `QuickAddTaskControl.swift`
     - `TimeBoxWidgetsBundle.swift`

4. **Build Settings prüfen**
   - Deployment Target: iOS 18.0
   - Swift Language Version: Swift 5 oder 6

5. **Build & Run auf Device**
   - Control Center Widgets funktionieren NUR auf echtem Device
   - Simulator zeigt keine Control Widgets

## Verifikation

Nach dem Build:
1. Gehe zu Settings → Control Center
2. Suche nach "Quick Task" (TimeBox Widget)
3. Füge es zum Control Center hinzu
4. Öffne Control Center und tippe den Button

## Was wir testen

**Gemini's Behauptung:**
Der `@Parameter` mit `requestValueDialog` sollte einen Eingabe-Dialog öffnen, OHNE die App zu starten.

**Mögliche Ergebnisse:**
- ✅ Dialog erscheint im Control Center → Gemini hatte recht
- ⚠️ System-Dialog erscheint (wie Siri) → Akzeptabel
- ❌ App wird geöffnet → Kein Vorteil gegenüber normalem Widget
