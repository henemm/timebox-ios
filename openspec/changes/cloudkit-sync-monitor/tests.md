# Tests: CloudKit Sync Monitor

## Unit Tests (FocusBloxTests/CloudKitSyncMonitorTests.swift)

### Test 1: Initial State
```
testInitialState()
- setupState == .notStarted
- importState == .notStarted
- exportState == .notStarted
- isSyncing == false
- hasSyncError == false
- lastSuccessfulSync == nil
```

### Test 2: Import Started -> isSyncing
```
testImportStarted_setsIsSyncing()
- Post eventChangedNotification mit import event (endDate = nil)
- Assert: importState == .inProgress
- Assert: isSyncing == true
```

### Test 3: Import Succeeded
```
testImportSucceeded_updatesState()
- Post eventChangedNotification mit import event (succeeded = true, endDate != nil)
- Assert: importState == .succeeded
- Assert: isSyncing == false
- Assert: lastSuccessfulSync != nil
```

### Test 4: Export Failed -> hasSyncError
```
testExportFailed_setsError()
- Post eventChangedNotification mit export event (succeeded = false, error != nil)
- Assert: exportState == .failed
- Assert: hasSyncError == true
- Assert: errorMessage != nil
```

### Test 5: Setup Event
```
testSetupEvent_updatesSetupState()
- Post eventChangedNotification mit setup event
- Assert: setupState changes accordingly
```

### Test 6: Multiple Events
```
testMultipleEvents_tracksAllTypes()
- Post import started, export started
- Assert: both inProgress
- Assert: isSyncing == true
- Post import succeeded, export succeeded
- Assert: isSyncing == false
```

## UI Tests

Kein separater UI Test noetig - der Monitor ist ein Backend-Service.
macOS Toolbar-Indikator wird ueber bestehende UI Tests abgedeckt
(syncStatusIndicator accessibilityIdentifier existiert bereits).
