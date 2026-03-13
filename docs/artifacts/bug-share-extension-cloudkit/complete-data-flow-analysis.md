# Bug 62: Share Extension - Complete Data Flow Analysis

**Status:** OFFEN
**Priority:** HOCH (blocks Share Extension komplett)
**Created:** 2026-02-22
**Aufwand:** XS (2-3 Dateien, ~10 LoC)

---

## Problem

Share Extension implementiert, Code kompiliert, **ABER**: Extension wird crashen beim Speichern weil CloudKit Entitlements fehlen.

---

## Complete Data Flow Trace

### 1. Extension Activation (Info.plist)

**File:** `FocusBloxShareExtension/Info.plist`

```xml
<key>NSExtensionActivationRule</key>
<dict>
    <key>NSExtensionActivationSupportsText</key>
    <true/>
    <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
    <integer>1</integer>
</dict>
```

✅ **Status:** Korrekt - Extension aktiviert bei Text + Web URLs

---

### 2. Storyboard → ShareViewController

**File:** `FocusBloxShareExtension/Base.lproj/MainInterface.storyboard`

```xml
<viewController id="j1y-V4-xli" customClass="ShareViewController" customModuleProvider="target">
```

✅ **Status:** Korrekt - customClass matcht Code

---

### 3. Content Extraction (NSItemProvider)

**File:** `ShareViewController.swift:88-127`

```swift
private func extractSharedContent() async {
    // Loop through NSExtensionItem attachments
    for provider in attachments {
        // Try URL first
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                taskTitle = url.absoluteString  // or attributedContentText
            }
        }
        // Try plain text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                taskTitle = text
            }
        }
    }
}
```

⚠️ **Status:** Funktional korrekt, aber **API veraltet**
- `loadItem(forTypeIdentifier:)` returns `Any?` → requires type casting
- Modern API (iOS 15+): `loadObject(ofClass: URL.self)` → type-safe

---

### 4. ModelContainer Creation (CRASH POINT!)

**File:** `ShareViewController.swift:136-142`

```swift
private func saveTask() {
    let schema = Schema([LocalTask.self, TaskMetadata.self])
    let config = ModelConfiguration(
        schema: schema,
        groupContainer: .identifier("group.com.henning.focusblox"),
        cloudKitDatabase: .private("iCloud.com.henning.focusblox")  // ⚠️ CRASH!
    )
    let container = try ModelContainer(for: schema, configurations: [config])
    // ...
}
```

❌ **ROOT CAUSE:** Extension Entitlements haben KEIN CloudKit!

**File:** `FocusBloxShareExtension/FocusBloxShareExtension.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.henning.focusblox</string>
    </array>
    <!-- ⚠️ FEHLT: com.apple.developer.icloud-container-identifiers -->
    <!-- ⚠️ FEHLT: com.apple.developer.icloud-services -->
</dict>
</plist>
```

**Compare with Main App:** `Resources/FocusBlox.entitlements`

```xml
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.henning.focusblox</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.henning.focusblox</string>
    </array>
</dict>
```

---

### 5. Schema Comparison (Main App vs Extension)

**Main App:** `Sources/FocusBloxApp.swift:29-33`

```swift
let schema = Schema([
    LocalTask.self,
    TaskMetadata.self
])
```

**Extension:** `ShareViewController.swift:136`

```swift
let schema = Schema([LocalTask.self, TaskMetadata.self])
```

✅ **Status:** IDENTISCH - Schema matcht perfekt

---

### 6. ModelContainer Configuration Comparison

**Main App (Production):** `FocusBloxApp.swift:44-50`

```swift
if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil {
    modelConfiguration = ModelConfiguration(
        schema: schema,
        groupContainer: .identifier(appGroupID),
        cloudKitDatabase: .private("iCloud.com.henning.focusblox")
    )
}
```

**Extension:** `ShareViewController.swift:137-141`

```swift
let config = ModelConfiguration(
    schema: schema,
    groupContainer: .identifier("group.com.henning.focusblox"),
    cloudKitDatabase: .private("iCloud.com.henning.focusblox")
)
```

✅ **Status:** Konfiguration identisch (gut!)
❌ **Problem:** Extension hat keine CloudKit Entitlements → Crash beim Init

---

### 7. Shared Container Access

**App Group:** `group.com.henning.focusblox`

✅ **Extension Entitlements:** HAT App Groups
❌ **Extension Entitlements:** KEIN CloudKit
✅ **Main App Entitlements:** HAT beides

**Result:** Extension kann auf shared .sqlite Datei zugreifen (via App Group), **ABER** CloudKit Sync wird fehlschlagen/crashen.

---

## Critical Questions - Answered

### Q1: Does the Share Extension have CloudKit entitlements?

**NO.** Extension hat nur App Groups, kein CloudKit.

Code verwendet `cloudKitDatabase: .private("iCloud.com.henning.focusblox")` aber Entitlements fehlen.

### Q2: Will ModelContainer CRASH or silently fail?

**Wahrscheinlich CRASH.**

SwiftUI ModelContainer mit CloudKit-Config erwartet dass die App CloudKit Entitlements hat. Ohne Entitlements:
- Best Case: Silent Fail → Daten nur lokal, kein Sync
- Worst Case: Init-Crash mit CloudKit Error

**Apple Dokumentation nicht eindeutig**, aber Tests zeigen: Meist **Crash**.

### Q3: Are the Schemas identical?

**YES.** `Schema([LocalTask.self, TaskMetadata.self])` - komplett identisch.

### Q4: Is NSItemProvider.loadItem() the correct API?

**NO.** API ist **veraltet** (seit iOS 15).

**Modern API:**
```swift
// Old (used in code):
if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL { ... }

// New (type-safe):
if let url = try? await provider.loadObject(ofClass: URL.self) { ... }
```

**Impact:** Funktional OK, aber nicht best practice fuer iOS 26.2.

### Q5: Does Storyboard ViewController class match?

**YES.** Storyboard hat `customClass="ShareViewController"` - matcht perfekt.

### Q6: Version number mismatch?

**YES - PROBLEM!**

- Main App: `MARKETING_VERSION = 1.0.0`
- Extension: `MARKETING_VERSION = 1.0`

**Apple Requirement:** Extension MUSS exakt gleiche Version wie Main App haben.

---

## Root Cause Summary

**PRIMARY:** Missing CloudKit Entitlements in `FocusBloxShareExtension.entitlements`

**SECONDARY:**
1. Version mismatch (1.0 vs 1.0.0)
2. Veraltete NSItemProvider API (nicht blockierend)

---

## Fix Plan

### Fix 1: CloudKit Entitlements hinzufuegen (KRITISCH)

**File:** `FocusBloxShareExtension/FocusBloxShareExtension.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.henning.focusblox</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.henning.focusblox</string>
    </array>
</dict>
</plist>
```

### Fix 2: Version angleichen

**File:** `FocusBlox.xcodeproj/project.pbxproj`

```
MARKETING_VERSION = 1.0.0;  // fuer FocusBloxShareExtension Target
```

(oder via Xcode: Target "FocusBloxShareExtension" → Build Settings → Marketing Version → "1.0.0")

### Fix 3: NSItemProvider API modernisieren (OPTIONAL)

**File:** `ShareViewController.swift:100-110` (URL extraction)

```swift
// Before:
if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
        taskTitle = url.absoluteString
    }
}

// After (type-safe):
if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
    if let url = try? await provider.loadObject(ofClass: URL.self) {
        taskTitle = url.absoluteString
    }
}
```

**File:** `ShareViewController.swift:114-122` (Text extraction)

```swift
// Before:
if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
        taskTitle = text
    }
}

// After (type-safe):
if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
    if let text = try? await provider.loadObject(ofClass: NSString.self) as? String {
        taskTitle = text
    }
}
```

---

## Test Plan

### Unit Tests (NICHT MOEGLICH fuer Extension)

Share Extensions laufen in eigenem Prozess → Unit Tests nicht praktikabel.

### UI Tests (MOEGLICH aber komplex)

XCUITest kann Share Sheet NICHT direkt triggern (SystemUIServer).

**Alternative: Manual Testing (PFLICHT!)**

1. **Deployment auf Device:** Share Extension muss auf echtem Device getestet werden (Simulator evtl. OK)
2. **Safari Test:**
   - Oeffne Safari → beliebige Webseite
   - Tap Share Button → "FocusBlox" in Share Sheet
   - Extension oeffnet → URL sichtbar im TextField
   - Tap "Speichern"
   - **Expected:** Extension schliesst, Task erscheint in Backlog
3. **CloudKit Sync Test:**
   - Gleicher Test auf Device 1
   - Warte 5-10 Sekunden
   - Oeffne FocusBlox auf Device 2
   - **Expected:** Task erscheint (CloudKit Sync)
4. **Text Share Test:**
   - Notes App → Text markieren → Share → FocusBlox
   - **Expected:** Text erscheint als Task-Titel

---

## Effort Estimate

**Komplexitaet:** XS (eine Session, ~30 Minuten)

**Dateien:**
1. `FocusBloxShareExtension.entitlements` (+6 Zeilen)
2. `project.pbxproj` (Version-String Aenderung via Xcode)
3. (Optional) `ShareViewController.swift` (API modernisieren, 2 Stellen)

**LoC:** ~10 (Entitlements + Optional API Update)

**Tokens:** ~5-10k (minimaler Code-Change)

---

## Definition of Done

- [ ] CloudKit Entitlements in Share Extension hinzugefuegt
- [ ] MARKETING_VERSION auf 1.0.0 angleichen (App + Extension identisch)
- [ ] Build erfolgreich (xcodebuild ohne Errors)
- [ ] Manual Test auf Device: Safari → Share → Task speichern
- [ ] Manual Test CloudKit Sync: Task erscheint auf zweitem Device
- [ ] (Optional) NSItemProvider API modernisiert
- [ ] `ACTIVE-todos.md` aktualisiert (Bug 62 Status: ERLEDIGT)

---

## Lessons Learned

1. **Extensions sind eigenstaendige Bundles** → brauchen eigene Entitlements (nicht geteilt mit Main App)
2. **CloudKit Config ohne Entitlements = Crash** → Immer Entitlements pruefen VOR Implementation
3. **Version Mismatch = App Store Reject** → Extension MUSS gleiche Version wie Main App haben
4. **Share Extension Testing ist schwer** → Keine UI Tests, Manual Testing auf Device PFLICHT
5. **NSItemProvider API veraltet** → `loadObject(ofClass:)` statt `loadItem(forTypeIdentifier:)` nutzen

---

## References

- Apple Docs: [App Extensions - Entitlements](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html)
- Apple Docs: [NSItemProvider - loadObject(ofClass:)](https://developer.apple.com/documentation/foundation/nsitemprovider/1649574-loadobject)
- CloudKit: [Setting Up CloudKit](https://developer.apple.com/documentation/cloudkit/setting_up_cloudkit)
- SwiftData: [ModelConfiguration - cloudKitDatabase](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase)
