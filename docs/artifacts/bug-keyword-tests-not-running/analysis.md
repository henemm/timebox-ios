# Bug-Analyse: KeywordSystemTests — 0 Tests Executed

## Bug-Beschreibung
`./scripts/sim.sh unit KeywordSystemTests` meldet "Executed 0 tests" — die 79+ Tests in KeywordSystemTests.swift laufen nicht.

## Root Cause (nach Challenge korrigiert)

**KeywordSystemTests.swift wurde durch Commit `209ea9a` aus dem pbxproj ENTFERNT.**

### Chronologie (bewiesen durch git diff)

1. **Commit `3b31cb1`** (BUG_148): KeywordSystemTests.swift korrekt zum FocusBloxTests-Target hinzugefügt. 4 pbxproj-Einträge erstellt (PBXBuildFile `1A9847AD...`, PBXFileReference `B23F42C9...`, Group-Entry, Sources-Entry). Commit-Message behauptet "79 neue KeywordSystemTests + 496 Regressionstests grün".

2. **Commit `209ea9a`** (BUG_169 — BGAppRefreshTask + Multi-Day Notifications): Massiver pbxproj-Rewrite (2134 Zeilen geändert). Dabei wurden alle 4 KeywordSystemTests-Einträge als Kollateralschaden gelöscht:
   - `-  1A9847AD99BCD88895CE36CB /* KeywordSystemTests.swift in Sources */`
   - `-  B23F42C99BC77EBC59C77A83 /* KeywordSystemTests.swift */`
   - `-  B23F42C99BC77EBC59C77A83 /* KeywordSystemTests.swift */,`
   - `-  1A9847AD99BCD88895CE36CB /* KeywordSystemTests.swift in Sources */,`

3. **Seitdem**: 0 Tests ausgeführt. Niemand hat es bemerkt.

### Warum ist es passiert?

Commit `209ea9a` hat 2134 Zeilen im pbxproj geändert — ein kompletter Rewrite durch ein Tool (vermutlich pbxproj Python-Library oder Xcode selbst). Dabei gingen die KeywordSystem-Einträge verloren, wahrscheinlich weil sie ein anderes Referenzformat hatten (`name = ...; path = FocusBloxTests/...; sourceTree = SOURCE_ROOT`) als ältere Einträge (`path = ...; sourceTree = "<group>"`).

### Umfang des Problems

- 178 Test-Dateien sind korrekt in der Build Phase registriert
- KeywordSystemTests.swift ist die einzige fehlende Test-Datei (durch Rewrite-Kollateralschaden)
- AITitleQualityTests: 3 von 12 Tests in `#if canImport(FoundationModels)` Block (separates Problem)
- SmartTaskEnrichmentServiceTests: 2 Failures (separates Problem — fehlende isAvailable Guards)

## Fix

1. KeywordSystemTests.swift zum FocusBloxTests Target hinzufügen (pbxproj-Script)
2. Tests ausführen → müssen von 0 auf 79+ springen
3. Wenn Compile-Errors: API-Drift seit Commit `3b31cb1` beheben

## Risiko nach Fix

- Tests könnten Compile-Errors haben wenn sich APIs seit BUG_148 geändert haben
- Kein Risiko für Produktionscode — nur Test-Infrastruktur betroffen
