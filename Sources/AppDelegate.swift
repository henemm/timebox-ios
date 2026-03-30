import UIKit

/// Minimaler AppDelegate für Quick Action Handling (Long-Press auf App-Icon).
/// Mapped UIApplicationShortcutItem Types auf focusblox:// URLs → onOpenURL in FocusBloxApp.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Quick Action URLs keyed by shortcut item type
    private static let quickActionURLs: [String: URL] = [
        "com.henning.focusblox.create-task": URL(string: "focusblox://create-task")!,
        "com.henning.focusblox.sprint-picker": URL(string: "focusblox://sprint-picker")!,
        "com.henning.focusblox.day-view": URL(string: "focusblox://day-view")!,
    ]

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
            DispatchQueue.main.async {
                Self.handleShortcut(shortcutItem)
            }
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        return config
    }

    @discardableResult
    private static func handleShortcut(_ item: UIApplicationShortcutItem) -> Bool {
        guard let url = quickActionURLs[item.type] else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
