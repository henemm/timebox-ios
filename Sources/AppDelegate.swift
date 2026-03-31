import UIKit

/// Quick Action types for type-safe handling
enum QuickActionType: String {
    case createTask = "com.henning.focusblox.create-task"
    case sprintPicker = "com.henning.focusblox.sprint-picker"
    case dayView = "com.henning.focusblox.day-view"
}

/// Minimaler AppDelegate für Quick Action Handling (Long-Press auf App-Icon).
/// Speichert die anstehende Action in einer statischen Property.
/// FocusBloxApp.swift liest sie bei scenePhase == .active aus.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Pending Quick Action — consumed by FocusBloxApp on foreground
    static var pendingQuickAction: QuickActionType?

    /// Called when app is already running and user taps a Quick Action
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = Self.handleShortcut(shortcutItem)
        completionHandler(handled)
    }

    /// Called when app launches from a Quick Action (cold start)
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            Self.handleShortcut(shortcutItem)
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        return config
    }

    @discardableResult
    private static func handleShortcut(_ item: UIApplicationShortcutItem) -> Bool {
        guard let action = QuickActionType(rawValue: item.type) else { return false }
        pendingQuickAction = action
        return true
    }
}
