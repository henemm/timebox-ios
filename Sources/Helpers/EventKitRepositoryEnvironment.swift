import SwiftUI

/// EnvironmentKey for EventKitRepository dependency injection
private struct EventKitRepositoryKey: EnvironmentKey {
    static let defaultValue: any EventKitRepositoryProtocol = EventKitRepository()
}

extension EnvironmentValues {
    var eventKitRepository: any EventKitRepositoryProtocol {
        get { self[EventKitRepositoryKey.self] }
        set { self[EventKitRepositoryKey.self] = newValue }
    }
}
