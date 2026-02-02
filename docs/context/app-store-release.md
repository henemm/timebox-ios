# Context: App Store Release

## Request Summary
Vorbereitung des FocusBlox Projekts für die Veröffentlichung über App Store Connect.

## Aktuelle Projektkonfiguration

### Bundle Identifier
- **App:** `com.henning.timebox`
- **Widget:** `com.henning.timebox.FocusBloxWidgets`
- **Framework:** `com.henning.timebox.FocusBloxCore`

### Versionen
- **Marketing Version:** 1.0.0 (teilweise 1.0 - inkonsistent!)
- **Build Number:** 1

### App Icon
- ✅ 1024x1024 PNG vorhanden
- ✅ RGBA Format korrekt

### Entitlements
- `com.apple.security.app-sandbox` = true

### Info.plist Einträge
- ✅ `NSRemindersUsageDescription` - vorhanden
- ✅ `NSCalendarsUsageDescription` - vorhanden
- ✅ `NSSupportsLiveActivities` - vorhanden
- ✅ `CFBundleDisplayName` - "FocusBlox"
- ⚠️ `UISupportedInterfaceOrientations` - nur Portrait (Warning beim Build)

## Analyse: Was fehlt für App Store Connect?

### 1. Projekt-Einstellungen (KRITISCH)

| Problem | Status | Lösung |
|---------|--------|--------|
| Inkonsistente MARKETING_VERSION | ⚠️ | Alle auf 1.0.0 vereinheitlichen |
| Interface Orientations Warning | ⚠️ | `UIRequiresFullScreen` oder alle Orientierungen |

### 2. App Store Connect Metadaten (EXTERN)

Diese werden in App Store Connect gepflegt, nicht im Code:
- App Name
- Subtitle
- Beschreibung (kurz/lang)
- Keywords
- Screenshots (iPhone, iPad)
- App Preview Videos (optional)
- Preis & Verfügbarkeit
- Altersfreigabe
- Datenschutzrichtlinie URL
- Support URL

### 3. Code Signing für Distribution

| Setting | Debug | Release |
|---------|-------|---------|
| CODE_SIGN_IDENTITY | Apple Development | Apple Distribution |
| PROVISIONING_PROFILE | Team Profile | App Store Profile |

### 4. Empfohlene Ergänzungen

| Feature | Priorität | Beschreibung |
|---------|-----------|--------------|
| Privacy Manifest | HOCH | Ab iOS 17 für bestimmte APIs Pflicht |
| App Privacy Details | HOCH | Welche Daten sammelt die App? |

## Scope Assessment

- **Files zu ändern:** 2-3
- **Estimated LoC:** ~20
- **Risk Level:** LOW

## Technischer Ansatz

1. **MARKETING_VERSION** überall auf 1.0.0 setzen
2. **Interface Orientations** Warning fixen
3. **Archive Build** testen
4. Optional: Privacy Manifest hinzufügen

## Offene Fragen

- [ ] Welche iOS Version soll minimal unterstützt werden? (aktuell 26.2)
- [ ] Soll die App kostenlos oder kostenpflichtig sein?
- [ ] Gibt es eine Datenschutzrichtlinien-URL?
- [ ] Gibt es eine Support-URL?
